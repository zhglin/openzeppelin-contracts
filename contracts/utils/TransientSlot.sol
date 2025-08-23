// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/TransientSlot.sol)
// This file was procedurally generated from scripts/generate/templates/TransientSlot.js.

pragma solidity ^0.8.24;

/**
 * @dev 用于将值类型读写到特定瞬态存储槽的库。
 *
 * 瞬态槽通常用于存储在当前交易后被移除的临时值。
 * 该库有助于读写这些槽，而无需内联汇编。
 *
 *  * 使用瞬态存储读写值的示例：
 * ```solidity
 * contract Lock {
 *     using TransientSlot for *;
 *
 *     // 定义槽。或者，使用 SlotDerivation 库来派生槽。
 *     // 为了防止在同一交易中发生重入调用。一旦交易完成，这个保护标志必须被重置，以便未来的、独立的交易可以再次调用该函数。
 *     // 如果它持久化了，函数在第一次调用后就会被永久锁定。
 *     bytes32 internal constant _LOCK_SLOT = 0xf4678858b2b588224636b8522b729e7722d32fc491da849ed75b3fdf3c84f542;
 *
 *     modifier locked() {
 *         require(!_LOCK_SLOT.asBoolean().tload());
 *
 *         _LOCK_SLOT.asBoolean().tstore(true);
 *         _;
 *         _LOCK_SLOT.asBoolean().tstore(false);
 *     }
 * }
 * ```
 * 
 * 瞬态存储槽（Transient Storage Slots）是 EVM（以太坊虚拟机）中一种新型的存储机制，它是在 EIP-1153 (Transient Storage) 中引入的。
 * 它的主要特点和作用如下：
 * 1. 什么是瞬态存储？
 *  它是一种临时性的、仅在当前交易执行期间有效的存储空间。
 *  与常规的链上存储（Storage）不同，瞬态存储中的数据在交易结束时会自动清除，不会被写入区块链的状态中。
 *  每个合约都有自己私有的、临时的白板，这个白板在交易结束时会被擦干净。如果合约 A在它自己的白板上写了东西，只有合约 A 能看到/修改。
 *  如果合约 B 在它自己的白板上写了东西，只有合约 B 能看到/修改。但是，如果合约 A 调用合约B，然后合约 B 又回调合约 A，那么合约 A 仍然可以看到它在交易早期写在它自己白板上的内容。
 * 2. 关键特性：
 *  短暂性 (Ephemeral)：数据只在当前交易的生命周期内存在。一旦交易完成（无论是成功还是失败），所有瞬态存储中的数据都会被销毁。
 *      成本低廉 (Cheap)：由于数据不持久化到链上，瞬态存储的 gas 成本远低于常规的 sstore（写入常规存储）操作。这使得它非常适合存储临时数据。
 *      跨内部调用可访问 (Accessible Across Internal Calls)：这是它与内存（Memory）存储的主要区别之一。
 *      在同一个交易中，即使是不同的内部函数调用（例如 A 调用 B，B 调用C），它们都可以访问和修改相同的瞬态存储槽中的数据。
 * 3. 为什么它有用？（主要用例）：
 *  重入保护 (Reentrancy Guards)：这是最典型的用例。在 TransientSlot.sol 的示例中，locked 修饰符就是利用瞬态存储来实现重入保护。在函数开始
 *      时设置一个瞬态标志，函数结束时清除，确保在同一交易中不会被重复调用。由于数据在交易结束时自动清除，无需额外的 gas 成本来重置标志。
 *      临时标志或状态 (Temporary Flags/States)：在复杂的、多步骤的交易中，你可能需要在不同的内部函数调用之间传递或共享一些临时状态或标志。使
 *      用瞬态存储可以避免将这些临时数据写入昂贵的常规存储，从而节省 gas。
 *      优化 Gas 成本：任何不需要在交易之间持久化的临时数据，都可以考虑使用瞬态存储来替代常规存储，以显著降低 gas 消耗。
 * 4. 与其他存储类型的区别：
 *      常规存储 (Storage)：数据持久化到区块链状态中，成本高昂。用于存储合约的永久状态。
 *      内存 (Memory)：数据仅在当前函数调用期间存在，成本低廉。主要用于函数内部的临时变量和数据结构。它不能像瞬态存储那样方便地跨内部调用共享状态。
 *      Calldata：只读，数据来自外部调用，成本最低。主要用于函数参数。
 * 在 EVM 层面，瞬态存储通过新的操作码 TSTORE（写入瞬态存储）和 TLOAD（从瞬态存储读取）来操作。
 * TransientSlot.sol库就是对这些底层操作码的封装，提供了更高级、更安全的 Solidity 接口。
 *
 * 提示：考虑将此库与 {SlotDerivation} 一起使用。
 */
