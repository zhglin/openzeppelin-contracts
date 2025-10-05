// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorPreventLateQuorum.sol)

pragma solidity ^0.8.24;

import {Governor} from "../Governor.sol";
import {Math} from "../../utils/math/Math.sol";

/**
 * @dev 一个确保在达到法定人数后有最短投票期的模块。
 * 这可以防止大户投票者在最后一刻通过投票影响结果并触发法定人数，方法是确保总有时间让其他投票者做出反应并试图反对该决定。
 *
 * 如果一次投票导致达到法定人数，提案的投票期可能会被延长，以确保在至少经过指定时间（“投票延期”参数）之前它不会结束。
 * 此参数可以通过治理提案进行设置。
 */
 /*
    要解决的问题：“最后一刻突袭”攻击
    想象一个场景：
        1. 一个提案投票快结束了，参与度很低，眼看就要失败。
        2. 就在最后几秒，一个“巨鲸”（持有大量投票权的人）突然投出决定性的一票，不仅让提案的票数反转为“赞成”，还同时满足了法定人数（Quorum）的要求。
        3. 由于时间太短，其他所有人都来不及反应，无法组织反对票，导致这个“被突袭”的提案意外通过。这就是“延迟达到法定人数”攻击。
    
    _voteExtension 如何工作
    这个模块就是为了防止上述攻击而设计的。
        * 每次有人投票后，合约都会在 _tallyUpdated 函数中检查：“这次投票是不是第一次让这个提案达到了法定人数？”
        * 如果是，合约会立刻计算一个新的“强制截止时间”：
            强制截止时间 = 当前时间 + _voteExtension
        * 然后，它会用这个新的截止时间去和原定的投票截止时间比较。如果新的截止时间更晚，合约就会自动延长投票期，确保从达到法定人数的那一刻起，
            社区至少还有 _voteExtension 这么长的“反应时间”。
    总结：
        _voteExtension 是一个安全参数，它通过保证一个固定的“反应窗口”，来防止投票被“最后一秒”的巨鲸突袭操纵，从而保障了治理的公平性。
 */
abstract contract GovernorPreventLateQuorum is Governor {
    // 从一个提案首次达到法定人数的那一刻起，到投票最终结束，之间必须至少要有多长的时间。
    uint48 private _voteExtension;

    // 记录每个提案的延长后的截止日期（如果有的话）。
    mapping(uint256 proposalId => uint48) private _extendedDeadlines;

    /// @dev 当提案因在其投票期后期达到法定人数而推迟截止日期时发出。
    event ProposalExtended(uint256 indexed proposalId, uint64 extendedDeadline);

    /// @dev 当 {lateQuorumVoteExtension} 参数被更改时发出。
    event LateQuorumVoteExtensionSet(uint64 oldVoteExtension, uint64 newVoteExtension);

    /**
     * @dev 初始化投票延期参数：从提案达到法定人数那一刻起，到其投票期结束所需经过的时间（以区块数或秒为单位，取决于治理合约的时钟模式）。
     *  如有必要，投票期将被延长至超出提案创建时设置的期限。
     */
    constructor(uint48 initialVoteExtension) {
        _setLateQuorumVoteExtension(initialVoteExtension);
    }

    /**
     * @dev 返回提案的截止日期，如果提案在其投票期后期达到法定人数，该截止日期可能已超出提案创建时设置的期限。参见 {Governor-proposalDeadline}。
     */
    function proposalDeadline(uint256 proposalId) public view virtual override returns (uint256) {
        return Math.max(super.proposalDeadline(proposalId), _extendedDeadlines[proposalId]);
    }

    /**
     * @dev 投票总数更新，并检测是否因此达到法定人数，可能会延长投票期。
     *
     * 可能会发出 {ProposalExtended} 事件。
     */
    function _tallyUpdated(uint256 proposalId) internal virtual override {
        super._tallyUpdated(proposalId);
        // 如果这是提案第一次达到法定人数，则延长其投票期（如果需要）。
        if (_extendedDeadlines[proposalId] == 0 && _quorumReached(proposalId)) {
            // 计算新的截止日期。
            uint48 extendedDeadline = clock() + lateQuorumVoteExtension();

            // 仅当新的截止日期晚于当前截止日期时才延长投票期。    
            if (extendedDeadline > proposalDeadline(proposalId)) {
                emit ProposalExtended(proposalId, extendedDeadline);
            }

            // 记录新的截止日期。
            _extendedDeadlines[proposalId] = extendedDeadline;
            /*
                将 _extendedDeadlines 的更新放在 if 条件外面，是出于一个非常重要的双重目的。
                目的一：作为“已检查”的一次性标记（最重要的原因）
                    最主要的原因是，_extendedDeadlines[proposalId] 不仅存储截止日期，它还被用作一个一次性的标记（flag）。
                        * 外层的 if (_extendedDeadlines[proposalId] == 0 && ...) 条件决定了整个延长逻辑只在提案首次达到法定人数时执行一次。
                        * 一旦我们进入了这个逻辑块，就必须将 _extendedDeadlines[proposalId] 设置为一个非零值。
                        * 如果不这样做，那么下一次有人投票时，_extendedDeadlines[proposalId] 仍然是 0，这个条件会再次满足，延长逻辑就会被错误地重复执行。
                    所以，这行赋值语句的首要任务是“盖章”，标记“法定人数已达，检查完毕”，防止逻辑重复执行。
                
                目的二：记录“强制截止时间”
                    现在我们知道了必须设置一个值，那么设置什么值呢？合约选择设置 extendedDeadline (当前时间 + _voteExtension)。我们来看两种情况：
                    * 情况A（需要延长）:
                        * extendedDeadline 大于 原截止时间。
                        * 此时，_extendedDeadlines 被更新为这个更晚的时间。proposalDeadline() 
                            函数会因此返回这个更晚的时间，成功延长了投票期。这符合我们的预期。
                    * 情况B（无需延长）:
                        * extendedDeadline 小于或等于 原截止时间。这意味着即使达到了法定人数，剩余的投票时间也足够长，满足“反应窗口”的要求。
                        * 此时，虽然 _extendedDeadlines 仍然被更新为这个（较早的）extendedDeadline 值，但这不会产生负面影响。
                        * 因为最终的截止时间是通过 proposalDeadline() 函数中的 Math.max(原截止时间, _extendedDeadlines[...]) 计算的。Math.max 
                            会正确地选择那个更晚的“原截止时间”，所以投票期不会被错误地缩短。
            */
        }
    }

    /**
     * @dev 返回投票延期参数的当前值：从提案达到法定人数到其投票期结束所需经过的区块数。
     */
    function lateQuorumVoteExtension() public view virtual returns (uint48) {
        return _voteExtension;
    }

    /**
     * @dev 更改 {lateQuorumVoteExtension}。此操作只能由治理执行者执行，通常通过治理提案进行。
     *
     * 发出 {LateQuorumVoteExtensionSet} 事件。
     */
    function setLateQuorumVoteExtension(uint48 newVoteExtension) public virtual onlyGovernance {
        _setLateQuorumVoteExtension(newVoteExtension);
    }

    /**
     * @dev 更改 {lateQuorumVoteExtension}。这是一个内部函数，如果需要其他访问控制机制，可以在像 {setLateQuorumVoteExtension} 这样的公共函数中公开。
     *
     * 发出 {LateQuorumVoteExtensionSet} 事件。
     */
    function _setLateQuorumVoteExtension(uint48 newVoteExtension) internal virtual {
        emit LateQuorumVoteExtensionSet(_voteExtension, newVoteExtension);
        _voteExtension = newVoteExtension;
    }
}
