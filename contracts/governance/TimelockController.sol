// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/TimelockController.sol)

pragma solidity ^0.8.20;

import {AccessControl} from "../access/AccessControl.sol";
import {ERC721Holder} from "../token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "../token/ERC1155/utils/ERC1155Holder.sol";
import {Address} from "../utils/Address.sol";
import {IERC165} from "../utils/introspection/ERC165.sol";

/**
 * @dev 合约模块，充当一个带时间锁的控制器。当被设置为一个 `Ownable` 智能合约的所有者时，
 * 它会对所有 `onlyOwner` 的维护操作强制执行一个时间锁。
 * 这给了被控制合约的用户在潜在危险的维护操作被应用前退出的时间。
 *
 * 默认情况下，此合约是自我管理的，意味着管理任务必须经过时间锁流程。
 * 提案者（proposer）角色负责提议操作，
 * 执行者（executor）角色负责执行操作。
 * 一个常见的用例是将此 {TimelockController} 设置为某个智能合约的所有者，并将一个多签钱包或一个 DAO 设置为唯一的提案者。
 *  通过继承Ownable.sol合约的合约可以使用 {_transferOwnership} 函数将所有权转移到时间锁合约。
 *  所有需要所有者权限的操作（即 onlyOwner 函数），现在都必须经过“提案 -> 投票 -> 等待 -> 执行”的流程。
 * 
 * 执行者角色通常设置为 `address(0)`，这意味着任何人都可以执行就绪的操作。
 * 这允许任何人帮助完成时间锁的执行过程，而无需信任特定的执行者。
 * 取消者（canceller）角色允许撤销待定的操作。      
 */
