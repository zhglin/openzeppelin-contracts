// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorSettings.sol)

pragma solidity ^0.8.24;

import {IGovernor, Governor} from "../Governor.sol";

/**
 * @dev {Governor} 的扩展，用于可通过治理更新的设置。
 */
 /*
    让治理的核心参数（如投票期、提案门槛等）本身也能够通过治理投票来修改。
    这个模块将三个最基础的治理参数从“硬编码”变成了“可配置”的状态变量：
        1. `votingDelay` (投票延迟)：提案创建后多久开始投票。
        2. `votingPeriod` (投票期)：投票持续多长时间。
        3. `proposalThreshold` (提案门槛)：需要多少票权才能发起一个提案。
 */
abstract contract GovernorSettings is Governor {
    // 代币数量
    uint256 private _proposalThreshold;
    // 时间点：在核心中限制为 uint48（与 clock() 类型相同）
    uint48 private _votingDelay;
    // 持续时间：在核心中限制为 uint32
    uint32 private _votingPeriod;

    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

    /**
     * @dev 初始化治理参数。
     */
    constructor(uint48 initialVotingDelay, uint32 initialVotingPeriod, uint256 initialProposalThreshold) {
        _setVotingDelay(initialVotingDelay);
        _setVotingPeriod(initialVotingPeriod);
        _setProposalThreshold(initialProposalThreshold);
    }

    /// @inheritdoc IGovernor
    // 从提案创建到投票开始之间的延迟。
    function votingDelay() public view virtual override returns (uint256) {
        return _votingDelay;
    }

    /// @inheritdoc IGovernor
    // 从投票开始到投票结束之间的延迟。
    function votingPeriod() public view virtual override returns (uint256) {
        return _votingPeriod;
    }

    /// @inheritdoc Governor
    // 它规定了一个账户必须拥有最低多少票数（Voting Power），才有资格提交一个新的治理提案。
    function proposalThreshold() public view virtual override returns (uint256) {
        return _proposalThreshold;
    }

    /**
     * @dev 更新投票延迟。此操作只能通过治理提案执行。
     *
     * 发出 {VotingDelaySet} 事件。
     */
    function setVotingDelay(uint48 newVotingDelay) public virtual onlyGovernance {
        _setVotingDelay(newVotingDelay);
    }

    /**
     * @dev 更新投票期。此操作只能通过治理提案执行。
     *
     * 发出 {VotingPeriodSet} 事件。
     */
    function setVotingPeriod(uint32 newVotingPeriod) public virtual onlyGovernance {
        _setVotingPeriod(newVotingPeriod);
    }

    /**
     * @dev 更新提案阈值。此操作只能通过治理提案执行。
     *
     * 发出 {ProposalThresholdSet} 事件。
     */
    function setProposalThreshold(uint256 newProposalThreshold) public virtual onlyGovernance {
        _setProposalThreshold(newProposalThreshold);
    }

    /**
     * @dev 投票延迟的内部 setter 函数。
     *
     * 发出 {VotingDelaySet} 事件。
     */
    function _setVotingDelay(uint48 newVotingDelay) internal virtual {
        emit VotingDelaySet(_votingDelay, newVotingDelay);
        _votingDelay = newVotingDelay;
    }

    /**
     * @dev 投票期的内部 setter 函数。
     *
     * 发出 {VotingPeriodSet} 事件。
     */
    function _setVotingPeriod(uint32 newVotingPeriod) internal virtual {
        if (newVotingPeriod == 0) {
            revert GovernorInvalidVotingPeriod(0);
        }
        emit VotingPeriodSet(_votingPeriod, newVotingPeriod);
        _votingPeriod = newVotingPeriod;
    }

    /**
     * @dev 提案阈值的内部 setter 函数。
     *
     * 发出 {ProposalThresholdSet} 事件。
     */
    function _setProposalThreshold(uint256 newProposalThreshold) internal virtual {
        emit ProposalThresholdSet(_proposalThreshold, newProposalThreshold);
        _proposalThreshold = newProposalThreshold;
    }
}
