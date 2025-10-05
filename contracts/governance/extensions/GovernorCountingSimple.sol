// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorCountingSimple.sol)

pragma solidity ^0.8.24;

import {IGovernor, Governor} from "../Governor.sol";

/**
 * @dev {Governor} 的扩展，用于简单的三选项投票计数。
 */
abstract contract GovernorCountingSimple is Governor {
    /**
     * @dev 支持的投票类型。与 Governor Bravo 的顺序匹配。
     */
    enum VoteType {
        Against,    // 0反对
        For,        // 1赞成
        Abstain     // 2弃权
    }

    struct ProposalVote {
        uint256 againstVotes;   // 反对票数
        uint256 forVotes;       // 赞成票数
        uint256 abstainVotes;   // 弃权票数
        mapping(address voter => bool) hasVoted;    // 记录每个账户是否已投票, true表示已投票
    }

    // 每个提案的投票数据
    mapping(uint256 proposalId => ProposalVote) private _proposalVotes;

    /// @inheritdoc IGovernor
    // solhint-disable-next-line func-name-mixedcase
    // `support=bravo` 指的是投票选项 0 = 反对, 1 = 赞成, 2 = 弃权，如 `GovernorBravo` 中所示。
    // `quorum=for,abstain` 意味着赞成票和弃权票都计入法定人数。
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /// @inheritdoc IGovernor
    // account 是否已对特定提案投票
    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @dev 内部投票数的访问器。
     * 获取特定提案的反对票、赞成票和弃权票数。
     */
    function proposalVotes(
        uint256 proposalId
    ) public view virtual returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.againstVotes, proposalVote.forVotes, proposalVote.abstainVotes);
    }

    /// @inheritdoc Governor
    // 已投票数是否达到法定人数
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        // 法定人数检查
        /*
        为什么这么设计？
        这是一种常见的治理设计模式，源自 Compound 的 Governor Bravo 合约。
        背后的逻辑是，法定人数（Quorum）是用来衡量提案的“参与度”或“关注度”的门槛。
            通过将弃权票也计入法定人数，可以鼓励更多人参与投票，即使他们对提案持中立态度。
            如果只计算赞成票，那么一个有很多赞成票但更多人弃权的提案可能因为达不到参与门槛而失败。
        将“反对票”排除在法定人数计算之外，意味着一个提案需要获得最低限度的“非反对”参与才能进入最终的是否通过的判断。
            这可以防止一个争议巨大、反对票很多的提案仅仅因为总投票人数多而满足法定人数要求。
        总结一下：这是合约明确设定的规则，目的是将“弃权”也视为一种有效的参与形式来计算总参与度。

        第一关：参与度检查 (`_quorumReached`)
            * 目的：确保这个提案获得了足够的关注和参与，避免一个没什么人关心的提案被极少数人通过。这个“足够”的门槛就是“法定人数”（Quorum）。
            * 规则 (`quorum=for,abstain`)：在这个合约里，规则被设定为只有“赞成票”和“弃权票”才被算作有效的“参与”。反对票不算。
            
            这是一种特殊的治理理念，您可以这样理解这条规则背后的“潜台词”：
                1. “赞成”是一种参与：这很显然，你支持这个提案。
                2. “弃权”也是一种参与：你花时间去了解了提案，虽然你选择中立，但你的弃权行为本身代表了你对这次投票的关注。系统认可你的这种参与。
                3. “反对”在这里不被视为“建设性参与”：这是最关键的一点。
                    系统认为，一个提案如果想要进入到“胜负判断”的阶段，它必须先证明自己至少获得了一定程度的“非反对”关注。
                    如果一个提案从头到尾全是反对，那么它连讨论的价值都没有，在第一关就应该被淘汰。
                所以，`_quorumReached` 函数在计算 `forVotes + abstainVotes` 时，
                    它真正在问的问题是：“这个提案获得的‘赞成’和‘中立’关注度，达到我们设定的最低门槛了吗？”
        第二关：胜负判断 (`_voteSucceeded`)
            * 目的：在确认有足够多的人参与之后，判断这个提案最终是否通过。
            * 规则：很简单，就是 forVotes > againstVotes (赞成票是否严格大于反对票)。
            
            注意：在这一关里，“弃权票”不起任何作用，它只在第一关里有用。
        */
        return quorum(proposalSnapshot(proposalId)) <= proposalVote.forVotes + proposalVote.abstainVotes;
    }

    /**
     * @dev 参见 {Governor-_voteSucceeded}。在此模块中，赞成票必须严格多于反对票。
     *  提案是否成功。
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        // 赞成票是否大于反对票
        return proposalVote.forVotes > proposalVote.againstVotes;
    }

    /**
     * @dev 参见 {Governor-_countVote}。在此模块中，支持遵循 `VoteType` 枚举（来自 Governor Bravo）。
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,  // 投票类型 0 = 反对, 1 = 赞成, 2 = 弃权
        uint256 totalWeight, // 投票权重
        bytes memory // params
    ) internal virtual override returns (uint256) {
        // 获取投票数据
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        // 已投票检查
        if (proposalVote.hasVoted[account]) {
            revert GovernorAlreadyCastVote(account);
        }

        // 投票标记
        proposalVote.hasVoted[account] = true;

        if (support == uint8(VoteType.Against)) {
            proposalVote.againstVotes += totalWeight;   // 反对票数增加
        } else if (support == uint8(VoteType.For)) {
            proposalVote.forVotes += totalWeight;       // 赞成票数增加
        } else if (support == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += totalWeight;   // 弃权票数增加
        } else {
            revert GovernorInvalidVoteType();
        }

        return totalWeight;
    }
}
