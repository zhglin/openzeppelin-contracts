// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorCountingFractional.sol)

pragma solidity ^0.8.24;

import {IGovernor, Governor} from "../Governor.sol";
import {GovernorCountingSimple} from "./GovernorCountingSimple.sol";
import {Math} from "../../utils/math/Math.sol";

/**
 * @dev {Governor} 的扩展，用于分数投票。
 *
 * 与 {GovernorCountingSimple} 类似，此合约是 {Governor} 的一个投票计数模块，
 * 支持3个选项：反对、赞成、弃权。
 * 此外，它还包括第四个选项：分数（Fractional），允许投票者将其投票权力分配给其他3个选项。
 *
 * 使用分数（Fractional）支持投票时，必须附带一个 `params` 参数，该参数是三个打包的 `uint128` 值，
 * 分别代表委托人分配给“反对”、“赞成”和“弃权”的权重。对于投给其他
 * 3个选项的票，`params` 参数必须为空。
 *
 * 这在委托人是实现其自身投票规则的合约时特别有用。这些委托合约
 * 可以根据委托其投票权力的多个实体的偏好进行分数投票。
 *
 * 一些用例包括：
 *
 * * 从DeFi池持有的代币进行投票
 * * 从L2通过桥持有的代币进行投票
 * * 使用零知识证明从屏蔽池中进行私密投票。
 *
 * 基于 ScopeLift 的 https://github.com/ScopeLift/flexible-voting/blob/e5de2efd1368387b840931f19f3c184c85842761/src/GovernorCountingFractional.sol[`GovernorCountingFractional`]
 *
 * _自 v5.1 起可用。_
 */
