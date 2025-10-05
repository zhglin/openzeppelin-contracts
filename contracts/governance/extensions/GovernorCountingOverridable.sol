// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorCountingOverridable.sol)

pragma solidity ^0.8.24;

import {SignatureChecker} from "../../utils/cryptography/SignatureChecker.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";
import {VotesExtended} from "../utils/VotesExtended.sol";
import {GovernorVotes} from "./GovernorVotes.sol";
import {IGovernor, Governor} from "../Governor.sol";

/**
 * @dev {Governor} 的扩展，使委托人能够覆盖其代表的投票。此模块需要一个继承自 {VotesExtended} 的代币。
 */
 /*
    代表和老板都各自只有一次操作机会。
    可以这么说：无论是代表投票，还是老板覆盖，都是一次性地使用其当前可用的全部票权。
    1. 对于代表（Delegate）
        当代表调用 castVote 时，他会用掉所有委托给他、并且尚未被老板收回的全部剩余票权。他不能选择只用一部分。
    2. 对于老板（Delegator）
        当老板调用 castOverrideVote 时，他也是将自己名下所有代币在快照时的全部票权一次性投出。他也不能选择“我只想用我一半的票权来覆盖”。

    代表和老板都可以投吗？
        是的，可以理解为他们都可以“操作”，但不是简单的一人一票。他们的行为是“普通投票”和“覆盖投票”的关系，最终只有一个结果生效。
    * 代表（Delegate）：执行的是“普通投票”（castVote），他代表所有委托给他的票权进行投票。
    * 老板（Delegator / Token Holder）：执行的是“覆盖投票”（castOverrideVote），他使用自己名下的票权，来修正或优先决定这部分票权的投向。

    有顺序吗？
        是的，顺序非常关键。不同的投票顺序会触发不同的处理逻辑，但最终结果都保证了“老板”的意愿优先。

    情况一：老板先投（覆盖票），代表后投
        1. 老板调用 castOverrideVote 投出自己的“覆盖票”。
        2. 系统将老板的票数（比如400票）计入他选择的选项（比如“反对”）。
        3. 同时，系统会给这位代表的“投票回执”上记一笔账（overriddenWeight），标记他有400票的权力已经被老板提前用掉了。
        4. 之后，当这位代表投票时，他的总票权会先减去已经被老板用掉的这400票，然后再进行计票。
    > 效果：老板优先决定了自己这部分票的去向，代表只能用“剩余的”委托票权投票。这是一种“事前阻止”模式。

    情况二：代表先投，老板后投（覆盖票）
        1. 代表调用 castVote 投票，此时他用的是全部委托票权（比如1000票“赞成”,这里的1000是有多个老板的总的委托）。
        2. 系统将代表的1000票“赞成”计入总票池。
        3. 之后，老板发现代表的投票不符合自己的意愿，于是调用 castOverrideVote 投了“反对票”（比如他自己的400票）。
        4. 系统会执行一个“修正”操作：
            * 首先，将老板的400票加到“反对”的总票池里。
            * 然后，从“赞成”的总票池里减去400票，因为这部分票权已经被老板“覆盖”并重新投向了“反对”。
    > 效果：老板的投票修正了代表之前的投票结果。这是一种“事后修正”模式。

    总结
        无论谁先谁后，老板（代币的最终持有人）的意愿总是优先的。
        这个机制设计得非常巧妙，它通过：
            * 事前阻止（老板先投）
            * 事后修正（老板后投）
    这两种方式，最终都确保了票权的最终控制权掌握在所有者自己手中，完美地实现了“覆盖”的语义。
 */
