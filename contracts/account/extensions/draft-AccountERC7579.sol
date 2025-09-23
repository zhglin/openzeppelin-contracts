// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (account/extensions/draft-AccountERC7579.sol)

pragma solidity ^0.8.26;

import {PackedUserOperation} from "../../interfaces/draft-IERC4337.sol";
import {IERC1271} from "../../interfaces/IERC1271.sol";
import {
    IERC7579Module,
    IERC7579Validator,
    IERC7579Execution,
    IERC7579AccountConfig,
    IERC7579ModuleConfig,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "../../interfaces/draft-IERC7579.sol";
import {ERC7579Utils, Mode, CallType, ExecType} from "../../account/utils/draft-ERC7579Utils.sol";
import {EnumerableSet} from "../../utils/structs/EnumerableSet.sol";
import {Bytes} from "../../utils/Bytes.sol";
import {Packing} from "../../utils/Packing.sol";
import {Calldata} from "../../utils/Calldata.sol";
import {Account} from "../Account.sol";

/**
 * @dev {Account} 的扩展，实现了对 ERC-7579 模块的支持。
 *
 * 为了符合 ERC-1271 的支持要求，此合约通过调用 {IERC7579Validator-isValidSignatureWithSender}
 * 将签名验证推迟到已安装的验证器模块。
 *
 * 此合约不实现用户操作的验证逻辑，因为此功能通常委托给独立的验证模块。
 * 开发者必须在初始化时安装一个验证器模块（或任何其他机制来启用账户执行）：
 *
 * ```solidity
 * contract MyAccountERC7579 is AccountERC7579, Initializable {
 *   function initializeAccount(address validator, bytes calldata validatorData) public initializer {
 *     _installModule(MODULE_TYPE_VALIDATOR, validator, validatorData);
 *   }
 * }
 * ```
 *
 * [注意]
 * ====
 * * 不包括钩子（Hook）支持。请参阅 {AccountERC7579Hooked} 以获取一个挂钩到执行的版本。
 * * 在验证 ERC-1271 签名或 ERC-4337 用户操作时，验证器的选择在内部虚函数
 *   {_extractUserOpValidator} 和 {_extractSignatureValidator} 中实现。两者的实现都遵循了通用实践。
 *   然而，这部分在 ERC-7579（或任何后续的 ERC）中没有标准化。某些账户可能希望覆盖这些内部函数。
 * * 当与 {ERC7739} 结合使用时，{isValidSignature} 的解析顺序可能会产生影响（{ERC7739} 不会调用 super）。
 *   可能需要手动解析。
 * * 当前不支持静态调用（使用 callType `0xfe`）。
 * ====
 *
 * 警告：移除所有验证器模块将导致账户无法操作，因为之后将无法验证任何用户操作。
 */
abstract contract AccountERC7579 is Account, IERC1271, IERC7579Execution, IERC7579AccountConfig, IERC7579ModuleConfig {
    using Bytes for *;
    using ERC7579Utils for *;
    using EnumerableSet for *;
    using Packing for bytes32;

    EnumerableSet.AddressSet private _validators;   // 已安装的验证器模块

    // executeFromExecutor 方法中使用
    EnumerableSet.AddressSet private _executors;    // 已安装的执行器模块

    mapping(bytes4 selector => address) private _fallbacks; // 选择器到已安装回退处理器的映射

    /// @dev 账户的 {fallback} 被调用时，传入的选择器没有已安装的处理器。
    error ERC7579MissingFallbackHandler(bytes4 selector);

    /// @dev 修饰符，检查调用者是否是给定类型的已安装模块。
    modifier onlyModule(uint256 moduleTypeId, bytes calldata additionalContext) {
        _checkModule(moduleTypeId, msg.sender, additionalContext);
        _;
    }

    /// @dev 参见 {_fallback}。
    fallback(bytes calldata) external payable virtual returns (bytes memory) {
        return _fallback();
    }

    /// @inheritdoc IERC7579AccountConfig
    /*
        返回一个唯一的字符串标识符，用于识别智能账户的具体实现（implementation）及其版本。
            * 智能合约的“型号”和“固件版本”：它告诉外部世界，这个智能账户是由哪个供应商开发的，它的名称是什么，以及它当前运行的是哪个版本。
            * 而非账户的“地址”：账户地址标识的是链上的一个具体实例，而 accountId 标识的是这个实例所使用的代码类型。
        ERC-7579 规范要求
            根据 IERC7579AccountConfig 接口的注释，accountId() 函数有以下要求和建议：
                * 必须返回非空字符串：确保始终提供一个有效的标识符。
                * 建议的结构："vendorname.accountname.semver"
                    * vendorname：开发或提供此账户实现的实体名称（例如 openzeppelin）。
                    * accountname：账户实现的具体名称（例如 AccountERC7579）。
                    * semver：账户实现的代码版本，遵循语义化版本控制（例如 v0.0.0）。
                * 应在所有智能账户中是唯一的：这个 ID 应该能够唯一地标识一个特定的账户代码库和版本。
        实际应用场景
            accountId() 函数对于以下场景非常有用：
                * 钱包和 DApp 识别：钱包或 DApp 可以通过查询 accountId来识别用户连接的智能账户类型。
                    这有助于它们提供针对特定账户类型的定制化用户界面、功能或警告。
                    例如，一个钱包可能知道某个 accountId对应的账户支持特定的功能，从而在 UI 中启用相关选项。
                * 互操作性：它为不同的工具和平台提供了一个标准化的方式来理解智能账户的特性。
                * 审计和安全：安全审计人员或用户可以通过 accountId 快速识别账户所使用的代码版本，从而了解其已知特性、潜在漏洞或安全更新。
                * 调试和支持：在出现问题时，accountId 可以帮助开发者和支持团队快速定位问题可能出在哪个账户实现上。
        总之，accountId() 函数是 ERC-7579 智能账户的“身份证号”，它提供了一种标准化的方式来识别和理解账户的底层代码实现。
    */
    function accountId() public view virtual returns (string memory) {
        // 供应商名称.账户名称.语义化版本
        return "@openzeppelin/community-contracts.AccountERC7579.v0.0.0";
    }

    /**
     * @inheritdoc IERC7579AccountConfig
     *
     * @dev 支持的调用类型:
     * * 单一 (`0x00`): 单个交易执行。
     * * 批量 (`0x01`): 一批交易的执行。
     * * 委托 (`0xff`): 委托调用执行。
     *
     * 支持的执行类型:
     * * 默认 (`0x00`): 默认执行类型（失败时回滚）。
     * * 尝试 (`0x01`): 尝试执行类型（失败时触发 ERC7579TryExecuteFail 事件）。
     */
    function supportsExecutionMode(bytes32 encodedMode) public view virtual returns (bool) {
        (CallType callType, ExecType execType, , ) = Mode.wrap(encodedMode).decodeMode();
        return
            (callType == ERC7579Utils.CALLTYPE_SINGLE ||
                callType == ERC7579Utils.CALLTYPE_BATCH ||
                callType == ERC7579Utils.CALLTYPE_DELEGATECALL) &&
            (execType == ERC7579Utils.EXECTYPE_DEFAULT || execType == ERC7579Utils.EXECTYPE_TRY);
    }

    /**
     * @inheritdoc IERC7579AccountConfig
     *
     * @dev 支持的模块类型:
     *
     * * 验证器 (Validator): 在验证阶段用于确定交易是否有效并应在账户上执行的模块。
     * * 执行器 (Executor): 可以通过回调代表智能账户执行交易的模块。
     * * 回退处理器 (Fallback Handler): 可以扩展智能账户回退功能的模块。
     */
    function supportsModule(uint256 moduleTypeId) public view virtual returns (bool) {
        return
            moduleTypeId == MODULE_TYPE_VALIDATOR ||
            moduleTypeId == MODULE_TYPE_EXECUTOR ||
            moduleTypeId == MODULE_TYPE_FALLBACK;
    }

    /// @inheritdoc IERC7579ModuleConfig
    function installModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata initData
    ) public virtual onlyEntryPointOrSelf {
        _installModule(moduleTypeId, module, initData);
    }

    /// @inheritdoc IERC7579ModuleConfig
    function uninstallModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata deInitData
    ) public virtual onlyEntryPointOrSelf {
        _uninstallModule(moduleTypeId, module, deInitData);
    }

    /// @inheritdoc IERC7579ModuleConfig
    // 检查模块是否已安装
    function isModuleInstalled(
        uint256 moduleTypeId,
        address module,
        bytes calldata additionalContext
    ) public view virtual returns (bool) {
        if (moduleTypeId == MODULE_TYPE_VALIDATOR) return _validators.contains(module);
        if (moduleTypeId == MODULE_TYPE_EXECUTOR) return _executors.contains(module);
        if (moduleTypeId == MODULE_TYPE_FALLBACK) return _fallbacks[bytes4(additionalContext[0:4])] == module;
        return false;
    }

    /// @inheritdoc IERC7579Execution
    /*
        * 调用者权限 (`onlyEntryPointOrSelf`):
            * 这个函数只能由 EntryPoint（入口点合约，通常是 ERC-4337 的一部分） 调用，或者由账户本身调用。
            * 这意味着它是账户执行外部用户操作（UserOperation）的主要入口点，或者账户内部逻辑需要执行某些操作时使用。
            * 它确保了只有受信任的实体才能直接触发账户的执行逻辑。
        * 返回值:
            * 这个函数没有明确的返回值（在 Solidity 中，对于外部调用，如果函数没有 returns 关键字，则隐式为 void）。
            * 如果执行成功，它会完成操作；如果失败，它会回滚。
        * 目的:
            * 它是账户处理来自外部（特别是通过 EntryPoint）的执行请求的标准方式。
    */
    function execute(bytes32 mode, bytes calldata executionCalldata) public payable virtual onlyEntryPointOrSelf {
        _execute(Mode.wrap(mode), executionCalldata);
    }

    /// @inheritdoc IERC7579Execution
    /*
        * 调用者权限 (`onlyModule(MODULE_TYPE_EXECUTOR, ...)` ):
            * 这个函数只能由已安装的、类型为 `MODULE_TYPE_EXECUTOR` 的执行器模块调用。
            * 这是一个更严格的访问控制，确保只有专门负责执行的模块才能使用此功能。
        * 返回值:
            * 这个函数明确返回 `bytes[] memory returnData`。这是一个字节数组的数组，通常包含由 executionCalldata 中定义的每个子调用返回的数据。
            * 执行器模块通常需要这些返回数据来进一步处理或聚合结果。
        * 目的:
            * 它旨在供执行器模块使用。一个执行器模块可能接收到一个复杂的执行指令，它会处理这些指令，
                然后将实际的低级执行任务委托给账户的executeFromExecutor 方法。
            * 执行器模块需要从账户的执行中获取详细的返回数据，以便它可以根据这些数据做出决策或将结果传递给用户。
    */
    function executeFromExecutor(
        bytes32 mode,
        bytes calldata executionCalldata
    )
        public
        payable
        virtual
        onlyModule(MODULE_TYPE_EXECUTOR, Calldata.emptyBytes())
        returns (bytes[] memory returnData)
    {
        return _execute(Mode.wrap(mode), executionCalldata);
    }

    /**
     * @dev 通过 IERC7579Validator 模块实现 ERC-1271。如果基于模块的验证失败，则回退到
     * 由抽象签名者进行的“原生”验证。
     *
     * 注意：当与 {ERC7739} 结合使用时，解析顺序可能会产生影响（{ERC7739} 不会调用 super）。
     * 可能需要手动解析。
     */
    /*
        isValidSignature 函数所要验证的签名，是在链下由用户（或代表用户的钱包/DApp）生成的。
            这个签名是一个复合签名，它不是一个简单的加密签名，而是按照 _extractSignatureValidator 函数所期望的特定格式构造的。

        1. 函数的用途    
            * 实现 ERC-1271 标准：允许外部合约或 DApp 验证由这个智能账户“签署”的消息或数据的有效性。
            * 委托验证：它不直接执行签名验证逻辑，而是根据签名数据中包含的信息，找到并调用相应的验证器模块来完成验证。
        2. 函数签名
            1 function isValidSignature(bytes32 hash, bytes calldata signature) public view virtual returns (bytes4 magicValue)
                * `bytes32 hash`：被签署数据的哈希值。这是 ERC-1271 规范中要求验证的原始数据哈希。
                * `bytes calldata signature`：待验证的签名数据。这不仅仅是原始的加密签名，
                    而是按照特定约定（如 _extractSignatureValidator所期望的）构造的复合数据。
                * `returns (bytes4 magicValue)`：
                    * 如果签名有效，函数应返回 ERC-1271 的魔术值 0x1626ba7e。
                    * 如果签名无效，函数应返回 0xffffffff。
        isValidSignature 函数使得 ERC-7579 智能账户能够：
            * 兼容 ERC-1271：与其他支持 ERC-1271 的合约和 DApp 无缝交互。
            * 模块化验证：将复杂的签名验证逻辑从核心账户中分离出来，委托给专门的验证器模块。
                这允许账户拥有高度定制化的验证策略（例如，多重签名、社交恢复、基于时间锁的验证等），并且可以灵活地更换或升级这些策略，
                而无需更改账户的核心逻辑。
            * 灵活的签名格式：通过 _extractSignatureValidator 的约定，签名数据本身可以携带元信息（如哪个模块应该验证它），增加了灵活性。             
    */
    function isValidSignature(bytes32 hash, bytes calldata signature) public view virtual returns (bytes4) {
        // 检查签名长度是否足以提取
        // 期望签名数据的前20个字节是模块地址，如果签名长度不足20字节，则无法提取模块地址，直接判定为无效签名。
        if (signature.length >= 20) {
            // 从签名中分离出模块地址和实际签名数据
            (address module, bytes calldata innerSignature) = _extractSignatureValidator(signature);
            // 如果模块未安装，则跳过
            if (isModuleInstalled(MODULE_TYPE_VALIDATOR, module, Calldata.emptyBytes())) {
                // 尝试验证，跳过任何回滚
                try IERC7579Validator(module).isValidSignatureWithSender(msg.sender, hash, innerSignature) returns (
                    bytes4 magic
                ) {
                    return magic;
                } catch {}
            }
        }
        return bytes4(0xffffffff);
    }

    /**
     * @dev 使用 {_signableUserOpHash} 验证用户操作，如果 nonce 密钥的前 20 字节指定的模块已安装，
     * 则返回验证数据。否则，回退到 {Account-_validateUserOp}。
     *
     * 模块提取逻辑请参见 {_extractUserOpValidator}。
     */
    function _validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256) {
        address module = _extractUserOpValidator(userOp);
        return
            isModuleInstalled(MODULE_TYPE_VALIDATOR, module, Calldata.emptyBytes())
                // 调用 IERC7579Validator 模块验证用户操作
                ? IERC7579Validator(module).validateUserOp(userOp, _signableUserOpHash(userOp, userOpHash))
                : super._validateUserOp(userOp, userOpHash);
    }

    /**
     * @dev ERC-7579 执行逻辑。有关支持的模式，请参见 {supportsExecutionMode}。
     *
     * 如果不支持调用类型，则回滚。
     * 
     * _execute 函数是账户执行操作的“发动机”，它只负责根据指令（mode 和executionCalldata）执行底层的调用。
     * 而各种模块则扮演着“驾驶员”、“导航员”、“安全员”等角色，它们在执行流程的不同环节与这个“发动机”互动，
     * 但_execute 本身并不直接“指挥”这些模块。
     */
    function _execute(
        Mode mode,
        bytes calldata executionCalldata
    ) internal virtual returns (bytes[] memory returnData) {
        (CallType callType, ExecType execType, , ) = mode.decodeMode();
        if (callType == ERC7579Utils.CALLTYPE_SINGLE) return executionCalldata.execSingle(execType);
        if (callType == ERC7579Utils.CALLTYPE_BATCH) return executionCalldata.execBatch(execType);
        if (callType == ERC7579Utils.CALLTYPE_DELEGATECALL) return executionCalldata.execDelegateCall(execType);
        revert ERC7579Utils.ERC7579UnsupportedCallType(callType);
    }

    /**
     * @dev 使用给定的初始化数据安装给定类型的模块。
     *
     * 对于回退模块类型，`initData` 应该是 4 字节选择器和其余数据的（打包）串联，
     * 在调用 {IERC7579Module-onInstall} 时发送给处理器。
     *
     * 要求:
     *
     * * 必须支持模块类型。参见 {supportsModule}。否则以 {ERC7579Utils-ERC7579UnsupportedModuleType} 回滚。
     * * 模块必须是给定类型。否则以 {ERC7579Utils-ERC7579MismatchedModuleTypeId} 回滚。
     * * 模块不能已安装。否则以 {ERC7579Utils-ERC7579AlreadyInstalledModule} 回滚。
     *
     * 触发 {IERC7579ModuleConfig-ModuleInstalled} 事件。
     */
    function _installModule(uint256 moduleTypeId, address module, bytes memory initData) internal virtual {
        require(supportsModule(moduleTypeId), ERC7579Utils.ERC7579UnsupportedModuleType(moduleTypeId));
        require(
            // 调用IERC7579Module.isModuleType检查模块类型
            IERC7579Module(module).isModuleType(moduleTypeId),
            ERC7579Utils.ERC7579MismatchedModuleTypeId(moduleTypeId, module)
        );

        if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
            require(_validators.add(module), ERC7579Utils.ERC7579AlreadyInstalledModule(moduleTypeId, module));
        } else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
            require(_executors.add(module), ERC7579Utils.ERC7579AlreadyInstalledModule(moduleTypeId, module));
        } else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
            bytes4 selector;
            (selector, initData) = _decodeFallbackData(initData);
            require(
                // 未被install过的selector才能install
                _fallbacks[selector] == address(0),
                ERC7579Utils.ERC7579AlreadyInstalledModule(moduleTypeId, module)
            );
            _fallbacks[selector] = module;
        }

        // 调用IERC7579Module.onInstall进行初始化
        IERC7579Module(module).onInstall(initData);
        emit ModuleInstalled(moduleTypeId, module);
    }

    /**
     * @dev 使用给定的反初始化数据卸载给定类型的模块。
     *
     * 对于回退模块类型，`deInitData` 应该是 4 字节选择器和其余数据的（打包）串联，
     * 在调用 {IERC7579Module-onUninstall} 时发送给处理器。
     *
     * 要求:
     *
     * * 模块必须已安装。否则以 {ERC7579Utils-ERC7579UninstalledModule} 回滚。
     */
    function _uninstallModule(uint256 moduleTypeId, address module, bytes memory deInitData) internal virtual {
        // 检查模块类型是否受支持
        require(supportsModule(moduleTypeId), ERC7579Utils.ERC7579UnsupportedModuleType(moduleTypeId));

        if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
            require(_validators.remove(module), ERC7579Utils.ERC7579UninstalledModule(moduleTypeId, module));
        } else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
            require(_executors.remove(module), ERC7579Utils.ERC7579UninstalledModule(moduleTypeId, module));
        } else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
            bytes4 selector;
            (selector, deInitData) = _decodeFallbackData(deInitData);
            require(
                _fallbackHandler(selector) == module && module != address(0),
                ERC7579Utils.ERC7579UninstalledModule(moduleTypeId, module)
            );
            // 删除模块
            delete _fallbacks[selector];
        }

        // 调用IERC7579Module.onUninstall进行反初始化
        IERC7579Module(module).onUninstall(deInitData);
        emit ModuleUninstalled(moduleTypeId, module);
    }

    /**
     * @dev 回退函数，将调用委托给为给定选择器安装的处理器。
     *
     * 如果未安装处理器，则以 {ERC7579MissingFallbackHandler} 回滚。
     *
     * 按照 ERC-2771 格式，在 calldata 的末尾附加原始的 `msg.sender` 来调用处理器。
     */
    function _fallback() internal virtual returns (bytes memory) {
        // 根据 msg.sig 找到对应的回退处理器
        address handler = _fallbackHandler(msg.sig);
        require(handler != address(0), ERC7579MissingFallbackHandler(msg.sig));

        // 根据 https://eips.ethereum.org/EIPS/eip-7579#fallback[ERC-7579 规范]:
        // - 必须利用 ERC-2771 将原始的 msg.sender 添加到发送给回退处理器的 calldata 中
        // - 必须使用 call 来调用回退处理器
        (bool success, bytes memory returndata) = handler.call{value: msg.value}(
            abi.encodePacked(msg.data, msg.sender)
        );

        if (success) return returndata;

        assembly ("memory-safe") {
            revert(add(returndata, 0x20), mload(returndata))
        }
    }

    /// @dev 返回给定选择器的回退处理器。如果未安装，则返回 `address(0)`。
    function _fallbackHandler(bytes4 selector) internal view virtual returns (address) {
        return _fallbacks[selector];
    }

    /// @dev 检查模块是否已安装。如果模块未安装，则回滚。
    function _checkModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata additionalContext
    ) internal view virtual {
        require(
            isModuleInstalled(moduleTypeId, module, additionalContext),
            ERC7579Utils.ERC7579UninstalledModule(moduleTypeId, module)
        );
    }

    /**
     * @dev 从用户操作中提取 nonce 验证器。
     *
     * 要构造一个 nonce 密钥，请按如下方式设置 nonce：
     *
     * ```
     * <模块地址 (20 字节)> | <密钥 (4 字节)> | <nonce (8 字节)>
     * ```
     * 注意：此函数的默认行为复制了以下实现的行为：
     * https://github.com/rhinestonewtf/safe7579/blob/bb29e8b1a66658790c4169e72608e27d220f79be/src/Safe7579.sol#L266[Safe adapter],
     * https://github.com/etherspot/etherspot-prime-contracts/blob/cfcdb48c4172cea0d66038324c0bae3288aa8caa/src/modular-etherspot-wallet/wallet/ModularEtherspotWallet.sol#L227[Etherspot's Prime Account], and
     * https://github.com/erc7579/erc7579-implementation/blob/16138d1afd4e9711f6c1425133538837bd7787b5/src/MSAAdvanced.sol#L247[ERC7579 参考实现]。
     *
     * 这在 ERC-7579（或任何后续 ERC）中没有标准化。某些账户可能希望覆盖这些内部函数。
     *
     * 例如，https://github.com/bcnmy/nexus/blob/54f4e19baaff96081a8843672977caf712ef19f4/contracts/lib/NonceLib.sol#L17[Biconomy's Nexus]
     * 使用了类似但不兼容的方法（验证器地址也是 nonce 的一部分，但位置不同）。
     */
    function _extractUserOpValidator(PackedUserOperation calldata userOp) internal pure virtual returns (address) {
        return address(bytes32(userOp.nonce).extract_32_20(0));
    }

    /**
     * @dev 从签名中提取签名验证器。
     *
     * 要构造一个签名，请将前 20 字节设置为模块地址，其余字节为签名数据：
     *
     * ```
     * <模块地址 (20 字节)> | <签名数据>
     * ```
     *
     * 注意：此函数的默认行为复制了以下实现的行为：
     * https://github.com/rhinestonewtf/safe7579/blob/bb29e8b1a66658790c4169e72608e27d220f79be/src/Safe7579.sol#L350[Safe adapter],
     * https://github.com/bcnmy/nexus/blob/54f4e19baaff96081a8843672977caf712ef19f4/contracts/Nexus.sol#L239[Biconomy's Nexus],
     * https://github.com/etherspot/etherspot-prime-contracts/blob/cfcdb48c4172cea0d66038324c0bae3288aa8caa/src/modular-etherspot-wallet/wallet/ModularEtherspotWallet.sol#L252[Etherspot's Prime Account], and
     * https://github.com/erc7579/erc7579-implementation/blob/16138d1afd4e9711f6c1425133538837bd7787b5/src/MSAAdvanced.sol#L296[ERC7579 参考实现]。
     *
     * 这在 ERC-7579（或任何后续 ERC）中没有标准化。某些账户可能希望覆盖这些内部函数。
     */
    /*
        它的主要作用是从一个复合签名中提取出负责验证该签名的模块地址以及实际的签名数据。
        在 ERC-7579 模块化账户中，一个账户可以有多个验证器模块。
        当账户收到一个签名时，它需要知道应该由哪个验证器模块来处理这个签名。  
        _extractSignatureValidator 就是为了解决这个问题而设计的。
        它假设用户提供的 signature 参数不仅仅是原始的签名数据，而是经过特殊构造的，其中包含了指定验证器模块的信息。
            遵循以下签名构造约定： <模块地址 (20 字节)> | <签名数据>  
        虽然 OpenZeppelin 的 AccountERC7579 采用了这种约定，但其他 ERC-7579 账户实现可能使用不同的方式来指定验证器模块。
            因此，如果你要与不同的 ERC-7579 账户交互，可能需要根据它们的约定来调整这个提取逻辑。        
    */
    function _extractSignatureValidator(
        bytes calldata signature
    ) internal pure virtual returns (address module, bytes calldata innerSignature) {
        return (address(bytes20(signature[0:20])), signature[20:]);
    }

    /**
     * @dev 从 initData/deInitData 中为 MODULE_TYPE_FALLBACK 提取函数选择器
     *
     * 注意：如果我们在这里有 calldata，我们可以使用 calldata 切片，这样操作起来更便宜，不需要
     * 实际复制。然而，这将要求 `_installModule` 获取一个 calldata 字节对象而不是内存
     * 字节对象。这将阻止从合约构造函数中调用 `_installModule`，并强制使用
     * 外部初始化器。未来这可能会改变，因为大多数账户可能会部署为
     * 克隆/代理/ERC-7702 委托，因此无论如何都会依赖初始化器。
     * 
     * bytes4(data): 这行代码会截取 data 的前4个字节，并将其转换为 bytes4 类型。这4个字节就是函数选择器。
     * data.slice(4): 这是 OpenZeppelin 的 Bytes库提供的一个辅助函数，
     *      它会返回从第4个字节开始（不包括第4个字节）到末尾的所有字节。这就是剩余的初始化数据。
     * bytes memory packedData = abi.encodePacked(selector, moduleInitData)
     */
    function _decodeFallbackData(
        bytes memory data
    ) internal pure virtual returns (bytes4 selector, bytes memory remaining) {
        return (bytes4(data), data.slice(4));
    }

    /// @dev 默认情况下，仅使用模块进行 userOp 和签名的验证。禁用原始签名。
    function _rawSignatureValidation(
        bytes32 /*hash*/,
        bytes calldata /*signature*/
    ) internal view virtual override returns (bool) {
        return false;
    }
}
