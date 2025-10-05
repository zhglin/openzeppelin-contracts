// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (vendor/compound/ICompoundTimelock.sol)

pragma solidity >=0.6.9;

/**
 * https://github.com/compound-finance/compound-protocol/blob/master/contracts/Timelock.sol[Compound timelock] interface
 */
 /*
    1. 它是第三方标准，而非 OZ 自创
        Compound 时间锁是 Compound 协议 设计和实现的，它是一个在 DeFi 领域被广泛采用的“外部标准”。
        OpenZeppelin 在这里扮演的角色是“连接器”或“适配器”。他们提供 GovernorTimelockCompound 这个模块，
        目的是让使用 OpenZeppelin Governor 的项目能够方便地与已经存在的、广泛使用的 Compound 生态系统进行集成。
 */
interface ICompoundTimelock {
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    receive() external payable;

    // solhint-disable-next-line func-name-mixedcase
    function GRACE_PERIOD() external view returns (uint256);

    // solhint-disable-next-line func-name-mixedcase
    function MINIMUM_DELAY() external view returns (uint256);

    // solhint-disable-next-line func-name-mixedcase
    function MAXIMUM_DELAY() external view returns (uint256);

    function admin() external view returns (address);

    function pendingAdmin() external view returns (address);

    function delay() external view returns (uint256);

    function queuedTransactions(bytes32) external view returns (bool);

    function setDelay(uint256) external;

    function acceptAdmin() external;

    function setPendingAdmin(address) external;

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable returns (bytes memory);
}