abstract contract GovernorCountingOverridable is GovernorVotes {
    bytes32 public constant OVERRIDE_BALLOT_TYPEHASH =
        keccak256("OverrideBallot(uint256 proposalId,uint8 support,address voter,uint256 nonce,string reason)");

    /**
     * @dev 支持的投票类型。与 Governor Bravo 的顺序匹配。
     */
    enum VoteType {
        Against,    // 0 = 反对
        For,        // 1 = 赞成
        Abstain     // 2 = 弃权
    }

    struct VoteReceipt {
        uint8 casted; // 如果未投票则为0。否则为：support + 1
        bool hasOverridden; // 如果账户已覆盖其代表的投票，则为 true
        uint208 overriddenWeight; // 覆盖代表投票时使用的权重,已经被“老板”们自己用掉的票权
    }

    struct ProposalVote {
        uint256[3] votes; // votes[0] 用来存反对票，votes[1] 存赞成票，votes[2] 存弃权票。
        mapping(address voter => VoteReceipt) voteReceipt;  // 记录每个账户的投票收据
    }

    /// @dev 在原始代币持有者投出覆盖票后，`delegate` 投出的票数被 `weight` 减少了。
    event VoteReduced(address indexed delegate, uint256 proposalId, uint8 support, uint256 weight);

    /// @dev `proposalId` 上的一个委托投票被 `weight` 覆盖了。
    event OverrideVoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    error GovernorAlreadyOverriddenVote(address account);

    mapping(uint256 proposalId => ProposalVote) private _proposalVotes;

    /// @inheritdoc IGovernor
    // solhint-disable-next-line func-name-mixedcase
    // `override`：这是一个新的关键字，表示此合约支持“覆盖投票”机制。
    //      这意味着，如果一个代币持有者（委托人）将自己的投票权委托给了另一个地址（代表），当代表投票后，原始的代币持有者有权亲自下场，投出自己的一票来“覆盖”并修正代表的投票结果。
    // overridable=true 用于明确地告知外部工具或前端界面：“本治理合约的投票是支持被覆盖的”。
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo,override&quorum=for,abstain&overridable=true";
    }

    /**
     * @dev 参见 {IGovernor-hasVoted}。
     *
     * 注意：调用 {castVote} (或类似函数) 使用委托给投票者的投票权进行投票。
     * 相反，调用 {castOverrideVote} (或类似函数) 使用账户自身的资产余额所代表的投票权。
     * 投出“覆盖票”不计为投票，并且不会在此getter中反映。请考虑
     * 使用 {hasVotedOverride} 来检查一个账户是否已为给定的提案ID投出“覆盖票”。
     */
     // 如果 hasVoted(..., currentUser) 为 true，就显示“您已作为代表投票”。
    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return _proposalVotes[proposalId].voteReceipt[account].casted != 0;
    }

    /**
     * @dev 检查一个 `account` 是否已为一个提案覆盖其代表的投票。
     */
     // 如果 hasVotedOverride(..., currentUser) 为 true，就显示“您已覆盖投票”。
    function hasVotedOverride(uint256 proposalId, address account) public view virtual returns (bool) {
        return _proposalVotes[proposalId].voteReceipt[account].hasOverridden;
    }

    /**
     * @dev 内部投票数的访问器。
     */
    function proposalVotes(
        uint256 proposalId
    ) public view virtual returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) {
        uint256[3] storage votes = _proposalVotes[proposalId].votes;
        // 用uint8比较节省gas
        return (votes[uint8(VoteType.Against)], votes[uint8(VoteType.For)], votes[uint8(VoteType.Abstain)]);
    }

    /// @inheritdoc Governor
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        uint256[3] storage votes = _proposalVotes[proposalId].votes;
        return quorum(proposalSnapshot(proposalId)) <= votes[uint8(VoteType.For)] + votes[uint8(VoteType.Abstain)];
    }

    /**
     * @dev 参见 {Governor-_voteSucceeded}。在此模块中，赞成票必须严格多于反对票。
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        uint256[3] storage votes = _proposalVotes[proposalId].votes;
        return votes[uint8(VoteType.For)] > votes[uint8(VoteType.Against)];
    }

    /**
     * @dev 参见 {Governor-_countVote}。在此模块中，支持遵循 `VoteType` 枚举 (来自 Governor Bravo)。
     *
     * 注意：由 {Governor-_castVote} 调用，该函数会发出 {IGovernor-VoteCast} (或 {IGovernor-VoteCastWithParams})
     * 事件。
     */
     // 一个代表（delegate） 投票,只能由委托人来调用
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 totalWeight,
        bytes memory /*params*/
    ) internal virtual override returns (uint256) {
        // 提案的投票信息
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        // 检查支持的投票类型,只有0,1,2三种
        if (support > uint8(VoteType.Abstain)) {
            revert GovernorInvalidVoteType();
        }

        // 检查账户是否已投票
        if (proposalVote.voteReceipt[account].casted != 0) {
            revert GovernorAlreadyCastVote(account);
        }

        // 它代表的业务逻辑是：在计算你（代表）的票数之前，系统需要先检查，有没有已经将票权委托给你的“老板”（原始代币持有人），自己下场投了“覆盖票”？
        totalWeight -= proposalVote.voteReceipt[account].overriddenWeight;
        proposalVote.votes[support] += totalWeight;// 更新对应投票类型的总票数
        // 记录投票收据
        proposalVote.voteReceipt[account].casted = support + 1; // 标记投了哪个support, 0表示没投票

        return totalWeight;
    }

    /**
     * @dev {Governor-_countVote} 的变体，处理投票覆盖。
     *
     * 注意：有关 {castVote} 和 {castOverrideVote} 之间差异的更多详细信息，请参见 {hasVoted}。
     */
    function _countOverride(uint256 proposalId, address account, uint8 support) internal virtual returns (uint256) {
        // 投票信息
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        // 检查支持的投票类型,只有0,1,2三种
        if (support > uint8(VoteType.Abstain)) {
            revert GovernorInvalidVoteType();
        }

        // 检查账户是否已覆盖其代表的投票
        if (proposalVote.voteReceipt[account].hasOverridden) {
            revert GovernorAlreadyOverriddenVote(account);
        }

        // 获取提案的开始时间
        uint256 snapshot = proposalSnapshot(proposalId);
        // 获取账户在提案开始时的投票权重
        uint256 overriddenWeight = VotesExtended(address(token())).getPastBalanceOf(account, snapshot);
        // 获取账户在提案开始时的委托人
        address delegate = VotesExtended(address(token())).getPastDelegate(account, snapshot);
        // 委托人的投票信息
        uint8 delegateCasted = proposalVote.voteReceipt[delegate].casted;

        // 标记已覆盖, 这里的account是老板
        proposalVote.voteReceipt[account].hasOverridden = true;
        proposalVote.votes[support] += overriddenWeight; // 增加对应投票类型的总票数
        if (delegateCasted == 0) { // 委托人未投票
            // 仅记录覆盖的权重,这里的delegate是代表
            proposalVote.voteReceipt[delegate].overriddenWeight += SafeCast.toUint208(overriddenWeight);
        } else { // 委托人已投票
            uint8 delegateSupport = delegateCasted - 1;
            // 减少委托人已投票的权重
            proposalVote.votes[delegateSupport] -= overriddenWeight;
            emit VoteReduced(delegate, proposalId, delegateSupport, overriddenWeight);
            /*
            为什么不修改 `voteReceipt.overriddenWeight`？
                因为 overriddenWeight 字段的核心作用是在“老板先投”的场景下，提前扣除代表的可用票权，防止他在后续投票时使用这部分权力。
                既然现在代表已经投完票了（他的投票动作已经结束），他不可能再投第二次，所以再回头去更新这个字段已经没有意义了。
            当老板后投票时，合约的设计哲学是：
                >不去修改一个已经完成的、作为历史凭证的个人回执（voteReceipt），而是选择直接修正最终的计票总账本（votes 数组）。
            这是一种更清晰、更符合逻辑的设计，避免了不必要的复杂性。    
            */
        }

        return overriddenWeight;
    }

    /// @dev {Governor-_castVote} 的变体，处理投票覆盖。返回被覆盖的权重。
    // 老板投票
    function _castOverride(
        uint256 proposalId,
        address account,
        uint8 support,
        string calldata reason
    ) internal virtual returns (uint256) {
        // 检查提案状态是否为 Active
        _validateStateBitmap(proposalId, _encodeStateBitmap(ProposalState.Active));

        // 执行覆盖投票
        uint256 overriddenWeight = _countOverride(proposalId, account, support);

        emit OverrideVoteCast(account, proposalId, support, overriddenWeight, reason);

        _tallyUpdated(proposalId);

        return overriddenWeight;
    }

    /// @dev 用于投出覆盖票的公共函数。返回被覆盖的权重。
    function castOverrideVote(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public virtual returns (uint256) {
        address voter = _msgSender();
        return _castOverride(proposalId, voter, support, reason);
    }

    /// @dev 使用投票者签名投出覆盖票的公共函数。返回被覆盖的权重。
    function castOverrideVoteBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        string calldata reason,
        bytes calldata signature
    ) public virtual returns (uint256) {
        bool valid = SignatureChecker.isValidSignatureNow(
            voter,
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        OVERRIDE_BALLOT_TYPEHASH,
                        proposalId,
                        support,
                        voter,
                        _useNonce(voter),
                        keccak256(bytes(reason))
                    )
                )
            ),
            signature
        );

        if (!valid) {
            revert GovernorInvalidSignature(voter);
        }

        return _castOverride(proposalId, voter, support, reason);
    }
}
