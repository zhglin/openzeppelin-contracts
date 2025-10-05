// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorTimelockAccess.sol)

pragma solidity ^0.8.24;

import {IGovernor, Governor} from "../Governor.sol";
import {AuthorityUtils} from "../../access/manager/AuthorityUtils.sol";
import {IAccessManager} from "../../access/manager/IAccessManager.sol";
import {Address} from "../../utils/Address.sol";
import {Math} from "../../utils/math/Math.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";
import {Time} from "../../utils/types/Time.sol";

/**
 * @dev 此模块将 {Governor} 实例连接到 {AccessManager} 实例，允许治理合约使用常规的 {queue} 工作流进行由管理器限制延迟的调用。
 * 一个可选的基础延迟会应用于那些不由管理器在外部延迟的操作。提案的执行将被延迟足够长的时间，以满足其所有操作所需的延迟。
 *
 * 与 {GovernorTimelockControl} 和 {GovernorTimelockCompound} 不同（在这两个合约中，时间锁是一个独立的合约，必须由它来持有资产和权限），
 此扩展允许治理合约持有并使用其自身的资产和权限。然而，受管理器延迟限制的操作将通过 {AccessManager-execute} 函数执行。
 *
 * ==== 安全考量
 *
 * 根据被调用的受限函数，`AccessManager` 中的某些操作可能被管理员或一组监护人取消。
 * 由于提案是原子性的，监护人取消提案中的单个操作将导致整个提案无法执行。请考虑将可取消的操作分开提议。
 *
 * 默认情况下，当关联的 `AccessManager` 声明目标函数受其限制时，函数调用将通过该管理器路由。
 * 然而，管理员可能会配置管理器，使其对治理合约希望直接调用的函数（例如，代币转移）提出该声明，以试图拒绝其访问这些函数。
 * 为了减轻这种攻击向量，治理合约能够使用 {setAccessManagerIgnored} 忽略 `AccessManager` 所声称的限制。
 * 虽然永久性的拒绝服务得到了缓解，但技术上仍然可能发生临时性的DoS。
 * 所有治理合约自身的函数（例如 {setBaseDelaySeconds}）默认都忽略 `AccessManager`。
 *
 * 注意：`AccessManager` 不支持同时调度多个具有相同目标和调用数据的操作。有关解决方法，请参见 {AccessManager-schedule}。
 */
 /*
    1. 核心目标：更精细、更灵活的时间锁
        > 治理合约（Governor）自己持有资产和权限，但它的某些特定行为会受到一个叫做 `AccessManager`（访问管理器） 的合约的延迟和限制。
        最大亮点：它不再是为所有提案设置一个统一的延迟时间，而是可以根据提案中调用的具体函数，实现差异化、精细化的延迟管理。
    2. 关键组件和概念
        * `AccessManager` (访问管理器): 
            这是一个“权限中心”合约，可以被管理员精细地配置，用来规定‘谁（比如Governor）’在‘什么时间’、‘延迟多久后’才能调用‘哪个合约的哪个函数’。
        * `ExecutionPlan` (执行计划): 
            在提案创建时，合约会预先为这个提案生成一份计划。这份计划会固化本次提案中每个操作的执行路径：是直接执行，还是需要通过 AccessManager 
            来执行并延迟。这可以防止 AccessManager 的规则在投票期间被修改而影响提案结果。
        * 直接执行 vs. 间接执行:
            * 直接: Governor 自己调用目标函数。用于那些 AccessManager 不加限制的普通操作。
            * 间接: Governor 请求 AccessManager 来代为执行。用于那些被 AccessManager 标记为“受限”的高风险操作。
    3. 提案生命周期详解
        1. `propose` (提议)
            * 当你提交一个提案时，合约会拿着提案里的每一个操作，去问 AccessManager：“这个操作我能做吗？需要延迟多久？”
            * 根据 AccessManager 的回答，它会生成一份详细的 ExecutionPlan，并计算出整个提案所需的最长延迟时间。
        2. `queue` (排队)
            * 调用排队函数时，合约会查看 ExecutionPlan。
            * 对于那些被标记为需要延迟的操作，它会通知 AccessManager：“请把这个操作加入你的日程表，准备在X时间后执行”。
        3. `execute` (执行)
            * 到了执行时间，合约再次查看 ExecutionPlan。
            * 对于标记为“间接执行”的操作，它会命令 AccessManager：“日程表上的那个操作，时间到了，你现在去执行吧”。
            * 对于标记为“直接执行”的操作，Governor 就自己亲自动手执行了。
 */
