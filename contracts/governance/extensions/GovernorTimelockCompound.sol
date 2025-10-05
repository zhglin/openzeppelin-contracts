// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorTimelockCompound.sol)

pragma solidity ^0.8.24;

import {IGovernor, Governor} from "../Governor.sol";
import {ICompoundTimelock} from "../../vendor/compound/ICompoundTimelock.sol";
import {Address} from "../../utils/Address.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";

/**
 * @dev {Governor} 的扩展，将执行过程绑定到一个 Compound 时间锁。
 * 这为所有成功的提案增加了一个由外部时间锁强制执行的延迟（在投票持续时间之外）。
 * {Governor} 需要成为时间锁的管理员才能执行任何操作。
 * 一个公共的、无限制的 {GovernorTimelockCompound-__acceptAdmin} 函数可用于接受时间锁的所有权。
 *
 * 使用此模型意味着提案将由时间锁而不是 {Governor} 操作。
 * 因此，资产和权限必须附加到时间锁上。任何发送到 {Governor} 的资产都将无法从提案中访问，除非通过 {Governor-relay} 执行。
 */
abstract contract GovernorTimelockCompound is Governor {
    // Compound 协议
    ICompoundTimelock private _timelock;

    /**
     * @dev 当用于提案执行的时间锁控制器被修改时发出。
     */
    event TimelockChange(address oldTimelock, address newTimelock);

    /**
     * @dev 设置时间锁。
     */
    constructor(ICompoundTimelock timelockAddress) {
        _updateTimelock(timelockAddress);
    }

    /**
     * @dev {Governor-state} 函数的重写版本，增加了对 `Expired` 状态的支持。
     */
    function state(uint256 proposalId) public view virtual override returns (ProposalState) {
        ProposalState currentState = super.state(proposalId);

        return
            (currentState == ProposalState.Queued &&
                block.timestamp >= proposalEta(proposalId) + _timelock.GRACE_PERIOD())
                ? ProposalState.Expired
                : currentState;
    }

    /**
     * @dev 用于检查时间锁地址的公共访问器。
     */
    function timelock() public view virtual returns (address) {
        return address(_timelock);
    }

    /// @inheritdoc IGovernor
    function proposalNeedsQueuing(uint256) public view virtual override returns (bool) {
        return true;
    }

    /**
     * @dev 用于将提案排队到时间锁的函数。
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal virtual override returns (uint48) {
        uint48 etaSeconds = SafeCast.toUint48(block.timestamp + _timelock.delay());

        for (uint256 i = 0; i < targets.length; ++i) {
            if (
                _timelock.queuedTransactions(keccak256(abi.encode(targets[i], values[i], "", calldatas[i], etaSeconds)))
            ) {
                revert GovernorAlreadyQueuedProposal(proposalId);
            }
            _timelock.queueTransaction(targets[i], values[i], "", calldatas[i], etaSeconds);
        }

        return etaSeconds;
    }

    /**
     * @dev {Governor-_executeOperations} 函数的重写版本，它通过时间锁运行已经排队的提案。
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal virtual override {
        uint256 etaSeconds = proposalEta(proposalId);
        if (etaSeconds == 0) {
            revert GovernorNotQueuedProposal(proposalId);
        }
        Address.sendValue(payable(_timelock), msg.value);
        for (uint256 i = 0; i < targets.length; ++i) {
            _timelock.executeTransaction(targets[i], values[i], "", calldatas[i], etaSeconds);
        }
    }

    /**
     * @dev {Governor-_cancel} 函数的重写版本，用于在时间锁提案已经排队的情况下取消它。
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override returns (uint256) {
        uint256 proposalId = super._cancel(targets, values, calldatas, descriptionHash);

        uint256 etaSeconds = proposalEta(proposalId);
        if (etaSeconds > 0) {
            // 稍后进行外部调用
            for (uint256 i = 0; i < targets.length; ++i) {
                _timelock.cancelTransaction(targets[i], values[i], "", calldatas[i], etaSeconds);
            }
        }

        return proposalId;
    }

    /**
     * @dev 治理合约执行操作所通过的地址。在这种情况下，是时间锁。
     */
    function _executor() internal view virtual override returns (address) {
        return address(_timelock);
    }

    /**
     * @dev 接受时间锁的管理权限。
     */
    // solhint-disable-next-line private-vars-leading-underscore
    function __acceptAdmin() public {
        _timelock.acceptAdmin();
    }

    /**
     * @dev 用于更新底层时间锁实例的公共端点。仅限于时间锁自身调用，因此更新必须通过治理提案进行提议、调度和执行。
     *
     * 出于安全原因，在设置新的时间锁之前，必须将旧时间锁的管理权移交给另一个管理员。这两个操作（移交时间锁和进行更新）可以在一个提案中批量处理。
     *
     * 请注意，如果时间锁的管理权已在先前的操作中移交，并且时间锁的管理员权限已被接受，且操作在治理范围之外执行，我们将拒绝通过该时间锁进行的更新。

     * 警告：当存在其他已排队的治理提案时，不建议更改时间锁。
     */
    function updateTimelock(ICompoundTimelock newTimelock) external virtual onlyGovernance {
        _updateTimelock(newTimelock);
    }

    function _updateTimelock(ICompoundTimelock newTimelock) private {
        emit TimelockChange(address(_timelock), address(newTimelock));
        _timelock = newTimelock;
    }
}
