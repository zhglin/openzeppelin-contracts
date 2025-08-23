// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev 用于将基本类型读写到特定存储槽的库。
 * 存储槽通常用于在处理可升级合约时避免存储冲突。
 * 该库有助于读写这些槽，而无需内联汇编。
 * 此库中的函数返回包含 `value` 成员的 Slot 结构体，可用于读写。
 * 设置 ERC-1967 实现槽的示例用法：
 * ```solidity
 * contract ERC1967 {
 *     // 定义槽。或者，使用 SlotDerivation 库来派生槽。
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 * 提示：考虑将此库与 {SlotDerivation} 一起使用。
 * 
 * 最主要的原因是为了实现可升级代理模式（如 UUPS 或透明代理）。
 * StorageSlot 库的设计目的就是为了绕过编译器的自动存储打包，实现对特定、精确的 32 字节存储槽的读写。
 * 在这种情况下，您会牺牲编译器自动打包带来的 gas优化，以换取对存储的绝对控制。
 * 所以，当您使用 StorageSlot.getBooleanSlot(bytes32 slot) 时，
 * 您就是在告诉 EVM：“请在这个特定的 32字节槽中存储或读取一个布尔值”，即使这个布尔值本身只占用很小的空间。
 */
library StorageSlot {

    /**
     *  为什么需要用struct包装各个类型?
     *      1.Solidity 语言本身不允许你直接从一个任意的 bytes32 存储槽地址“创建”一个 uint256 storage 或 address storage类型的引用并返回。
     *          编译器无法直接理解如何将一个原始的存储槽地址安全地转换为一个特定类型的存储引用。
     *      2.StorageSlot 库的核心在于它使用了内联汇编 (assembly) 来直接操作存储槽。在汇编中，你可以使用 sload（从存储加载）和
                sstore（向存储写入）操作码来读写任何 32 字节的存储位置。
            3.这个 struct 充当了一个指向特定存储槽的“句柄”或“包装器”。    
            4.通过结构体包装，代码具有更好的类型安全性。当你得到一个 AddressSlot 时，你就知道这个槽位存储的是一个 address 类型的值。
     */

    struct AddressSlot {
        address value;
    }

    // 虽然 Boolean 在编译器中通常被打包为一个字节，但在 StorageSlot 库中，会占用一个存储槽（32 字节）。
    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev 返回一个 `AddressSlot`，其成员 `value` 位于 `slot`。
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev 返回一个 `BooleanSlot`，其成员 `value` 位于 `slot`。
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev 返回一个 `Bytes32Slot`，其成员 `value` 位于 `slot`。
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev 返回一个 `Uint256Slot`，其成员 `value` 位于 `slot`。
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev 返回一个 `Int256Slot`，其成员 `value` 位于 `slot`。
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev 返回一个 `StringSlot`，其成员 `value` 位于 `slot`。
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev 返回字符串存储指针 `store` 的 `StringSlot` 表示。
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev 返回一个 `BytesSlot`，其成员 `value` 位于 `slot`。
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev 返回字节存储指针 `store` 的 `BytesSlot` 表示。
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}