abstract contract GovernorTimelockAccess is Governor {
    // 执行计划在提案创建时生成，以便在那时确定提案的确切执行语义，即调用是否将通过 {AccessManager-execute}。
    struct ExecutionPlan {
        uint16 length;  // 提案中操作的数量
        uint32 delay;   // 延迟时间
        // 我们使用映射而不是数组，因为它允许我们在存储中更紧密地打包值，而无需冗余地存储长度。
        // 我们在每个桶中打包8个操作的数据。如果在提案创建时必须通过管理器进行调度和执行，则每个 uint32 值被设置为1。
        // 在排队时，该值被设置为 nonce + 2，其中 nonce 是在调度操作时从管理器接收的。
        mapping(uint256 operationBucket => uint32[8]) managerData;
    }

    // 设置为 true 的“切换”的含义取决于目标合约。
    // 如果 target == address(this)，管理器默认被忽略，一个 true 的切换意味着它将不会被忽略。
    // 对于所有其他目标合约，管理器默认被使用，一个 true 的切换意味着它将被忽略。
    /*
        赋予 Governor 合约一种最终否决权，让它可以在必要时忽略并绕过 `AccessManager` 的限制。
        1. 它是一个开关：_ignoreToggle 是一个映射 mapping(address target => mapping(bytes4 selector => 
            bool))，可以为任何合约的任何函数单独设置一个布尔（true/false）开关。
        2. 通过治理来控制：当 Governor 想要忽略 AccessManager 对某个函数（比如 token.transfer()）的限制时，社区可以通过一次治理投票，
            调用 setAccessManagerIgnored 函数，将这个开关设为 true。
        3. 绕过限制：开关设置之后，当 Governor 再创建包含 token.transfer() 的新提案时，它会检查这个开关，发现是 true，
            于是它就会完全无视 `AccessManager` 的规则，选择“直接执行”该操作，从而绕过了不合理的限制。
        值得注意的是，为了安全，这个开关对 Governor 自身函数和其他外部合约函数的默认行为是相反的：
            * 对于外部合约：默认是不忽略（听 AccessManager 的话）。
            * 对于 `Governor` 自己的函数：默认是忽略 AccessManager，这是为了防止 Governor 被 AccessManager 的错误配置锁死，从而无法执行任何操作。    
    */
    mapping(address target => mapping(bytes4 selector => bool)) private _ignoreToggle;

    mapping(uint256 proposalId => ExecutionPlan) private _executionPlan;

    // 应用于所有操作的基础延迟（以秒为单位）。某些操作可能会被其关联的 `AccessManager` 权限进一步延迟。
    // 在这种情况下，最终延迟将是基础延迟和权限要求的延迟中的最大值。
    uint32 private _baseDelay;

    // 与此治理合约关联的 AccessManager 实例。 该实例负责管理对受限函数的访问权限，并调度和执行这些函数调用
    IAccessManager private immutable _manager;

    error GovernorUnmetDelay(uint256 proposalId, uint256 neededTimestamp);
    error GovernorMismatchedNonce(uint256 proposalId, uint256 expectedNonce, uint256 actualNonce);
    error GovernorLockedIgnore();

    event BaseDelaySet(uint32 oldBaseDelaySeconds, uint32 newBaseDelaySeconds);
    event AccessManagerIgnoredSet(address target, bytes4 selector, bool ignored);

    /**
     * @dev 使用 {AccessManager} 和初始基础延迟来初始化治理合约。
     */
    constructor(address manager, uint32 initialBaseDelay) {
        _manager = IAccessManager(manager);
        _setBaseDelaySeconds(initialBaseDelay);
    }

    /**
     * @dev 返回与此治理合约关联的 {AccessManager} 实例。
     */
    function accessManager() public view virtual returns (IAccessManager) {
        return _manager;
    }

    /**
     * @dev 将应用于所有函数调用的基础延迟。某些调用可能会被其关联的 `AccessManager` 权限进一步延迟；在这种情况下，最终延迟将是基础延迟和权限要求的延迟中的最大值。
     *
     * 注意：执行延迟由 `AccessManager` 合约处理，并根据该合约以秒为单位表示。因此，无论治理合约的时钟模式如何，基础延迟也以秒为单位。
     */
    function baseDelaySeconds() public view virtual returns (uint32) {
        return _baseDelay;
    }

    /**
     * @dev 更改 {baseDelaySeconds} 的值。此操作只能通过治理提案调用。
     */
    function setBaseDelaySeconds(uint32 newBaseDelay) public virtual onlyGovernance {
        _setBaseDelaySeconds(newBaseDelay);
    }

    /**
     * @dev 更改 {baseDelaySeconds} 的值。无访问控制的内部函数。
     */
    function _setBaseDelaySeconds(uint32 newBaseDelay) internal virtual {
        emit BaseDelaySet(_baseDelay, newBaseDelay);
        _baseDelay = newBaseDelay;
    }

    /**
     * @dev 检查是否忽略来自关联 {AccessManager} 的对目标函数的限制。当目标函数将无论 `AccessManager` 对该函数的设置如何都直接被调用时，返回 true。
     * 参见 {setAccessManagerIgnored} 和上面的安全考量。
     */
     /*
        对于某个合约（target）的某个函数（selector），我（Governor）在执行它时，应不应该忽略 AccessManager 的规则？
        它返回 true 意味着“应该忽略”，返回 false 意味着“不应该忽略”。
        情况一：目标是外部合约 (例如，一个ERC20代币合约)
            1. 在这种情况下，target == address(this) 为 false，所以 isGovernor 变量也是 false。
            2. 核心逻辑 return _ignoreToggle[...] != false; 就等价于 return _ignoreToggle[...];。
            3. 解读：对于外部合约，这个函数直接返回 _ignoreToggle 开关的原始值。
                * 默认 (`_ignoreToggle` 为 `false`): 函数返回 false，含义是“不忽略”。这是默认行为，意味着 Governor 会遵守 AccessManager 
                    对这个外部函数的所有规则。
                * 当开关被设为 `true`: 函数返回 true，含义是“忽略”。这意味着 Governor 将绕过 AccessManager，直接执行这个外部函数。
        情况二：目标是 Governor 合约自身
            1. 在这种情况下，target == address(this) 为 true，所以 isGovernor 变量也是 true。
            2. 核心逻辑 return _ignoreToggle[...] != true; 就等价于 return !_ignoreToggle[...];。
            3. 解读：对于 Governor 自己的函数，这个函数返回 _ignoreToggle 开关的相反值。
                * 默认 (`_ignoreToggle` 为 `false`): 函数返回 !false，即 true。含义是“忽略”。这是最重要的安全默认设置，确保 Governor 不会被 
                    AccessManager 的错误配置锁死，能正常运行自己的核心功能。
                * 当开关被设为 `true`: 函数返回 !true，即 false。含义是“不忽略”。这是一个“主动选择（Opt-in）”行为，意味着社区通过治理，明确希望将 
                    Governor 的某个内部函数也置于 AccessManager 的监管之下。        
     */
    function isAccessManagerIgnored(address target, bytes4 selector) public view virtual returns (bool) {
        // 是否
        bool isGovernor = target == address(this);
        return _ignoreToggle[target][selector] != isGovernor; // 等价于: isGovernor ? !toggle : toggle
    }

    /**
     * @dev 配置是否忽略来自关联 {AccessManager} 的对目标函数的限制。
     * 参见上面的安全考量。
     */
    function setAccessManagerIgnored(
        address target,
        bytes4[] calldata selectors,
        bool ignored
    ) public virtual onlyGovernance {
        for (uint256 i = 0; i < selectors.length; ++i) {
            _setAccessManagerIgnored(target, selectors[i], ignored);
        }
    }

    /**
     * @dev {setAccessManagerIgnored} 的内部版本，无访问限制。
     */
    function _setAccessManagerIgnored(address target, bytes4 selector, bool ignored) internal virtual {
        bool isGovernor = target == address(this);
        // Governor 自身的函数必须始终忽略 AccessManager，不能被关闭
        if (isGovernor && selector == this.setAccessManagerIgnored.selector) {
            revert GovernorLockedIgnore();
        }
        _ignoreToggle[target][selector] = ignored != isGovernor; // 等价于: isGovernor ? !ignored : ignored
        emit AccessManagerIgnoredSet(target, selector, ignored);
    }

    /**
     * @dev 用于检查执行计划的公共访问器，包括提案自排队以来将被延迟的秒数，一个指示哪些提案操作将通过关联的 {AccessManager} 间接执行的数组，以及另一个指示哪些将在 {queue} 中调度的数组。请注意，那些必须被调度的操作可由 `AccessManager` 的监护人取消。
     */
    function proposalExecutionPlan(
        uint256 proposalId
    ) public view returns (uint32 delay, bool[] memory indirect, bool[] memory withDelay) {
        ExecutionPlan storage plan = _executionPlan[proposalId];

        uint32 length = plan.length;
        delay = plan.delay;
        indirect = new bool[](length);
        withDelay = new bool[](length);
        for (uint256 i = 0; i < length; ++i) {
            (indirect[i], withDelay[i], ) = _getManagerData(plan, i);
        }

        return (delay, indirect, withDelay);
    }

    /// @inheritdoc IGovernor
    // 是否需要排队
    function proposalNeedsQueuing(uint256 proposalId) public view virtual override returns (bool) {
        return _executionPlan[proposalId].delay > 0;
    }

    /// @inheritdoc IGovernor
    // 发起提案时，生成执行计划
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        // 调用父合约的 propose 来创建提案
        uint256 proposalId = super.propose(targets, values, calldatas, description);

        // 获取所需的基础延迟
        uint32 neededDelay = baseDelaySeconds();

        ExecutionPlan storage plan = _executionPlan[proposalId];
        plan.length = SafeCast.toUint16(targets.length);    // 提案中的操作数量

        for (uint256 i = 0; i < targets.length; ++i) {
            // calldatas[i] 至少应包含函数选择器（4字节）
            if (calldatas[i].length < 4) {
                continue;
            }
            address target = targets[i];
            bytes4 selector = bytes4(calldatas[i]);
            // 检查调用是否需要通过 AccessManager 进行调度和执行
            (bool immediate, uint32 delay) = AuthorityUtils.canCallWithDelay(
                address(_manager),
                address(this),
                target,
                selector
            );
            // 如果需要延迟，且未被忽略，则更新执行计划,并更新所需的最大延迟
            // 如果被忽略,则延迟时间使用基础延迟
            if ((immediate || delay > 0) && !isAccessManagerIgnored(target, selector)) {
                // 设置管理员标记
                _setManagerData(plan, i, !immediate, 0);
                // downcast is safe because both arguments are uint32
                neededDelay = uint32(Math.max(delay, neededDelay));
            }
        }

        // 更新延迟
        plan.delay = neededDelay;

        return proposalId;
    }

    /**
     * @dev 用于将提案排队的机制，可能会在 AccessManager 中调度其某些操作。
     *
     * 注意：执行延迟是根据在 {propose} 中检索到的延迟信息选择的。如果自提案创建以来延迟已更新，则此值可能不准确。在这种情况下，需要重新创建提案。
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory /* values */,
        bytes[] memory calldatas,
        bytes32 /* descriptionHash */
    ) internal virtual override returns (uint48) {
        // 提案信息
        ExecutionPlan storage plan = _executionPlan[proposalId];
        // 排队时间
        uint48 etaSeconds = Time.timestamp() + plan.delay;

        for (uint256 i = 0; i < targets.length; ++i) {
            (, bool withDelay, ) = _getManagerData(plan, i);
            // 仅调度那些需要延迟的操作
            if (withDelay) {
                // 在 `_setManagerData` 中执行状态更新之前调用 `_manager.schedule` 时，此函数可能重入。
                // 然而，在当前上下文的安全模型中，`manager` 是一个受信任的合约（例如一个 `AccessManager`）。
                // slither-disable-next-line reentrancy-no-eth
                (, uint32 nonce) = _manager.schedule(targets[i], calldatas[i], etaSeconds);
                _setManagerData(plan, i, true, nonce);
            }
        }

        return etaSeconds;
    }

    /**
     * @dev 用于执行提案的机制，可能会对延迟的操作通过 {AccessManager-execute} 执行。
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 /* descriptionHash */
    ) internal virtual override {
        // 时间未到
        uint48 etaSeconds = SafeCast.toUint48(proposalEta(proposalId));
        if (block.timestamp < etaSeconds) {
            revert GovernorUnmetDelay(proposalId, etaSeconds);
        }

        ExecutionPlan storage plan = _executionPlan[proposalId];

        for (uint256 i = 0; i < targets.length; ++i) {
            (bool controlled, bool withDelay, uint32 nonce) = _getManagerData(plan, i);
            // 受管理器控制的调用通过管理器执行
            if (controlled) {
                uint32 executedNonce = _manager.execute{value: values[i]}(targets[i], calldatas[i]);
                if (withDelay && executedNonce != nonce) {
                    revert GovernorMismatchedNonce(proposalId, nonce, executedNonce);
                }
            } else { // 直接执行
                (bool success, bytes memory returndata) = targets[i].call{value: values[i]}(calldatas[i]);
                Address.verifyCallResult(success, returndata);
            }
        }
    }

    /// @inheritdoc Governor
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override returns (uint256) {
        uint256 proposalId = super._cancel(targets, values, calldatas, descriptionHash);

        uint48 etaSeconds = SafeCast.toUint48(proposalEta(proposalId));

        ExecutionPlan storage plan = _executionPlan[proposalId];

        // 如果提案已被调度，它将有一个ETA，我们可能需要从外部取消
        if (etaSeconds != 0) {
            for (uint256 i = 0; i < targets.length; ++i) {
                (, bool withDelay, uint32 nonce) = _getManagerData(plan, i);
                // 仅当执行计划包含延迟时才尝试取消
                if (withDelay) {
                    bytes32 operationId = _manager.hashOperation(address(this), targets[i], calldatas[i]);
                    // 首先检查当前操作的 nonce 是否是我们之前观察到的那个。它可能已经被取消并重新调度了。除非它正是我们之前调度的那个实例，否则我们不想取消。
                    if (nonce == _manager.getNonce(operationId)) {
                        // 很重要的一点是，所有调用都应有机会被取消。
                        // 我们选择忽略某些取消操作的潜在失败，以便让其他操作有机会被正确取消。
                        // 特别是，如果操作之前已被监护人取消，取消操作可能会失败。
                        // 我们不匹配 revert 原因，以避免对特定错误进行编码假设。
                        try _manager.cancel(address(this), targets[i], calldatas[i]) {} catch {}
                    }
                }
            }
        }

        return proposalId;
    }

    /**
     * @dev 返回索引处的操作是否被管理器延迟，以及一旦排队后的调度 nonce。
     */
    /*
        1 // return (value > 0, value > 1, value > 1 ? value - 2 : 0);
        2 //         (是否受控, 是否延迟, nonce)
        * 如果值是 0 (默认值)：controlled 为 false，说明不受控。
        * 如果值是 1：controlled 为 true，但 withDelay 为 false，说明受控但无延迟。
        * 如果值 大于1（例如 nonce + 2）：controlled 和 withDelay 都为 true，说明受控且有延迟，并且 nonce 就是 值 - 2。
    */
    function _getManagerData(
        ExecutionPlan storage plan,
        uint256 index
    ) private view returns (bool controlled, bool withDelay, uint32 nonce) {
        (uint256 bucket, uint256 subindex) = _getManagerDataIndices(index);
        uint32 value = plan.managerData[bucket][subindex];
        unchecked {
            return (value > 0, value > 1, value > 1 ? value - 2 : 0);
        }
    }

    /**
     * @dev 将索引处的操作标记为由管理器许可，可能延迟，并在延迟时设置其调度 nonce。
     */
    /*
        1. 核心作用：高效编码“执行计划”
            它的核心作用是以一种极为节省空间（Gas Efficient）的方式，记录提案中每一个操作（operation）的执行信息。
            对于提案中的每一个操作，它需要记录三个关键信息：
                1. 是否受 `AccessManager` 控制？
                2. 如果受控制，是否需要延迟执行？
                3. 如果需要延迟，它在 AccessManager 中的调度 `nonce` 是多少？
        2. 存储的奥秘：managerData 和位运算
            为了节省Gas，合约没有使用简单的数组，而是用了一个 mapping(uint256 => uint32[8]) managerData 结构。
            它将每8个操作的信息打包存放在一个固定大小的 uint32[8] 数组（称为一个“桶”，bucket）里。
            _getManagerDataIndices 函数通过位运算（index >> 3 等价于 index / 8，index & 7 等价于 index % 8）
            快速计算出任何一个操作应该存放在哪个“桶”的哪个“位置”上。  
        3. 编码逻辑详解
            这个函数最精妙的部分是将上述三个信息（是否受控、是否延迟、nonce）编码（encode）成一个 uint32 的数字。解码逻辑在 _getManagerData 
            函数中，我们结合来看就非常清晰了。
            编码规则是：
                1 plan.managerData[bucket][subindex] = withDelay ? nonce + 2 : 1;

            这行代码根据不同的情况，将不同的数值存入 managerData：
            * 情况A：操作受控但无需延迟
                * 在 propose 函数中，如果一个操作被 AccessManager 限制但可以立即执行，withDelay 会是 false。
                * 此时，代码执行 ... = 1。存入的值是 1。
            * 情况B：操作受控且需要延迟
                * 在 queue 函数中，当操作被成功调度到 AccessManager 后，withDelay 是 true，并且会从 AccessManager 获得一个 nonce。
                * 此时，代码执行 ... = nonce + 2。存入的值是 `nonce + 2`。          
    */
    function _setManagerData(ExecutionPlan storage plan, uint256 index, bool withDelay, uint32 nonce) private {
        (uint256 bucket, uint256 subindex) = _getManagerDataIndices(index);
        plan.managerData[bucket][subindex] = withDelay ? nonce + 2 : 1;
    }

    /**
     * @dev 返回用于从打包的数组映射中读取管理器数据的桶和子索引。
     */
    function _getManagerDataIndices(uint256 index) private pure returns (uint256 bucket, uint256 subindex) {
        bucket = index >> 3; // index / 8
        subindex = index & 7; // index % 8
    }
}
