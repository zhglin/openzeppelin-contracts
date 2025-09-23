// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (account/utils/draft-ERC7579Utils.sol)

pragma solidity ^0.8.20;

import {Execution} from "../../interfaces/draft-IERC7579.sol";
import {Packing} from "../../utils/Packing.sol";
import {Address} from "../../utils/Address.sol";

type Mode is bytes32;
type CallType is bytes1;    // 调用类型
type ExecType is bytes1;    // 执行类型
type ModeSelector is bytes4;// 模式选择器
type ModePayload is bytes22;// 模式负载

/**
 * @dev 包含通用 ERC-7579 实用函数的库。
 *
 * 参见 https://eips.ethereum.org/EIPS/eip-7579[ERC-7579]。
 */
// slither-disable-next-line unused-state
library ERC7579Utils {
    using Packing for *;

    /// @dev 单个 `call` 执行。
    CallType internal constant CALLTYPE_SINGLE = CallType.wrap(0x00);

    /// @dev 一批 `call` 执行。
    CallType internal constant CALLTYPE_BATCH = CallType.wrap(0x01);

    /// @dev 一个 `delegatecall` 执行。
    CallType internal constant CALLTYPE_DELEGATECALL = CallType.wrap(0xFF);

    /// @dev 失败时回滚的默认执行类型。
    // 在 DEFAULT模式下，任何一个子调用失败，都会导致整个批量执行立即停止并回滚。这确保了批量操作的原子性（要么全部成功，要么全部失败）。
    ExecType internal constant EXECTYPE_DEFAULT = ExecType.wrap(0x00);

    /// @dev 失败时不回滚的执行类型。
    // 在 TRY 模式下，某个子调用的失败不会影响后续的调用，整个批量操作会继续执行下去。失败的调用只是被记录为一个事件。
    // 这对于“我希望执行一批操作，但不确定其中某些是否会成功，但我不想因为个别失败而导致全部失败”的场景非常有用。
    ExecType internal constant EXECTYPE_TRY = ExecType.wrap(0x01);

    /**
     * @dev 当一个 {EXECTYPE_TRY} 执行失败时触发。
     * @param batchExecutionIndex 失败调用在执行批次中的索引。
     * @param returndata 失败调用的返回数据。
     */
    event ERC7579TryExecuteFail(uint256 batchExecutionIndex, bytes returndata);

    /// @dev 提供的 {CallType} 不被支持。
    error ERC7579UnsupportedCallType(CallType callType);

    /// @dev 提供的 {ExecType} 不被支持。
    error ERC7579UnsupportedExecType(ExecType execType);

    /// @dev 提供的模块与提供的模块类型不匹配。
    error ERC7579MismatchedModuleTypeId(uint256 moduleTypeId, address module);

    /// @dev 模块未安装。
    error ERC7579UninstalledModule(uint256 moduleTypeId, address module);

    /// @dev 模块已安装。
    error ERC7579AlreadyInstalledModule(uint256 moduleTypeId, address module);

    /// @dev 模块类型不被支持。
    error ERC7579UnsupportedModuleType(uint256 moduleTypeId);

    /// @dev 输入的 calldata 格式不正确，可能存在恶意。
    error ERC7579DecodingError();

    /// @dev 执行单个调用。
    function execSingle(
        bytes calldata executionCalldata,
        ExecType execType
    ) internal returns (bytes[] memory returnData) {
        // 解码执行参数
        (address target, uint256 value, bytes calldata callData) = decodeSingle(executionCalldata);
        // 第一个调用的执行结果
        returnData = new bytes[](1);
        returnData[0] = _call(0, execType, target, value, callData);
    }

    /// @dev 执行一批调用。
    function execBatch(
        bytes calldata executionCalldata,
        ExecType execType
    ) internal returns (bytes[] memory returnData) {
        Execution[] calldata executionBatch = decodeBatch(executionCalldata);
        // 批量调用的执行结果
        returnData = new bytes[](executionBatch.length);
        for (uint256 i = 0; i < executionBatch.length; ++i) {
            returnData[i] = _call(
                i,
                execType,
                executionBatch[i].target,
                executionBatch[i].value,
                executionBatch[i].callData
            );
        }
    }

    /// @dev 执行一个委托调用。
    // DELEGATECALL的设计初衷是代码复用和状态保持，而不是价值转移，所以 EVM 层面就限制了它发送 ETH 的能力。
    function execDelegateCall(
        bytes calldata executionCalldata,
        ExecType execType
    ) internal returns (bytes[] memory returnData) {
        (address target, bytes calldata callData) = decodeDelegate(executionCalldata);
        returnData = new bytes[](1);
        returnData[0] = _delegatecall(0, execType, target, callData);
    }

    /// @dev 使用提供的参数编码模式。参见 {decodeMode}。
    /*
        callType (bytes1): 定义了基础的调用方式。
            0x00 (CALLTYPE_SINGLE): 单个 call 调用。
            0x01 (CALLTYPE_BATCH): 批量 call 调用。
            0xFF (CALLTYPE_DELEGATECALL): delegatecall 调用。
        execType (bytes1): 定义了执行失败时的处理策略。
            0x00 (EXECTYPE_DEFAULT): 默认模式，任何一个子调用失败，整个交易回滚。
            0x01 (EXECTYPE_TRY): 尝试模式，某个子调用失败不会影响后续调用，只会触发一个事件。
        selector (bytes4): 通常是一个函数选择器。它允许模块或钩子（hook）识别并执行特定的逻辑。
        payload (bytes22): 伴随 selector 的额外数据。可以用来传递参数、地址或其他自定义信息。
    */
    function encodeMode(
        CallType callType,      // bytes1   调用类型
        ExecType execType,      // bytes1   执行类型
        ModeSelector selector,  // bytes4   模式选择器
        ModePayload payload     // bytes22  模式负载
    ) internal pure returns (Mode mode) {
        return
            Mode.wrap( // 将打包好的 bytes32 包装成 Mode 类型
                CallType
                    .unwrap(callType)
                    .pack_1_1(ExecType.unwrap(execType))
                    .pack_2_4(bytes4(0))
                    .pack_6_4(ModeSelector.unwrap(selector))
                    .pack_10_22(ModePayload.unwrap(payload))
            );
    }

    /// @dev 将模式解码为其参数。参见 {encodeMode}。
    function decodeMode(
        Mode mode
    ) internal pure returns (CallType callType, ExecType execType, ModeSelector selector, ModePayload payload) {
        return (
            CallType.wrap(Packing.extract_32_1(Mode.unwrap(mode), 0)),
            ExecType.wrap(Packing.extract_32_1(Mode.unwrap(mode), 1)),
            ModeSelector.wrap(Packing.extract_32_4(Mode.unwrap(mode), 6)),
            ModePayload.wrap(Packing.extract_32_22(Mode.unwrap(mode), 10))
        );
    }

    /// @dev 编码单个调用执行。参见 {decodeSingle}。
    // 在编码阶段，调用 encodeSingle 时，将 target 使用 `address(0)` 作为 `address(this)` 的“别名”或“快捷方式”来进行编码。
    // 这样生成的 executionCalldata 会更短、更便宜。执行时库函数会自动完成转换。
    function encodeSingle(
        address target,
        uint256 value,
        bytes calldata callData
    ) internal pure returns (bytes memory executionCalldata) {
        return abi.encodePacked(target, value, callData);
    }

    /// @dev 解码单个调用执行。参见 {encodeSingle}。
    /*
        abi.encodePacked 会将所有参数直接、紧密地拼接在一起，中间不留任何空隙。
        因此，我们可以通过已知的字节偏移量来提取每个参数：
            - `target` 是第一个参数，占 20 字节，从偏移量 0 开始。
            - `value` 是第二个参数，占 32 字节，从偏移量 20 开始。
            - `callData` 是第三个参数，占用剩余的所有字节，从偏移量 52 开始，一直到数据末尾。
        decodeSingle 函数正是利用了这个固定的内存布局，通过字节切片 (slicing) 的方式，我们可以准确地解码出每个参数的值。
    */
    function decodeSingle(
        bytes calldata executionCalldata
    ) internal pure returns (address target, uint256 value, bytes calldata callData) {
        target = address(bytes20(executionCalldata[0:20])); // 转换成address类型
        value = uint256(bytes32(executionCalldata[20:52])); // 转换成uint256类型
        callData = executionCalldata[52:]; // 剩下的字节
    }

    /// @dev 编码委托调用执行。参见 {decodeDelegate}。
    function encodeDelegate(
        address target,
        bytes calldata callData
    ) internal pure returns (bytes memory executionCalldata) {
        return abi.encodePacked(target, callData);
    }

    /// @dev 解码委托调用执行。参见 {encodeDelegate}。
    function decodeDelegate(
        bytes calldata executionCalldata
    ) internal pure returns (address target, bytes calldata callData) {
        target = address(bytes20(executionCalldata[0:20]));
        callData = executionCalldata[20:];
    }

    /// @dev 编码一批执行。参见 {decodeBatch}。
    function encodeBatch(Execution[] memory executionBatch) internal pure returns (bytes memory executionCalldata) {
        return abi.encode(executionBatch);
    }

    /// @dev 解码一批执行。参见 {encodeBatch}。
    ///
    /// 注意：此函数会进行一些检查，如果输入格式不正确，将抛出 {ERC7579DecodingError}。
    /*
        它处理的是由 abi.encode创建的数据，这种数据结构更复杂，但能更好地处理动态数组。
        可以直接用 abi.decode(executionCalldata, (Execution[])), 但为了安全起见，我们手动解析以添加额外的验证。 
            1. Gas 效率: abi.decode 会将数据从 calldata (一个只读的、廉价的数据位置) 完整地复制到 memory (一个读/写、更昂贵的数据位置) 中，
                这会消耗大量Gas。
            2. 安全性: 直接操作 calldata 指针是危险的。如果输入的 executionCalldata是恶意的或格式错误的，可能会导致程序读取到无效的内存区域。
                因此，decodeBatch函数的大部分代码都在做一件事：在执行汇编魔法之前，对输入的字节串进行严格的、层层的边界和格式检查，确保它是安全的。    
        
        如果您用 abi.encode() 编码一个 3 字节的字符串，比如 'abc'，那么 .length 获取到的值将是 96。
        为什么是 96？
        编码一个动态类型（即使是单独编码它）至少包含三个部分：
            1. 偏移量 (Offset) - 占据 32 字节:
                * 这是一个“指针”，它告诉解码器应该去哪里找这个数据的“正文内容”。因为这里只编码了 'abc'这一个数据，
                所以它的正文内容紧跟在偏移量后面，所以这个偏移量的值是 32 (0x20)。
            2. 数据长度 (Length) - 占据 32 字节:
                * 在偏移量指向的位置，首先会有一个 32 字节的槽，用来存放动态数据的实际长度。
                * 字符串 'abc' 包含 3 个字符，即 3 个字节。所以这个槽位的值是 3。
            3. 数据内容 (Content) - 占据 32 字节 (或更多):
                * 在长度后面，才是数据的实际内容。
                * 内容 'abc' (其十六进制表示为 0x616263) 会被放进一个 32 字节的槽里。
                * 因为内容本身只有 3 字节，所以它会在右侧被 29 个零字节 (0x00) 补齐，以填满整个 32 字节的槽位。
        所以，整个 executionCalldata 的 .length 就是这三个部分长度的总和：
        32 字节 (偏移量) + 32 字节 (长度) + 32 字节 (内容) = 96 字节
        
        如果用 abi.encodePacked 会怎么样？
        值得一提的是，如果您使用的是 abi.encodePacked('abc')，情况就完全不同了。
        abi.encodePacked 会进行“紧密打包”，它不会添加任何偏移量或长度信息，只是简单地将内容的原始字节拼接在一起。
        所以，abi.encodePacked('abc') 的结果就是一个只包含 0x616263 的 bytes 数组，其 .length 将是 3。
        
        [槽 0]: 0x0000...0020  // 指针，指向数组元数据的开始位置（即下一个槽，第32字节处）
        [槽 1]: 0x0000...0002  // 数组长度，表示我们有 2 个元素
        [槽 2]: 0x0000...0040  // 指针，指向第 0 个元素的数据区（即槽 4）
        [槽 3]: 0x0000...00A0  // 指针，指向第 1 个元素的数据区（即槽 7）
        [槽 4]: 0x00...000A     // executionBatch[0].target (地址被填充到32字节)
        [槽 5]: 0x00...0001     // executionBatch[0].value
        [槽 6]: 0x00...0060     // 指针，指向 executionBatch[0].callData 的数据区（即槽 11）
        [槽 7]: 0x00...000B     // executionBatch[1].target
        [槽 8]: 0x00...0002     // executionBatch[1].value
        [槽 9]: 0x00...00C0     // 指针，指向 executionBatch[1].callData 的数据区（即槽 13）
        [槽 10]: 0x00...0002     // executionBatch[0].callData 的长度 (2 字节)
        [槽 11]: 0x112200...00  // executionBatch[0].callData 的内容 ("0x1122")，右侧补零
        [槽 12]: 0x00...0003     // executionBatch[1].callData 的长度 (3 字节)
        [槽 13]: 0x33445500...00  // executionBatch[1].callData 的内容 ("0x334455")，右侧补零
    */
    function decodeBatch(bytes calldata executionCalldata) internal pure returns (Execution[] calldata executionBatch) {
        unchecked {
            uint256 bufferLength = executionCalldata.length;

            // 检查 executionCalldata 不为空。
            // 标准 ABI 编码的动态数组，至少需要 32 字节来存储一个指向数据区的偏移量。
            if (bufferLength < 32) revert ERC7579DecodingError();

            // 获取数组的偏移量（指向数组长度的指针）。
            // 第一个 32 字节槽位(槽0)告诉我们，数组的“正文”（长度和元素）从哪里开始。
            uint256 arrayLengthOffset = uint256(bytes32(executionCalldata[0:32]));

            // 数组长度（在 arrayLengthOffset 处）应为 32 字节长。我们检查这是否在缓冲区边界内。
            // 因为我们知道 bufferLength 至少是 32，所以我们可以无溢出风险地进行减法。
            // 检查：偏移量是否有效,组长度本身也需要 32 字节来存储，所以偏移量不能指向缓冲区的末尾。
            // 在标准的 ABI 编码中，槽 0 里面存储的值是 32 (即 0x20)。arrayLengthOffset的值就是32(槽1的起始位置)。
            // 这意味着数组的长度信息存储在偏移量 32 处（槽 1）。
            // executionCalldata地址的0x00 //
            // 一个攻击者可以不遵循 ABI 规范，他可以随心所欲地构造 executionCalldata 的内容。
            // 他完全可以构造一个 executionCalldata，其前 32 字节（槽 0）的内容是 0x00...FFFF (一个非常大的数)。
            // 在这种情况下，当代码执行到 uint256 arrayLengthOffset = ... 时，arrayLengthOffset
            // 这个变量被赋予的值就是那个巨大的、由攻击者设定的任意值。
            if (arrayLengthOffset > bufferLength - 32) revert ERC7579DecodingError();

            // 获取数组长度。arrayLengthOffset + 32 受 bufferLength 限制，因此不会溢出。
            uint256 arrayLength = uint256(bytes32(executionCalldata[arrayLengthOffset:arrayLengthOffset + 32]));

            // 检查缓冲区是否足够长以将数组元素存储为“偏移指针”：
            // - 数组的每个元素都是指向数据的“偏移指针”。
            // - 每个“偏移指针”（指向一个数组元素）占用 32 字节。
            // - 在访问数组元素时会检查该位置的 calldata 的有效性，所以我们只需要检查缓冲区是否足够大以容纳这些指针。
            //
            // 因为我们知道 bufferLength 至少是 arrayLengthOffset + 32，所以我们可以无溢出风险地进行减法。
            // Solidity 将此类数组的长度限制为 2**64-1，这保证了 `arrayLength * 32` 不会溢出。
            // 这行代码检查 `arrayLength` 是否过大，以及 `calldata` 中是否有 `arrayLength * 32` 字节的空间来存放这些指针。
            if (arrayLength > type(uint64).max || bufferLength - arrayLengthOffset - 32 < arrayLength * 32)
                revert ERC7579DecodingError();

            assembly ("memory-safe") {
                // executionBatch.offset 指向 calldata 中数组元素指针列表的起始处。在整个交易的输入数据 (calldata) 中，是从第几个字节开始的？
                // add(executionCalldata.offset, arrayLengthOffset) 数组元数据区的起始地址 (也就是我们图中槽 1的位置)。
                // 为什么要再加 32？因为数组元数据区的第一个槽位（槽 1）存放的是数组的长度 (`arrayLength`)，而不是第一个元素。
                executionBatch.offset := add(add(executionCalldata.offset, arrayLengthOffset), 0x20)
                // executionBatch.length: 在底层，一个动态 calldata 数组变量（如 executionBatch）不仅仅是一个地址，
                // 它还包含一个 length属性。这行代码就是直接设置这个内部的 length 属性。
                executionBatch.length := arrayLength
            }
        }
    }

    /// @dev 使用提供的 {ExecType} 对目标执行 `call`。
    function _call(
        uint256 index,
        ExecType execType,
        address target,
        uint256 value,
        bytes calldata data
    ) private returns (bytes memory) {
        // 如果在执行时，发现 target 地址是 0x000...000 (即 address(0))，那么就自动将其替换为合约自身的地址 (`address(this)`)。
        (bool success, bytes memory returndata) = (target == address(0) ? address(this) : target).call{value: value}(
            data
        );
        return _validateExecutionMode(index, execType, success, returndata);
    }

    /// @dev 使用提供的 {ExecType} 对目标执行 `delegatecall`。
    function _delegatecall(
        uint256 index,
        ExecType execType,
        address target,
        bytes calldata data
    ) private returns (bytes memory) {
        (bool success, bytes memory returndata) = (target == address(0) ? address(this) : target).delegatecall(data);
        return _validateExecutionMode(index, execType, success, returndata);
    }

    /// @dev 验证执行模式并返回 returndata。
    // 根据用户最初在 mode 参数中指定的执行类型 (`ExecType`)，来决定如何应对这次外部调用的结果。
    // uint256 index: 这次调用在整个批量调用中的索引（位置）。如果是单个调用，它就是 0。这个参数主要用于在 TRY 模式下报告错误。
    // ExecType execType: 这是最关键的参数，它告诉函数应该遵循哪种“处理规则”。它只有两种主要可能的值：EXECTYPE_DEFAULT 或 EXECTYPE_TRY。
    // bool success: 这是低级别 call 或 delegatecall 直接返回的成功标志。true 表示成功，false 表示失败（例如，对方合约 revert 了）。
    // bytes memory returndata: 低级别调用返回的数据。如果 success 是 true，这是函数的返回值；
    //      如果 success 是 false，这通常是对方合约的错误信息。
    function _validateExecutionMode(
        uint256 index,
        ExecType execType,
        bool success,
        bytes memory returndata
    ) private returns (bytes memory) {
        if (execType == ERC7579Utils.EXECTYPE_DEFAULT) {
            Address.verifyCallResult(success, returndata);
        } else if (execType == ERC7579Utils.EXECTYPE_TRY) {
            if (!success) emit ERC7579TryExecuteFail(index, returndata);
        } else {
            revert ERC7579UnsupportedExecType(execType);
        }
        return returndata;
    }
}

// Operators
using {eqCallType as ==} for CallType global;
using {eqExecType as ==} for ExecType global;
using {eqModeSelector as ==} for ModeSelector global;
using {eqModePayload as ==} for ModePayload global;

/// @dev 比较两个 `CallType` 值是否相等。
function eqCallType(CallType a, CallType b) pure returns (bool) {
    return CallType.unwrap(a) == CallType.unwrap(b);
}

/// @dev 比较两个 `ExecType` 值是否相等。
function eqExecType(ExecType a, ExecType b) pure returns (bool) {
    return ExecType.unwrap(a) == ExecType.unwrap(b);
}

/// @dev 比较两个 `ModeSelector` 值是否相等。
function eqModeSelector(ModeSelector a, ModeSelector b) pure returns (bool) {
    return ModeSelector.unwrap(a) == ModeSelector.unwrap(b);
}

/// @dev 比较两个 `ModePayload` 值是否相等。
function eqModePayload(ModePayload a, ModePayload b) pure returns (bool) {
    return ModePayload.unwrap(a) == ModePayload.unwrap(b);
}
