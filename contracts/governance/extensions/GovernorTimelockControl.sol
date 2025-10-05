// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorTimelockControl.sol)

pragma solidity ^0.8.24;

import {IGovernor, Governor} from "../Governor.sol";
import {TimelockController} from "../TimelockController.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";

/**
 * @dev {Governor} 的扩展，将执行过程绑定到一个 {TimelockController} 实例。
 * 这为所有成功的提案增加了一个由 {TimelockController} 强制执行的延迟（在投票持续时间之外）。
 * {Governor} 需要拥有提议者（proposer）角色（理想情况下还包括执行者（executor）和取消者（canceller）角色）才能正常工作。
 *
 * 使用此模型意味着提案将由 {TimelelockController} 而不是 {Governor} 操作。
 * 因此，资产和权限必须附加到 {TimelockController} 上。
 * 任何发送到 {Governor} 的资产都将无法从提案中访问，除非通过 {Governor-relay} 执行。
 *
 * 警告：将 TimelockController 设置为除了治理合约之外还有额外的提议者或取消者是非常危险的，因为这赋予了他们以下能力：
 *      1) 作为时间锁执行操作，从而可能执行那些预期只能通过投票才能访问的操作或资金，
 *      以及 2) 阻止已经由选民批准的治理提案，实际上是执行拒绝服务攻击。
 */
 /*
    在 `TimelockController` 合约中，除了 `Governor` 治理合约自己，不应该有任何其他的“提议者（Proposer）”或“取消者（Canceler）”。
    TimelockController 是最终的权力执行者，它掌管着资金和系统权限。
        唯一能合法命令它的，应该是经过投票的 Governor 合约。如果将这些强大角色授予其他地址，会带来两个巨大的风险：
            风险一：绕过投票，直接夺权
                * 风险来源：将 PROPOSER_ROLE（提议者角色）授予 Governor 之外的地址（比如一个普通钱包地址）。
                * 攻击方式：
                    拥有 PROPOSER_ROLE 的地址可以直接调用 TimelockController 的 schedule 和 execute 函数。
                        这意味着，这个地址可以完全绕过 Governor 的投票过程，随心所欲地安排并执行任何操作，比如“将国库所有资金转入我的账户”。
                * 后果：
                    这相当于治理被完全架空，投票变得毫无意义。一个被信任的“提议者”可以瞬间盗走所有资产。
            风险二：恶意否决，瘫痪治理
                * 风险来源：将 CANCELER_ROLE（取消者角色）授予 Governor 之外的地址。
                * 攻击方式：
                    拥有 CANCELER_ROLE 的地址可以取消任何已经在 `TimelockController` 中排队等待执行的操作。
                * 场景：
                    1. 一个完全合法的提案经过了社区投票，成功了。
                    2. Governor 将这个提案的操作排队到 TimelockController 中，等待延迟期结束。
                    3. 这个恶意的“取消者”看到了这个排队的提案，并立即调用 cancel 函数将其取消。
                * 后果：
                    这个“取消者”可以凭一己之力否决掉所有社区辛辛苦苦投票通过的提案，让整个治理系统陷入瘫痪，无法做出任何决策。
                    这是一种典型的“拒绝服务（Denial of Service）”攻击。
 */
abstract contract GovernorTimelockControl is Governor {
    // 时间锁实例
    TimelockController private _timelock;

    // 提案 ID 到时间锁操作 ID 的映射
    mapping(uint256 proposalId => bytes32) private _timelockIds;

    /**
     * @dev 当用于提案执行的时间锁控制器被修改时发出。
     */
    event TimelockChange(address oldTimelock, address newTimelock);

    /**
     * @dev 设置时间锁。
     */
    constructor(TimelockController timelockAddress) {
        _updateTimelock(timelockAddress);
    }

    /**
     * @dev {Governor-state} 函数的重写版本，它会考虑时间锁报告的状态。
     */
    function state(uint256 proposalId) public view virtual override returns (ProposalState) {
        // 获取当前状态
        ProposalState currentState = super.state(proposalId);

        // 如果提案不在排队状态，则返回当前状态
        if (currentState != ProposalState.Queued) {
            return currentState;
        }

        // 检查时间锁的状态
        bytes32 queueid = _timelockIds[proposalId];
        if (_timelock.isOperationPending(queueid)) {    // 如果提案仍在等待时间锁的延迟期结束
            return ProposalState.Queued;
        } else if (_timelock.isOperationDone(queueid)) { // 提案已执行
            // 如果提案直接在时间锁上执行，可能会发生这种情况。
            return ProposalState.Executed;
        } else {
            // 如果提案直接在时间锁上取消，可能会发生这种情况。
            return ProposalState.Canceled;
        }
    }

    /**
     * @dev 用于检查时间锁地址的公共访问器。
     */
    function timelock() public view virtual returns (address) {
        return address(_timelock);
    }

    /// @inheritdoc IGovernor
    // 是否需要排队
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
        bytes32 descriptionHash
    ) internal virtual override returns (uint48) {
        // 获取延迟时间
        uint256 delay = _timelock.getMinDelay();

        // 计算solt
        bytes32 salt = _timelockSalt(descriptionHash);

        // 排队
        _timelockIds[proposalId] = _timelock.hashOperationBatch(targets, values, calldatas, 0, salt);
        
        // 调用时间锁的排队函数
        _timelock.scheduleBatch(targets, values, calldatas, 0, salt, delay);

        return SafeCast.toUint48(block.timestamp + delay);
    }

    /**
     * @dev {Governor-_executeOperations} 函数的重写版本，它通过时间锁运行已经排队的提案。
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override {
        // 执行
        _timelock.executeBatch{value: msg.value}(targets, values, calldatas, 0, _timelockSalt(descriptionHash));
        // 清理以退款
        delete _timelockIds[proposalId];
    }

    /**
     * @dev {Governor-_cancel} 函数的重写版本，用于在时间锁提案已经排队的情况下取消它。
     */
    // 此函数可以通过对时间锁的外部调用重入，但我们假设时间锁是受信任且行为良好的（根据 TimelockController），因此不会发生这种情况。
    // slither-disable-next-line reentrancy-no-eth
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override returns (uint256) {
        uint256 proposalId = super._cancel(targets, values, calldatas, descriptionHash);

        bytes32 timelockId = _timelockIds[proposalId];
        if (timelockId != 0) {
            // 取消
            _timelock.cancel(timelockId);
            // 清理
            delete _timelockIds[proposalId];
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
     * @dev 用于更新底层时间锁实例的公共端点。仅限于时间锁自身调用，因此更新必须通过治理提案进行提议、调度和执行。
     *
     * 警告：当存在其他已排队的治理提案时，不建议更改时间锁。
     */
    function updateTimelock(TimelockController newTimelock) external virtual onlyGovernance {
        _updateTimelock(newTimelock);
    }

    // 更新时间锁实例的内部函数
    function _updateTimelock(TimelockController newTimelock) private {
        emit TimelockChange(address(_timelock), address(newTimelock));
        _timelock = newTimelock;
    }

    /**
     * @dev 计算 {TimelockController} 操作的盐（salt）。
     *
     * 它是用治理合约自身的地址计算的，以避免使用相同时间锁的不同治理合约实例之间发生冲突。
     */
    function _timelockSalt(bytes32 descriptionHash) private view returns (bytes32) {
        return bytes20(address(this)) ^ descriptionHash;
    }
}
