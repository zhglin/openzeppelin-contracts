// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC7579.sol)

pragma solidity >=0.8.4;

import {PackedUserOperation} from "./draft-IERC4337.sol";

uint256 constant VALIDATION_SUCCESS = 0;    // 验证成功
uint256 constant VALIDATION_FAILED = 1;     // 验证失败
uint256 constant MODULE_TYPE_VALIDATOR = 1; // 模块类型 ID，用于验证模块
uint256 constant MODULE_TYPE_EXECUTOR = 2;  // 模块类型 ID，用于执行模块
uint256 constant MODULE_TYPE_FALLBACK = 3;  // 模块类型 ID，用于回退模块
uint256 constant MODULE_TYPE_HOOK = 4;      // 模块类型 ID，用于挂钩模块

/// @dev ERC-7579 模块的最小配置接口
interface IERC7579Module {
    /**
     * @dev 此函数在模块安装期间由智能帐户调用
     * @param data 在 `onInstall` 初始化期间可以传递给模块的任意数据
     *
     * 必须在出错时回滚（例如，如果模块已启用）
     */
    function onInstall(bytes calldata data) external;

    /**
     * @dev 此函数在模块卸载期间由智能帐户调用
     * @param data 在 `onUninstall` 卸载期间可以传递给模块的任意数据
     *
     * 必须在出错时回滚
     */
    function onUninstall(bytes calldata data) external;

    /**
     * @dev 如果模块是某种类型，则返回布尔值
     * @param moduleTypeId 根据 ERC-7579 规范的模块类型 ID
     *
     * 如果模块是给定类型，则必须返回 true，否则返回 false
     */
    function isModuleType(uint256 moduleTypeId) external view returns (bool);
}

/**
 * @dev ERC-7579 验证模块（类型 1）。
 *
 * 实现验证用户操作和签名逻辑的模块。
 */
interface IERC7579Validator is IERC7579Module {
    /**
     * @dev 验证 UserOperation
     * @param userOp ERC-4337 PackedUserOperation
     * @param userOpHash ERC-4337 PackedUserOperation 的哈希值
     *
     * 必须验证签名是 userOpHash 的有效签名
     * 在签名不匹配时应返回 ERC-4337 的 SIG_VALIDATION_FAILED（而不是回滚）
     * 有关返回值的其他信息，请参阅 {IAccount-validateUserOp}
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external returns (uint256);

    /**
     * @dev 使用 ERC-1271 验证签名
     * @param sender 向智能帐户发送 ERC-1271 请求的地址
     * @param hash ERC-1271 请求的哈希值
     * @param signature ERC-1271 请求的签名
     *
     * 如果签名有效，则必须返回 ERC-1271 `MAGIC_VALUE`
     * 不得修改状态
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    ) external view returns (bytes4);
}

/**
 * @dev ERC-7579 挂钩模块（类型 4）。
 *
 * 一个模块，它实现在帐户执行用户操作之前和之后执行的逻辑，
 * 可以单独执行，也可以批量执行。
 */
interface IERC7579Hook is IERC7579Module {
    /**
     * @dev 在执行前由智能帐户调用
     * @param msgSender 调用智能帐户的地址
     * @param value 发送到智能帐户的值
     * @param msgData 发送到智能帐户的数据
     *
     * 可以在 `hookData` 返回值中返回任意数据
     */
    function preCheck(
        address msgSender,
        uint256 value,
        bytes calldata msgData
    ) external returns (bytes memory hookData);

    /**
     * @dev 执行后由智能帐户调用
     * @param hookData `preCheck` 函数返回的数据
     *
     * 可以验证 `hookData` 以验证 `preCheck` 函数的交易上下文
     */
    function postCheck(bytes calldata hookData) external;
}

struct Execution {
    address target;
    uint256 value;
    bytes callData;
}

/**
 * @dev ERC-7579 执行。
 *
 * 帐户应实现此接口，以便入口点和 ERC-7579 模块可以执行操作。
 */
interface IERC7579Execution {
    /**
     * @dev 代表帐户执行交易。
     * @param mode 交易的编码执行模式。有关详细信息，请参阅 ModeLib.sol
     * @param executionCalldata 编码的执行调用数据
     *
     * 必须确保足够的授权控制：例如，如果与 ERC-4337 一起使用，则为 onlyEntryPointOrSelf
     * 如果请求的模式不受帐户支持，则必须回滚
     */
    function execute(bytes32 mode, bytes calldata executionCalldata) external payable;