library TransientSlot {
    /**
     * 一个用户定义的值类型是用 type C is V 定义的，其中 C 是新引入的类型的名称， V 必须是一个内置的值类型（“底层类型”）。 
     * 函数 C.wrap 被用来从底层类型转换到自定义类型。
     * 同样地， 函数 C.unwrap 被用来从自定义类型转换到底层类型。
     */

    /**
     * @dev 表示持有地址的槽的 UDVT（用户定义值类型）。
     */
    type AddressSlot is bytes32;

    /**
     * @dev 将任意槽转换为 AddressSlot。
     */
    function asAddress(bytes32 slot) internal pure returns (AddressSlot) {
        return AddressSlot.wrap(slot);
    }

    /**
     * @dev 表示持有布尔值的槽的 UDVT。
     */
    type BooleanSlot is bytes32;

    /**
     * @dev 将任意槽转换为 BooleanSlot。
     */
    function asBoolean(bytes32 slot) internal pure returns (BooleanSlot) {
        return BooleanSlot.wrap(slot);
    }

    /**
     * @dev 表示持有 bytes32 的槽的 UDVT。
     */
    type Bytes32Slot is bytes32;

    /**
     * @dev 将任意槽转换为 Bytes32Slot。
     */
    function asBytes32(bytes32 slot) internal pure returns (Bytes32Slot) {
        return Bytes32Slot.wrap(slot);
    }

    /**
     * @dev 表示持有 uint256 的槽的 UDVT。
     */
    type Uint256Slot is bytes32;

    /**
     * @dev 将任意槽转换为 Uint256Slot。
     */
    function asUint256(bytes32 slot) internal pure returns (Uint256Slot) {
        return Uint256Slot.wrap(slot);
    }

    /**
     * @dev 表示持有 int256 的槽的 UDVT。
     */
    type Int256Slot is bytes32;

    /**
     * @dev 将任意槽转换为 Int256Slot。
     */
    function asInt256(bytes32 slot) internal pure returns (Int256Slot) {
        return Int256Slot.wrap(slot);
    }

    /**
     * @dev 从瞬态存储中加载位于 `slot` 位置的值。
     */
    function tload(AddressSlot slot) internal view returns (address value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev 将 `value` 存储到瞬态存储中 `slot` 位置。
     */
    function tstore(AddressSlot slot, address value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev 从瞬态存储中加载位于 `slot` 位置的值。
     */
    function tload(BooleanSlot slot) internal view returns (bool value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev 将 `value` 存储到瞬态存储中 `slot` 位置。
     */
    function tstore(BooleanSlot slot, bool value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev 从瞬态存储中加载位于 `slot` 位置的值。
     */
    function tload(Bytes32Slot slot) internal view returns (bytes32 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev 将 `value` 存储到瞬态存储中 `slot` 位置。
     */
    function tstore(Bytes32Slot slot, bytes32 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev 从瞬态存储中加载位于 `slot` 位置的值。
     */
    function tload(Uint256Slot slot) internal view returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev 将 `value` 存储到瞬态存储中 `slot` 位置。
     */
    function tstore(Uint256Slot slot, uint256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev 从瞬态存储中加载位于 `slot` 位置的值。
     */
    function tload(Int256Slot slot) internal view returns (int256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev 将 `value` 存储到瞬态存储中 `slot` 位置。
     */
    function tstore(Int256Slot slot, int256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }
}