abstract contract GovernorCountingFractional is Governor {
    using Math for *;

    uint8 internal constant VOTE_TYPE_FRACTIONAL = 255; // 分数投票类型

    struct ProposalVote {
        uint256 againstVotes; // 反对票数
        uint256 forVotes;     // 赞成票数  
        uint256 abstainVotes; // 弃权票数
        mapping(address voter => uint256) usedVotes; // 记录每个账户已使用的票数
    }

    /**
     * @dev 从提案ID到该提案投票总数的映射。
     */
    mapping(uint256 proposalId => ProposalVote) private _proposalVotes;

    /**
     * @dev 分数投票参数使用的票数超过了该用户的可用票数。
     */
    error GovernorExceedRemainingWeight(address voter, uint256 usedVotes, uint256 remainingWeight);

    /// @inheritdoc IGovernor
    // solhint-disable-next-line func-name-mixedcase
    // `fractional`：这是本合约新增的“分数投票”选项。
    //      它允许一个投票者不把所有票权都投给单一选项，而是可以按任意比例拆分自己的票权，同时投给“反对”、“赞成”和“弃权”。
    // `params` 声明了哪种投票类型需要附带额外参数。
    //      当投票者使用“分数投票”模式时（即 support 值设为 255），他必须在调用投票函数时提供一个额外的 params 字节数据。    
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo,fractional&quorum=for,abstain&params=fractional";
    }

    /// @inheritdoc IGovernor
    // account 是否已对特定提案投票
    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return usedVotes(proposalId, account) > 0;
    }

    /**
     * @dev 获取 `account` 已为 `proposalId` 的提案投出的票数。对于
     * 允许委托人进行滚动、部分投票的集成很有用。
     */
    function usedVotes(uint256 proposalId, address account) public view virtual returns (uint256) {
        return _proposalVotes[proposalId].usedVotes[account];
    }

    /**
     * @dev 获取给定提案的当前票数分布。
     */
    function proposalVotes(
        uint256 proposalId
    ) public view virtual returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.againstVotes, proposalVote.forVotes, proposalVote.abstainVotes);
    }

    /// @inheritdoc Governor
    // 是否达到法定人数
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return quorum(proposalSnapshot(proposalId)) <= proposalVote.forVotes + proposalVote.abstainVotes;
    }

    /**
     * @dev 参见 {Governor-_voteSucceeded}。在此模块中，赞成票必须 > 反对票。
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return proposalVote.forVotes > proposalVote.againstVotes;
    }

    /**
     * @dev 参见 {Governor-_countVote}。记录委托人投票的函数。
     *
     * 执行此函数会消耗（部分）委托人在该提案上的权重。该权重可以
     * 通过指定一个分数 `support` 在3个选项（反对、赞成、弃权）中进行分配。
     *
     * 此计数模块支持两种投票模式：名义投票和分数投票。
     *
     * - 名义投票（Nominal）：通过将 `support` 设置为3个bravo选项之一（反对、赞成、弃权）来进行名义投票。
     * - 分数投票（Fractional）：通过将 `support` 设置为 `type(uint8).max` (255) 来进行分数投票。
     *
     * 投名义票要求 `params` 为空，并消耗委托人在该提案上
     * 为指定 `support` 选项的全部剩余权重。这与 {GovernorCountingSimple} 模块类似，并遵循
     * Governor Bravo 的 `VoteType` 枚举。因此，没有投票权重未被使用，因此无法进行进一步的投票
     * （对于此 `proposalId` 和此 `account`）。
     *
     * 投分数票会根据委托人分配给每个支持选项（分别为反对、赞成、弃权）的权重，
     * 消耗委托人在该提案上剩余权重的一部分。解码后的三个投票权重的总和
     * _必须_ 小于或等于委托人在该提案上的剩余权重（即
     * 他们的检查点总权重减去已在该提案上投出的票数）。可以使用以下方式生成此格式：
     *
     * `abi.encodePacked(uint128(againstVotes), uint128(forVotes), uint128(abstainVotes))`
     *
     * 注意：请注意，分数投票将每个类别中投出的票数限制为128位。
     * 根据基础代币的小数位数，单个投票者可能需要将其投票分成
     * 多个投票操作。对于精度高于约30位小数的情况，大额代币持有者可能需要
     * 大量调用才能投出所有票。投票者可以选择使用传统的“bravo”投票
     * 在单个操作中投出所有剩余的票。
     */
    // slither-disable-next-line cyclomatic-complexity
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,  // 投票类型
        uint256 totalWeight, // 总的投票权重
        bytes memory params
    ) internal virtual override returns (uint256) {
        // 计算剩余票数。如果溢出则返回0。
        // totalWeight这个值通常是在提案创建时（或某个特定的“快照”时间点），根据该地址持有的治理代币数量来确定的。它代表了这个投票者在这个提案上的最大影响力。
        // 投票者可以分多次、部分地投票（即分数投票），因此我们需要跟踪他们已经使用了多少票权（usedVotes）。
        // 通过从总权重中减去已使用的票权，我们可以确定他们在这个提案上还剩多少票权可以使用（remainingWeight）。
        (, uint256 remainingWeight) = totalWeight.trySub(usedVotes(proposalId, account));
        if (remainingWeight == 0) {
            revert GovernorAlreadyCastVote(account);
        }

        uint256 againstVotes = 0;
        uint256 forVotes = 0;
        uint256 abstainVotes = 0;
        uint256 usedWeight = 0;

        // 为了事件索引的清晰性，分数投票必须在 "support" 字段中明确声明。
        //
        // 支持的 `support` 值必须是：
        // - “完整”投票：`support = 0` (反对), `1` (赞成) 或 `2` (弃权)，params 为空。
        // - “分数”投票：`support = 255`，params 为48字节。
        if (support == uint8(GovernorCountingSimple.VoteType.Against)) {    // 0 = 反对
            if (params.length != 0) revert GovernorInvalidVoteParams();
            usedWeight = againstVotes = remainingWeight;
        } else if (support == uint8(GovernorCountingSimple.VoteType.For)) { // 1 = 赞成
            if (params.length != 0) revert GovernorInvalidVoteParams();
            usedWeight = forVotes = remainingWeight;
        } else if (support == uint8(GovernorCountingSimple.VoteType.Abstain)) { // 2 = 弃权
            if (params.length != 0) revert GovernorInvalidVoteParams();
            usedWeight = abstainVotes = remainingWeight;
        } else if (support == VOTE_TYPE_FRACTIONAL) {   // 255 = 分数投票
            // `params` 参数应为三个打包的 `uint128`：
            // `abi.encodePacked(uint128(againstVotes), uint128(forVotes), uint128(abstainVotes))`
            // 0x30 = 48 字节
            if (params.length != 0x30) revert GovernorInvalidVoteParams();

            assembly ("memory-safe") {
                // 前20字节是长度，接下来的48字节是数据
                // 每个 uint128 占16字节
                // params 的类型是 bytes memory。在Solidity中，对于动态大小的 memory 变量（如 bytes 或 string），
                // 变量名本身（params）存的不是数据内容，而是指向数据内容区域的一个起始地址。
                // 任何以 [] 结尾的动态数组成员（包括 bytes 和 string），其变量名都是一个指向 [长度][数据...] 这种内存布局的地址。
                // 数组、结构体、映射这三大类(引用类型)，无论在哪里，其变量名都扮演着“地址”或“引用”的角色。 而像 uint、bool、address 这样的基础类型(值类型)，无论在哪里，变量名存的都是它们自身的值。
                againstVotes := shr(128, mload(add(params, 0x20)))
                forVotes := shr(128, mload(add(params, 0x30)))
                abstainVotes := shr(128, mload(add(params, 0x40)))
                // 三个数相加
                usedWeight := add(add(againstVotes, forVotes), abstainVotes) // 输入是 uint128：不会溢出
            }

            // 检查解析的参数是否有效
            if (usedWeight > remainingWeight) {
                revert GovernorExceedRemainingWeight(account, usedWeight, remainingWeight);
            }
        } else {
            revert GovernorInvalidVoteType(); // 无效的投票类型
        }

        // 更新投票记录
        ProposalVote storage details = _proposalVotes[proposalId];
        if (againstVotes > 0) details.againstVotes += againstVotes;
        if (forVotes > 0) details.forVotes += forVotes;
        if (abstainVotes > 0) details.abstainVotes += abstainVotes;
        details.usedVotes[account] += usedWeight;

        return usedWeight;
    }
}