    /**
     * @dev 代表帐户执行交易。
     *         此函数旨在由执行器模块调用
     * @param mode 交易的编码执行模式。有关详细信息，请参阅 ModeLib.sol
     * @param executionCalldata 编码的执行调用数据
     * @return returnData 包含每个已执行子调用的返回数据的数组
     *
     * 必须确保足够的授权控制：即 onlyExecutorModule
     * 如果请求的模式不受帐户支持，则必须回滚
     */
    function executeFromExecutor(
        bytes32 mode,
        bytes calldata executionCalldata
    ) external payable returns (bytes[] memory returnData);
}

/**
 * @dev ERC-7579 帐户配置。
 *
 * 帐户应实现此接口以公开标识帐户、支持的模块和功能的信息。
 */
interface IERC7579AccountConfig {
    /**
     * @dev 返回智能帐户的帐户 ID
     * @return accountImplementationId 智能帐户的帐户 ID
     *
     * 必须返回非空字符串
     * accountId 的结构应如下所示：
     *        "vendorname.accountname.semver"
     * 该 ID 在所有智能帐户中应是唯一的
     */
    function accountId() external view returns (string memory accountImplementationId);

    /**
     * @dev 用于检查帐户是否支持某个执行模式的函数（见上文）
     * @param encodedMode 编码模式
     *
     * 如果帐户支持该模式，则必须返回 true，否则返回 false
     */
    function supportsExecutionMode(bytes32 encodedMode) external view returns (bool);

    /**
     * @dev 用于检查帐户是否支持某个模块 typeId 的函数
     * @param moduleTypeId 根据 ERC-7579 规范的模块类型 ID
     *
     * 如果帐户支持该模块类型，则必须返回 true，否则返回 false
     */
    function supportsModule(uint256 moduleTypeId) external view returns (bool);
}

/**
 * @dev ERC-7579 模块配置。
 *
 * 帐户应实现此接口以允许安装和卸载模块。
 */
interface IERC7579ModuleConfig {
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);

    /**
     * @dev 在智能帐户上安装某种类型的模块
     * @param moduleTypeId 根据 ERC-7579 规范的模块类型 ID
     * @param module 模块地址
     * @param initData 在 `onInstall` 初始化期间可以传递给模块的任意数据。
     *
     * 必须实现授权控制
     * 如果提供了 `initData` 参数，则必须在模块上调用 `onInstall`
     * 必须发出 ModuleInstalled 事件
     * 如果模块已安装或模块上的初始化失败，则必须回滚
     */
    function installModule(uint256 moduleTypeId, address module, bytes calldata initData) external;

    /**
     * @dev 在智能帐户上卸载某种类型的模块
     * @param moduleTypeId 根据 ERC-7579 规范的模块类型 ID
     * @param module 模块地址
     * @param deInitData 在 `onUninstall` 卸载期间可以传递给模块的任意数据。
     *
     * 必须实现授权控制
     * 如果提供了 `deInitData` 参数，则必须在模块上调用 `onUninstall`
     * 必须发出 ModuleUninstalled 事件
     * 如果模块未安装或模块上的卸载失败，则必须回滚
     */
    function uninstallModule(uint256 moduleTypeId, address module, bytes calldata deInitData) external;

    /**
     * @dev 返回模块是否安装在智能帐户上
     * @param moduleTypeId 根据 ERC-7579 规范的模块类型 ID
     * @param module 模块地址
     * @param additionalContext 可传递的任意数据，用于确定模块是否已安装
     *
     * 如果模块已安装，则必须返回 true，否则返回 false
     */
    function isModuleInstalled(
        uint256 moduleTypeId,
        address module,
        bytes calldata additionalContext
    ) external view returns (bool);
}