/*
    predecessor参数是指前置操作的ID。如果一个操作有前置操作，那么在执行这个操作之前，必须先确保前置操作已经完成。
    对于复杂的、需要多个步骤才能完成的治理任务，执行顺序至关重要。如果顺序错误，可能会导致整个任务失败，甚至让协议处于一个不安全或损坏的状态。
    通过使用predecessor参数，可以确保操作按照正确的顺序执行，从而维护协议的完整性和安全性。
*/
/*
    ERC721Holder, ERC1155Holder,提供接受ERC721和ERC1155代币的能力。
    这对于时间锁合约来说是有用的，因为它可能需要持有这些类型的代币，作为治理提案的一部分。
    例如，一个治理提案可能涉及将某些ERC721或ERC1155代币转移到另一个地址。
*/
contract TimelockController is AccessControl, ERC721Holder, ERC1155Holder {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    
    // 已完成的操作的时间戳
    uint256 internal constant _DONE_TIMESTAMP = uint256(1);

    // 操作 ID 到时间戳的映射
    mapping(bytes32 id => uint256) private _timestamps;

    // 最小延迟时间（以秒为单位）
    uint256 private _minDelay;

    // 操作的状态
    enum OperationState {
        Unset,
        Waiting,
        Ready,
        Done
    }

    /**
     * @dev 操作调用的参数长度不匹配。
     */
    error TimelockInvalidOperationLength(uint256 targets, uint256 payloads, uint256 values);

    /**
     * @dev 计划的操作不满足最小延迟时间。
     */
    error TimelockInsufficientDelay(uint256 delay, uint256 minDelay);

    /**
     * @dev 操作的当前状态不符合要求。
     * `expectedStates` 是一个位图，其中启用的位对应于 OperationState 枚举中从右到左计数的位置。
     *
     * 参见 {_encodeStateBitmap}。
     */
    error TimelockUnexpectedOperationState(bytes32 operationId, bytes32 expectedStates);

    /**
     * @dev 操作的前置操作尚未完成。
     */
    error TimelockUnexecutedPredecessor(bytes32 predecessorId);

    /**
     * @dev 调用者账户未被授权。
     */
    error TimelockUnauthorizedCaller(address caller);

    /**
     * @dev 当一个调用作为操作 `id` 的一部分被计划时触发。
     */
    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    /**
     * @dev 当一个调用作为操作 `id` 的一部分被执行时触发。
     */
    event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);

    /**
     * @dev 当一个带有非零盐值的新提案被计划时触发。
     */
    event CallSalt(bytes32 indexed id, bytes32 salt);

    /**
     * @dev 当操作 `id` 被取消时触发。
     */
    event Cancelled(bytes32 indexed id);

    /**
     * @dev 当未来操作的最小延迟时间被修改时触发。
     */
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    /**
     * @dev 使用以下参数初始化合约：
     *
     * - `minDelay`: 操作的初始最小延迟时间（以秒为单位）
     * - `proposers`: 将被授予提案者和取消者角色的账户
     * - `executors`: 将被授予执行者角色的账户
     * - `admin`: 可选的将被授予管理员角色的账户；使用零地址禁用
     *
     * 重要提示：可选的管理员可以在部署后帮助进行角色的初始配置，而无需受制于时间延迟，
     * 但此角色随后应被放弃，以支持通过带时间锁的提案进行管理。
     * 此合约的先前版本会自动将此管理员分配给部署者，也应同样放弃。
     */
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin) {
        // 自我管理
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));

        // 可选的管理员
        if (admin != address(0)) {
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
        }

        // 注册提案者和取消者
        for (uint256 i = 0; i < proposers.length; ++i) {
            _grantRole(PROPOSER_ROLE, proposers[i]);
            _grantRole(CANCELLER_ROLE, proposers[i]);
        }

        // 注册执行者
        for (uint256 i = 0; i < executors.length; ++i) {
            _grantRole(EXECUTOR_ROLE, executors[i]);
        }

        _minDelay = minDelay;
        emit MinDelayChange(0, minDelay);
    }

    /**
     * @dev 修改器，使函数只能由特定角色调用。除了检查发送者的角色外，
     * `address(0)` 的角色也会被考虑。将角色授予 `address(0)` 等同于为所有人启用此角色。
     */
    modifier onlyRoleOrOpenRole(bytes32 role) {
        if (!hasRole(role, address(0))) { // address(0) 具有此角色
            _checkRole(role, _msgSender());
        }
        _;
    }

    /**
     * @dev 作为维护过程的一部分，合约可能会接收/持有 ETH。
     */
    receive() external payable virtual {}

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev 返回一个 id 是否对应一个已注册的操作。这包括等待中、就绪和已完成的操作。
     */
    function isOperation(bytes32 id) public view returns (bool) {
        return getOperationState(id) != OperationState.Unset;
    }

    /**
     * @dev 返回一个操作是否处于待定状态。请注意，“待定”操作也可能是“就绪”状态。
     */
    function isOperationPending(bytes32 id) public view returns (bool) {
        OperationState state = getOperationState(id);
        return state == OperationState.Waiting || state == OperationState.Ready;
    }

    /**
     * @dev 返回一个操作是否已准备好执行。请注意，“就绪”操作也是“待定”状态。
     */
    function isOperationReady(bytes32 id) public view returns (bool) {
        return getOperationState(id) == OperationState.Ready;
    }

    /**
     * @dev 返回一个操作是否已完成。
     */
    function isOperationDone(bytes32 id) public view returns (bool) {
        return getOperationState(id) == OperationState.Done;
    }

    /**
     * @dev 返回一个操作变为就绪状态的时间戳（对于未设置的操作为 0，对于已完成的操作为 1）。
     */
    function getTimestamp(bytes32 id) public view virtual returns (uint256) {
        return _timestamps[id];
    }

    /**
     * @dev 返回操作的状态。
     */
    function getOperationState(bytes32 id) public view virtual returns (OperationState) {
        uint256 timestamp = getTimestamp(id);
        if (timestamp == 0) {
            return OperationState.Unset;
        } else if (timestamp == _DONE_TIMESTAMP) {
            return OperationState.Done;
        } else if (timestamp > block.timestamp) {
            return OperationState.Waiting;
        } else {
            return OperationState.Ready;
        }
    }

    /**
     * @dev 返回一个操作生效所需的最小延迟时间（以秒为单位）。
     *
     * 这个值可以通过执行一个调用 `updateDelay` 的操作来更改。
     */
    function getMinDelay() public view virtual returns (uint256) {
        return _minDelay;
    }

    /**
     * @dev 返回包含单个交易的操作的标识符。
     */
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual returns (bytes32) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    /**
     * @dev 返回包含一批交易的操作的标识符。
     */
    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) public pure virtual returns (bytes32) {
        return keccak256(abi.encode(targets, values, payloads, predecessor, salt));
    }

    /**
     * @dev 计划一个包含单个交易的操作。
     *
     * 如果 salt 非零，则触发 {CallSalt} 事件，并触发 {CallScheduled} 事件。
     *
     * 要求：
     *
     * - 调用者必须拥有“提案者”角色。
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual onlyRole(PROPOSER_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        _schedule(id, delay);
        emit CallScheduled(id, 0, target, value, data, predecessor, delay);
        if (salt != bytes32(0)) {
            emit CallSalt(id, salt);
        }
    }

    /**
     * @dev 计划一个包含一批交易的操作。
     *
     * 如果 salt 非零，则触发 {CallSalt} 事件，并为批处理中的每个交易触发一个 {CallScheduled} 事件。
     *
     * 要求：
     *
     * - 调用者必须拥有“提案者”角色。
     */
    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual onlyRole(PROPOSER_ROLE) {
        if (targets.length != values.length || targets.length != payloads.length) {
            revert TimelockInvalidOperationLength(targets.length, payloads.length, values.length);
        }

        bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);
        _schedule(id, delay);
        for (uint256 i = 0; i < targets.length; ++i) {
            emit CallScheduled(id, i, targets[i], values[i], payloads[i], predecessor, delay);
        }
        if (salt != bytes32(0)) {
            emit CallSalt(id, salt);
        }
    }

    /**
     * @dev 计划一个在给定延迟后生效的操作。
     */
    function _schedule(bytes32 id, uint256 delay) private {
        if (isOperation(id)) {
            revert TimelockUnexpectedOperationState(id, _encodeStateBitmap(OperationState.Unset));
        }
        uint256 minDelay = getMinDelay();
        if (delay < minDelay) {
            revert TimelockInsufficientDelay(delay, minDelay);
        }
        _timestamps[id] = block.timestamp + delay;
    }

    /**
     * @dev 取消一个操作。
     *
     * 要求：
     *
     * - 调用者必须拥有“取消者”角色。
     */
    function cancel(bytes32 id) public virtual onlyRole(CANCELLER_ROLE) {
        if (!isOperationPending(id)) {
            revert TimelockUnexpectedOperationState(
                id,
                _encodeStateBitmap(OperationState.Waiting) | _encodeStateBitmap(OperationState.Ready)
            );
        }
        delete _timestamps[id];

        emit Cancelled(id);
    }

    /**
     * @dev 执行一个（已就绪的）包含单个交易的操作。
     *
     * 触发一个 {CallExecuted} 事件。
     *
     * 要求：
     *
     * - 调用者必须拥有“执行者”角色。
     */
    // 这个函数可能重入，但不存在风险，因为 _afterCall 会检查提案是否处于待定状态，
    // 因此在重入期间对操作的任何修改都应该被捕获。
    // slither-disable-next-line reentrancy-eth
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, payload, predecessor, salt);

        _beforeCall(id, predecessor);
        _execute(target, value, payload);
        emit CallExecuted(id, 0, target, value, payload);
        _afterCall(id);
    }

    /**
     * @dev 执行一个（已就绪的）包含一批交易的操作。
     *
     * 为批处理中的每个交易触发一个 {CallExecuted} 事件。
     *
     * 要求：
     *
     * - 调用者必须拥有“执行者”角色。
     */
    // 这个函数可能重入，但不存在风险，因为 _afterCall 会检查提案是否处于待定状态，
    // 因此在重入期间对操作的任何修改都应该被捕获。
    // slither-disable-next-line reentrancy-eth
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual onlyRoleOrOpenRole(EXECUTOR_ROLE) {
        if (targets.length != values.length || targets.length != payloads.length) {
            revert TimelockInvalidOperationLength(targets.length, payloads.length, values.length);
        }

        bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);

        _beforeCall(id, predecessor);
        for (uint256 i = 0; i < targets.length; ++i) {
            address target = targets[i];
            uint256 value = values[i];
            bytes calldata payload = payloads[i];
            _execute(target, value, payload);
            emit CallExecuted(id, i, target, value, payload);
        }
        _afterCall(id);
    }

    /**
     * @dev 执行一个操作的调用。
     */
    function _execute(address target, uint256 value, bytes calldata data) internal virtual {
        // 执行调用
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        Address.verifyCallResult(success, returndata);
    }

    /**
     * @dev 在执行操作调用之前进行检查。
     */
    function _beforeCall(bytes32 id, bytes32 predecessor) private view {
        // 是否就绪
        if (!isOperationReady(id)) {
            revert TimelockUnexpectedOperationState(id, _encodeStateBitmap(OperationState.Ready));
        }
        // 前置操作是否已完成
        if (predecessor != bytes32(0) && !isOperationDone(predecessor)) {
            revert TimelockUnexecutedPredecessor(predecessor);
        }
    }

    /**
     * @dev 在执行操作调用之后进行检查。
     */
    function _afterCall(bytes32 id) private {
        if (!isOperationReady(id)) {
            revert TimelockUnexpectedOperationState(id, _encodeStateBitmap(OperationState.Ready));
        }
        // 设置完成状态
        _timestamps[id] = _DONE_TIMESTAMP;
    }

    /**
     * @dev 更改未来操作的最小时间锁时长。
     *
     * 触发一个 {MinDelayChange} 事件。
     *
     * 要求：
     *
     * - 调用者必须是时间锁合约本身。这只能通过计划并随后执行一个
     *   操作来实现，其中时间锁是目标，数据是此函数的 ABI 编码调用。
     */
    function updateDelay(uint256 newDelay) external virtual {
        address sender = _msgSender();
        // 只能由合约本身调用,通过schedule函数调用
        if (sender != address(this)) {
            revert TimelockUnauthorizedCaller(sender);
        }
        emit MinDelayChange(_minDelay, newDelay);
        _minDelay = newDelay;
    }

    /**
     * @dev 将一个 `OperationState` 编码为一个 `bytes32` 表示，其中每个启用的位对应于
     * `OperationState` 枚举中的基础位置。例如：
     *
     * 0x000...1000
     *   ^^^^^^----- ...
     *         ^---- Done (已完成)
     *          ^--- Ready (就绪)
     *           ^-- Waiting (等待中)
     *            ^- Unset (未设置)
     */
    function _encodeStateBitmap(OperationState operationState) internal pure returns (bytes32) {
        // 它将数字 1 的二进制表示向左移动指定的位数。
        return bytes32(1 << uint8(operationState));
    }
}
