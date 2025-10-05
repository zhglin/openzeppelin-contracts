// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Panic.sol)

pragma solidity ^0.8.20;

/**
 * @dev 用于发出标准化 panic（恐慌）代码的辅助库。
 *
 * ```solidity
 * contract Example {
 *      using Panic for uint256;
 *
 *      // 使用任何已声明的内部常量
 *      function foo() { Panic.GENERIC.panic(); }
 *
 *      // 或者
 *      function foo() { Panic.panic(Panic.GENERIC); }
 * }
 * ```
 *
 * 遵循 https://github.com/ethereum/solidity/blob/v0.8.24/libsolutil/ErrorCodes.h[libsolutil] 的列表。
 *
 * _自 v5.1 起可用。_
 */
/*
    Panic.sol 是一个底层的、供高级开发者使用的工具库，它的作用是让智能合约可以手动地、标准化地触发一个 Solidity 的“Panic（恐慌）”类型错误。
    要理解它的用途，我们首先要明白什么是 “Panic” 错误。
        Solidity 中的两种错误类型,从 Solidity 0.8.0 版本开始，错误主要分为两种：
        1. Error：这是我们最常见的错误，通常由 require 或 revert 语句触发。
            * require(condition, "Error message"): 条件不满足时，返回一个字符串错误信息。
            * error MyCustomError(); revert MyCustomError();: 使用自定义错误，这更节省 Gas 且更结构化。
            * 用途：用于处理业务逻辑中的预期错误，比如“用户余额不足”、“调用者不是所有者”等。
        2. Panic：这是一种特殊的、更严重的错误。它通常不是由业务逻辑问题引起的，而是由底层的、编程级别的错误造成的。
            当发生 Panic 时，交易会 revert并返回一个特定的错误码（一个数字）。
            * 例子：
                * 算术溢出或下溢（错误码 0x11）。
                * 除以零（错误码 0x12）。
                * 访问数组时索引越界（错误码 0x32）。
                * 调用 assert(false)（错误码 0x01）。

    Panic.sol 这个库就是把上述的这些 Panic 错误码都定义成了常量，并提供了一个 panic(uint256 code) 函数，
    让开发者可以手动地触发一个和 Solidity 内置 Panic 完全一样的错误。
    
    为什么要手动触发 Panic？
        这通常是为那些编写底层基础库（尤其是使用汇编语言）的开发者准备的。
        假设您正在编写一个非常高效的数据结构库（比如 OpenZeppelin 的 DoubleEndedQueue.sol）。
        在这个库的内部，您可能在手动操作内存或数组。当您在自己的代码逻辑中检测到一个“数组即将越界”的错误时，您有两个选择：
            1. revert MyCustomArrayOutOfBoundsError(): 抛出一个自定义错误。
            2. Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS): 使用 Panic.sol 抛出一个和 Solidity EVM 在遇到同样问题时会抛出的完全相同的标准化错误（0x32）。
        选择第二种的好处是一致性。
        这使得您的库表现得就像是 Solidity 语言的原生部分。
        那些为分析标准 Panic 错误而构建的工具（如 Hardhat、Foundry 的调试器）就能正确地识别和报告这个错误，而不是将其视为一个未知的自定义错误。

    Panic.sol 是一个高级工具，它让底层库的开发者能够模拟 EVM的原生错误行为，从而与整个以太坊开发工具生态系统更好地集成。
    对于大多数应用层开发者来说，几乎永远不会直接用到它，但在构建像 OpenZeppelin 这样可重用的基础合约库时，它非常有用。
*/
// slither-disable-next-line unused-state
library Panic {
    /// @dev 通用/未指定错误
    uint256 internal constant GENERIC = 0x00;
    /// @dev 由 assert() 内置函数使用
    uint256 internal constant ASSERT = 0x01;
    /// @dev 算术下溢或溢出
    uint256 internal constant UNDER_OVERFLOW = 0x11;
    /// @dev 除以零或对零取模
    uint256 internal constant DIVISION_BY_ZERO = 0x12;
    /// @dev 枚举转换错误
    uint256 internal constant ENUM_CONVERSION_ERROR = 0x21;
    /// @dev 存储中无效的编码
    uint256 internal constant STORAGE_ENCODING_ERROR = 0x22;
    /// @dev 对空数组执行 pop 操作
    uint256 internal constant EMPTY_ARRAY_POP = 0x31;
    /// @dev 数组越界访问
    uint256 internal constant ARRAY_OUT_OF_BOUNDS = 0x32;
    /// @dev 资源错误（分配过大或数组过大）
    uint256 internal constant RESOURCE_ERROR = 0x41;
    /// @dev 调用无效的内部函数
    uint256 internal constant INVALID_INTERNAL_FUNCTION = 0x51;

    /// @dev 使用 panic 代码进行 revert。建议与预定义的内部常量一起使用。
    function panic(uint256 code) internal pure {
        // 手动构建一个标准的 `Panic(uint256)` 错误，并用它来 `revert` 交易。
        // 这等同于在 Solidity 中执行 revert Panic(code);，但它是通过直接操作内存和 EVM 指令来实现的，更为底层和高效。
        assembly ("memory-safe") {
            // 将 Panic(uint256) 的函数选择器存入内存
            // 0x000000000000000000000000000000000000000000000000000000004e487b71
            // 这意味着，这 4 个字节 4e487b71 实际上位于内存地址的 0x1c 到 0x1f（十进制的 28 到 31）的位置。
            mstore(0x00, 0x4e487b71)
            // 将错误码 code 存入内存
            //  * 0x00 - 0x1f: ...004e487b71
            //  * 0x20 - 0x3f: ...<32字节的code值>
            mstore(0x20, code)
            // revert 交易，并返回构建好的错误数据
            // 0x4e487b71 的 4 个字节正好存储在内存的 0x1c 到 0x1f 位置。所以 0x1c 是我们想要的错误数据的起始点。
            // 错误数据总长度是 4（函数选择器） + 32（uint256 code） = 36 字节，即 0x24。
            revert(0x1c, 0x24)
        }
    }
}
