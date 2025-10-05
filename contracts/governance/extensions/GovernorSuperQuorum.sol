// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorSuperQuorum.sol)

pragma solidity ^0.8.24;

import {Governor} from "../Governor.sol";

/**
 * @dev 带有超级法定人数（super quorum）的 {Governor} 扩展。
 * 满足超级法定人数（并且赞成票占多数）的提案会在提案截止日期前进入 `Succeeded` 状态。
 * 希望使用此扩展的计数模块必须实现 {proposalVotes}。
 */
abstract contract GovernorSuperQuorum is Governor {
    /**
     * @dev 提案达到超级法定人数所需的最低投票数。只有赞成票（FOR votes）被计入超级法定人数。一旦达到超级法定人数，一个活跃的提案可以进入下一个状态，而无需等待提案截止日期。
     *
     * 注意：`timepoint` 参数对应于用于计票的快照。这使得可以根据诸如代币在该时间点的 `totalSupply` 等值来调整法定人数（参见 {ERC20Votes}）。
     *
     * 注意：请确保为超级法定人数指定的值大于 {quorum}，否则，可能会用比默认法定人数更少的票数通过一个提案。
     */
     /*
        将投票开始时间（即“快照时间点”）作为参数传递给 superQuorum，是为了让这个“超级法定人数”的阈值不是一个固定不变的数字，而是可以动态计算的。
        核心原因：为了实现“动态阈值”
            在大多数DAO中，法定人数通常不被设为一个硬编码的数字（比如1,000,000票），因为代币的总供应量可能会变化（通胀、销毁等）。
            更常见的做法是将其设置为“在提案快照时，总票数的X%”（例如，超级法定人数需要达到总票数的20%）。
            要实现这一点，superQuorum 函数在计算时，就需要知道“提案快照时”这个具体的时间点是哪一刻。这个时间点正是投票的开始时间。
     */
    function superQuorum(uint256 timepoint) public view virtual returns (uint256);

    /**
     * @dev 内部投票数的访问器。这必须由计数模块实现。未实现此函数的计数模块与此模块不兼容。
     */
    function proposalVotes(
        uint256 proposalId
    ) public view virtual returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes);

    /**
     * @dev {Governor-state} 函数的重写版本，用于检查提案是否已达到超级法定人数。
     *
     * 注意：如果提案达到超级法定人数但 {_voteSucceeded} 返回 false，例如，假设超级法定人数设置得足够低，以至于赞成票和反对票都超过了它，但反对票超过了赞成票，那么提案将继续保持活跃状态，直到 {_voteSucceeded} 返回 true 或达到提案截止日期。
     * 这意味着，在超级法定人数较低的情况下，投票也可能在足够多的反对者有机会投票之前过早成功。因此，建议设置足够高的超级法定人数以避免这类情况。
     */
    function state(uint256 proposalId) public view virtual override returns (ProposalState) {
        ProposalState currentState = super.state(proposalId);
        if (currentState != ProposalState.Active) return currentState;

        (, uint256 forVotes, ) = proposalVotes(proposalId);
        if (forVotes < superQuorum(proposalSnapshot(proposalId)) || !_voteSucceeded(proposalId)) {
            return ProposalState.Active;
        } else if (proposalEta(proposalId) == 0) { // 提案不需要排队
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Queued;
        }
    }
}
