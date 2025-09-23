// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/Calldata.sol)

pragma solidity ^0.8.20;

/**
 * @dev 用于操作 calldata 中对象的辅助库。
 */
/*
    在 Solidity 中，calldata 是一种特殊的数据位置，用于存储外部函数调用的参数。它的特点是：
        * 只读：你不能修改 calldata 中的数据。
        * 临时性：数据只在函数调用期间存在。
        * 高效：相比 memory，使用 calldata 通常更节省 Gas，因为它不需要将数据从交易输入复制到内存中。
    
     1. `emptyBytes()`
        * 作用：返回一个空的 bytes calldata 对象。
        * 实现方式：它使用了内联汇编（assembly）来直接设置 bytes calldata 对象的 offset（偏移量）和 length（长度）为 0。
        * 为什么有用：在某些情况下，你可能需要向一个期望 bytes calldata 类型参数的函数传递一个空值。
            通常，你可能会创建一个空的 bytes memory对象，然后将其传递。但 emptyBytes() 提供了更 Gas 优化的方式，
            它直接构造了一个指向 caldata中“空”位置的引用，避免了不必要的内存分配和数据复制。

    2. `emptyString()`
        * 作用：返回一个空的 string calldata 对象。
        * 实现方式：与 emptyBytes() 类似，也是通过内联汇编直接设置 string calldata 对象的 offset 和 length 为 0。
        * 为什么有用：原因同 emptyBytes()，只是针对 string calldata 类型。
*/
library Calldata {
    // slither-disable-next-line write-after-write
    function emptyBytes() internal pure returns (bytes calldata result) {
        assembly ("memory-safe") {
            result.offset := 0
            result.length := 0
        }
    }

    // slither-disable-next-line write-after-write
    function emptyString() internal pure returns (string calldata result) {
        assembly ("memory-safe") {
            result.offset := 0
            result.length := 0
        }
    }
}
