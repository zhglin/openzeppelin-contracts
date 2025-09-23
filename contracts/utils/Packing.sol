// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (utils/Packing.sol)
// This file was procedurally generated from scripts/generate/templates/Packing.js.

pragma solidity ^0.8.20;

/**
 * @dev Helper library packing and unpacking multiple values into bytesXX.
 *
 * Example usage:
 *
 * ```solidity
 * library MyPacker {
 *     type MyType is bytes32;
 *
 *     function _pack(address account, bytes4 selector, uint64 period) external pure returns (MyType) {
 *         bytes12 subpack = Packing.pack_4_8(selector, bytes8(period));
 *         bytes32 pack = Packing.pack_20_12(bytes20(account), subpack);
 *         return MyType.wrap(pack);
 *     }
 *
 *     function _unpack(MyType self) external pure returns (address, bytes4, uint64) {
 *         bytes32 pack = MyType.unwrap(self);
 *         return (
 *             address(Packing.extract_32_20(pack, 0)),
 *             Packing.extract_32_4(pack, 20),
 *             uint64(Packing.extract_32_8(pack, 24))
 *         );
 *     }
 * }
 * ```
 *
 * _Available since v5.1._
 */
// solhint-disable func-name-mixedcase
library Packing {
    error OutOfRangeAccess();

    // 将两个 bytes1 类型的变量 (left 和 right) “打包”或“拼接”成一个 bytes2 类型的变量。
    // EVM 在处理数据时，其基本单位是一个 32 字节（256 位）的“字 (word)”。
    // 这意味着，即使像 bytes1 或 bytes2 这样的小数据类型，当它们被加载到堆栈上进行操作时，也会被填充成一个完整的 32 字节的字。
    function pack_1_1(bytes1 left, bytes1 right) internal pure returns (bytes2 result) {
        assembly ("memory-safe") {
            // not(0) 对其取反会得到一个所有 256 位都为 1 的字，即 0xFFFFFF...FF
            // shl(248, not(0)) 向左移动 248 位后, 会得到 0xFF0000...00(第一个字节是 FF，后面 31 个字节是 00)
            // and(left, ...) 通过与运算，保留 left 的第一个有效字节，
            // 确保 left 变量中除了第一个字节外，没有任何“脏数据”
            left := and(left, shl(248, not(0)))
            right := and(right, shl(248, not(0)))
            // shr(8, right) shr 是“向右移位”(Shift Right)。这条指令将清理过的 right 变量向右移动 8 位（即 1 个字节）。
            // or(left, ...): or 是按位或操作。它将清理过的 left 和移位后的 right 进行“或”运算。
            result := or(left, shr(8, right))
        }
    }

    function pack_2_2(bytes2 left, bytes2 right) internal pure returns (bytes4 result) {
        assembly ("memory-safe") {
            left := and(left, shl(240, not(0)))
            right := and(right, shl(240, not(0)))
            result := or(left, shr(16, right))
        }
    }

    // 将一个 bytes2 类型的变量 (left) 和一个 bytes4 类型的变量 (right) 打包成一个 bytes6 类型的变量 (result)。
    function pack_2_4(bytes2 left, bytes4 right) internal pure returns (bytes6 result) {
        assembly ("memory-safe") {
            // shl(240, not(0)) 结果是 0xFFFF00...00 (前两个字节是 FF，后面 30 个字节是 00)
            left := and(left, shl(240, not(0)))
            // shl(224, not(0)) 结果是 0xFFFFFFFF0000...00 (前四个字节是 FF，后面 28 个字节是 00)
            right := and(right, shl(224, not(0)))
            // shr(16, right) 将 right 向右移动 16 位（即 2 个字节），这样 right 的前四个字节就会占据 result 的第 3 到第 6 个字节位置。
            result := or(left, shr(16, right))
        }
    }

    function pack_2_6(bytes2 left, bytes6 right) internal pure returns (bytes8 result) {
        assembly ("memory-safe") {
            left := and(left, shl(240, not(0)))
            right := and(right, shl(208, not(0)))
            result := or(left, shr(16, right))
        }
    }

    function pack_2_8(bytes2 left, bytes8 right) internal pure returns (bytes10 result) {
        assembly ("memory-safe") {
            left := and(left, shl(240, not(0)))
            right := and(right, shl(192, not(0)))
            result := or(left, shr(16, right))
        }
    }

    function pack_2_10(bytes2 left, bytes10 right) internal pure returns (bytes12 result) {
        assembly ("memory-safe") {
            left := and(left, shl(240, not(0)))
            right := and(right, shl(176, not(0)))
            result := or(left, shr(16, right))
        }
    }

    function pack_2_20(bytes2 left, bytes20 right) internal pure returns (bytes22 result) {
        assembly ("memory-safe") {
            left := and(left, shl(240, not(0)))
            right := and(right, shl(96, not(0)))
            result := or(left, shr(16, right))
        }
    }

    function pack_2_22(bytes2 left, bytes22 right) internal pure returns (bytes24 result) {
        assembly ("memory-safe") {
            left := and(left, shl(240, not(0)))
            right := and(right, shl(80, not(0)))
            result := or(left, shr(16, right))
        }
    }

    function pack_4_2(bytes4 left, bytes2 right) internal pure returns (bytes6 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(240, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_4_4(bytes4 left, bytes4 right) internal pure returns (bytes8 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(224, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_4_6(bytes4 left, bytes6 right) internal pure returns (bytes10 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(208, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_4_8(bytes4 left, bytes8 right) internal pure returns (bytes12 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(192, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_4_12(bytes4 left, bytes12 right) internal pure returns (bytes16 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(160, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_4_16(bytes4 left, bytes16 right) internal pure returns (bytes20 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(128, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_4_20(bytes4 left, bytes20 right) internal pure returns (bytes24 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(96, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_4_24(bytes4 left, bytes24 right) internal pure returns (bytes28 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(64, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_4_28(bytes4 left, bytes28 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            left := and(left, shl(224, not(0)))
            right := and(right, shl(32, not(0)))
            result := or(left, shr(32, right))
        }
    }

    function pack_6_2(bytes6 left, bytes2 right) internal pure returns (bytes8 result) {
        assembly ("memory-safe") {
            left := and(left, shl(208, not(0)))
            right := and(right, shl(240, not(0)))
            result := or(left, shr(48, right))
        }
    }

    // 将一个 bytes6 类型的变量 (left) 和一个 bytes4 类型的变量 (right) 打包成一个 bytes10 类型的变量 (result)。
    function pack_6_4(bytes6 left, bytes4 right) internal pure returns (bytes10 result) {
        assembly ("memory-safe") {
            // shl(208, not(0)) 结果是 0xFFFFFFFFFFFF0000...00 (前六个字节是 FF，后面 26 个字节是 00)
            left := and(left, shl(208, not(0)))
            // shl(224, not(0)) 结果是 0xFFFFFFFF0000...00 (前四个字节是 FF，后面 28 个字节是 00)
            right := and(right, shl(224, not(0)))
            // shr(48, right) 将 right 向右移动 48 位（即 6 个字节），这样 right 的前四个字节就会占据 result 的第 7 到第 10 个字节位置。
            result := or(left, shr(48, right))
        }
    }

    function pack_6_6(bytes6 left, bytes6 right) internal pure returns (bytes12 result) {
        assembly ("memory-safe") {
            left := and(left, shl(208, not(0)))
            right := and(right, shl(208, not(0)))
            result := or(left, shr(48, right))
        }
    }

    function pack_6_10(bytes6 left, bytes10 right) internal pure returns (bytes16 result) {
        assembly ("memory-safe") {
            left := and(left, shl(208, not(0)))
            right := and(right, shl(176, not(0)))
            result := or(left, shr(48, right))
        }
    }

    function pack_6_16(bytes6 left, bytes16 right) internal pure returns (bytes22 result) {
        assembly ("memory-safe") {
            left := and(left, shl(208, not(0)))
            right := and(right, shl(128, not(0)))
            result := or(left, shr(48, right))
        }
    }

    function pack_6_22(bytes6 left, bytes22 right) internal pure returns (bytes28 result) {
        assembly ("memory-safe") {
            left := and(left, shl(208, not(0)))
            right := and(right, shl(80, not(0)))
            result := or(left, shr(48, right))
        }
    }

    function pack_8_2(bytes8 left, bytes2 right) internal pure returns (bytes10 result) {
        assembly ("memory-safe") {
            left := and(left, shl(192, not(0)))
            right := and(right, shl(240, not(0)))
            result := or(left, shr(64, right))
        }
    }

    function pack_8_4(bytes8 left, bytes4 right) internal pure returns (bytes12 result) {
        assembly ("memory-safe") {
            left := and(left, shl(192, not(0)))
            right := and(right, shl(224, not(0)))
            result := or(left, shr(64, right))
        }
    }

    function pack_8_8(bytes8 left, bytes8 right) internal pure returns (bytes16 result) {
        assembly ("memory-safe") {
            left := and(left, shl(192, not(0)))
            right := and(right, shl(192, not(0)))
            result := or(left, shr(64, right))
        }
    }

    function pack_8_12(bytes8 left, bytes12 right) internal pure returns (bytes20 result) {
        assembly ("memory-safe") {
            left := and(left, shl(192, not(0)))
            right := and(right, shl(160, not(0)))
            result := or(left, shr(64, right))
        }
    }

    function pack_8_16(bytes8 left, bytes16 right) internal pure returns (bytes24 result) {
        assembly ("memory-safe") {
            left := and(left, shl(192, not(0)))
            right := and(right, shl(128, not(0)))
            result := or(left, shr(64, right))
        }
    }

    function pack_8_20(bytes8 left, bytes20 right) internal pure returns (bytes28 result) {
        assembly ("memory-safe") {
            left := and(left, shl(192, not(0)))
            right := and(right, shl(96, not(0)))
            result := or(left, shr(64, right))
        }
    }

    function pack_8_24(bytes8 left, bytes24 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            left := and(left, shl(192, not(0)))
            right := and(right, shl(64, not(0)))
            result := or(left, shr(64, right))
        }
    }

    function pack_10_2(bytes10 left, bytes2 right) internal pure returns (bytes12 result) {
        assembly ("memory-safe") {
            left := and(left, shl(176, not(0)))
            right := and(right, shl(240, not(0)))
            result := or(left, shr(80, right))
        }
    }

    function pack_10_6(bytes10 left, bytes6 right) internal pure returns (bytes16 result) {
        assembly ("memory-safe") {
            left := and(left, shl(176, not(0)))
            right := and(right, shl(208, not(0)))
            result := or(left, shr(80, right))
        }
    }

    function pack_10_10(bytes10 left, bytes10 right) internal pure returns (bytes20 result) {
        assembly ("memory-safe") {
            left := and(left, shl(176, not(0)))
            right := and(right, shl(176, not(0)))
            result := or(left, shr(80, right))
        }
    }

    function pack_10_12(bytes10 left, bytes12 right) internal pure returns (bytes22 result) {
        assembly ("memory-safe") {
            left := and(left, shl(176, not(0)))
            right := and(right, shl(160, not(0)))
            result := or(left, shr(80, right))
        }
    }

    // 将一个 bytes10 类型的变量 (left) 和一个 bytes22 类型的变量 (right) 打包成一个 bytes32 类型的变量 (result)。
    function pack_10_22(bytes10 left, bytes22 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // shl(176, not(0)) 结果是 0xFFFFFFFFFFFF...FF0000000000 (前十个字节是 FF，后面 22 个字节是 00)
            left := and(left, shl(176, not(0)))
            // shl(80, not(0)) 结果是 0xFFFFFFFFFFFF...FFFF0000000000000000000000 (前二十二个字节是 FF，后面 10 个字节是 00)
            right := and(right, shl(80, not(0)))
            // shr(80, right) 将 right 向右移动 80 位（即 10 个字节），这样 right 的前二十二个字节就会占据 result 的第 11 到第 32 个字节位置。
            result := or(left, shr(80, right))
        }
    }

    function pack_12_4(bytes12 left, bytes4 right) internal pure returns (bytes16 result) {
        assembly ("memory-safe") {
            left := and(left, shl(160, not(0)))
            right := and(right, shl(224, not(0)))
            result := or(left, shr(96, right))
        }
    }

    function pack_12_8(bytes12 left, bytes8 right) internal pure returns (bytes20 result) {
        assembly ("memory-safe") {
            left := and(left, shl(160, not(0)))
            right := and(right, shl(192, not(0)))
            result := or(left, shr(96, right))
        }
    }

    function pack_12_10(bytes12 left, bytes10 right) internal pure returns (bytes22 result) {
        assembly ("memory-safe") {
            left := and(left, shl(160, not(0)))
            right := and(right, shl(176, not(0)))
            result := or(left, shr(96, right))
        }
    }

    function pack_12_12(bytes12 left, bytes12 right) internal pure returns (bytes24 result) {
        assembly ("memory-safe") {
            left := and(left, shl(160, not(0)))
            right := and(right, shl(160, not(0)))
            result := or(left, shr(96, right))
        }
    }

    function pack_12_16(bytes12 left, bytes16 right) internal pure returns (bytes28 result) {
        assembly ("memory-safe") {
            left := and(left, shl(160, not(0)))
            right := and(right, shl(128, not(0)))
            result := or(left, shr(96, right))
        }
    }

    function pack_12_20(bytes12 left, bytes20 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            left := and(left, shl(160, not(0)))
            right := and(right, shl(96, not(0)))
            result := or(left, shr(96, right))
        }
    }

    function pack_16_4(bytes16 left, bytes4 right) internal pure returns (bytes20 result) {
        assembly ("memory-safe") {
            left := and(left, shl(128, not(0)))
            right := and(right, shl(224, not(0)))
            result := or(left, shr(128, right))
        }
    }

    function pack_16_6(bytes16 left, bytes6 right) internal pure returns (bytes22 result) {
        assembly ("memory-safe") {
            left := and(left, shl(128, not(0)))
            right := and(right, shl(208, not(0)))
            result := or(left, shr(128, right))
        }
    }

    function pack_16_8(bytes16 left, bytes8 right) internal pure returns (bytes24 result) {
        assembly ("memory-safe") {
            left := and(left, shl(128, not(0)))
            right := and(right, shl(192, not(0)))
            result := or(left, shr(128, right))
        }
    }

    function pack_16_12(bytes16 left, bytes12 right) internal pure returns (bytes28 result) {
        assembly ("memory-safe") {
            left := and(left, shl(128, not(0)))
            right := and(right, shl(160, not(0)))
            result := or(left, shr(128, right))
        }
    }

    function pack_16_16(bytes16 left, bytes16 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            left := and(left, shl(128, not(0)))
            right := and(right, shl(128, not(0)))
            result := or(left, shr(128, right))
        }
    }

    function pack_20_2(bytes20 left, bytes2 right) internal pure returns (bytes22 result) {
        assembly ("memory-safe") {
            left := and(left, shl(96, not(0)))
            right := and(right, shl(240, not(0)))
            result := or(left, shr(160, right))
        }
    }

    function pack_20_4(bytes20 left, bytes4 right) internal pure returns (bytes24 result) {
        assembly ("memory-safe") {
            left := and(left, shl(96, not(0)))
            right := and(right, shl(224, not(0)))
            result := or(left, shr(160, right))
        }
    }

    function pack_20_8(bytes20 left, bytes8 right) internal pure returns (bytes28 result) {
        assembly ("memory-safe") {
            left := and(left, shl(96, not(0)))
            right := and(right, shl(192, not(0)))
            result := or(left, shr(160, right))
        }
    }

    function pack_20_12(bytes20 left, bytes12 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            left := and(left, shl(96, not(0)))
            right := and(right, shl(160, not(0)))
            result := or(left, shr(160, right))
        }
    }

    function pack_22_2(bytes22 left, bytes2 right) internal pure returns (bytes24 result) {
        assembly ("memory-safe") {
            left := and(left, shl(80, not(0)))
            right := and(right, shl(240, not(0)))
            result := or(left, shr(176, right))
        }
    }

    function pack_22_6(bytes22 left, bytes6 right) internal pure returns (bytes28 result) {
        assembly ("memory-safe") {
            left := and(left, shl(80, not(0)))
            right := and(right, shl(208, not(0)))
            result := or(left, shr(176, right))
        }
    }

    function pack_22_10(bytes22 left, bytes10 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            left := and(left, shl(80, not(0)))
            right := and(right, shl(176, not(0)))
            result := or(left, shr(176, right))
        }
    }

    function pack_24_4(bytes24 left, bytes4 right) internal pure returns (bytes28 result) {
        assembly ("memory-safe") {
            left := and(left, shl(64, not(0)))
            right := and(right, shl(224, not(0)))
            result := or(left, shr(192, right))
        }
    }

    function pack_24_8(bytes24 left, bytes8 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            left := and(left, shl(64, not(0)))
            right := and(right, shl(192, not(0)))
            result := or(left, shr(192, right))
        }
    }

    function pack_28_4(bytes28 left, bytes4 right) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            left := and(left, shl(32, not(0)))
            right := and(right, shl(224, not(0)))
            result := or(left, shr(224, right))
        }
    }

    function extract_2_1(bytes2 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 1) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_2_1(bytes2 self, bytes1 value, uint8 offset) internal pure returns (bytes2 result) {
        bytes1 oldValue = extract_2_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_4_1(bytes4 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 3) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_4_1(bytes4 self, bytes1 value, uint8 offset) internal pure returns (bytes4 result) {
        bytes1 oldValue = extract_4_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_4_2(bytes4 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 2) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_4_2(bytes4 self, bytes2 value, uint8 offset) internal pure returns (bytes4 result) {
        bytes2 oldValue = extract_4_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_6_1(bytes6 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 5) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_6_1(bytes6 self, bytes1 value, uint8 offset) internal pure returns (bytes6 result) {
        bytes1 oldValue = extract_6_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_6_2(bytes6 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_6_2(bytes6 self, bytes2 value, uint8 offset) internal pure returns (bytes6 result) {
        bytes2 oldValue = extract_6_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_6_4(bytes6 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 2) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_6_4(bytes6 self, bytes4 value, uint8 offset) internal pure returns (bytes6 result) {
        bytes4 oldValue = extract_6_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_8_1(bytes8 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 7) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_8_1(bytes8 self, bytes1 value, uint8 offset) internal pure returns (bytes8 result) {
        bytes1 oldValue = extract_8_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_8_2(bytes8 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 6) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_8_2(bytes8 self, bytes2 value, uint8 offset) internal pure returns (bytes8 result) {
        bytes2 oldValue = extract_8_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_8_4(bytes8 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_8_4(bytes8 self, bytes4 value, uint8 offset) internal pure returns (bytes8 result) {
        bytes4 oldValue = extract_8_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_8_6(bytes8 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 2) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_8_6(bytes8 self, bytes6 value, uint8 offset) internal pure returns (bytes8 result) {
        bytes6 oldValue = extract_8_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_10_1(bytes10 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 9) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_10_1(bytes10 self, bytes1 value, uint8 offset) internal pure returns (bytes10 result) {
        bytes1 oldValue = extract_10_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_10_2(bytes10 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 8) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_10_2(bytes10 self, bytes2 value, uint8 offset) internal pure returns (bytes10 result) {
        bytes2 oldValue = extract_10_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_10_4(bytes10 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 6) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_10_4(bytes10 self, bytes4 value, uint8 offset) internal pure returns (bytes10 result) {
        bytes4 oldValue = extract_10_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_10_6(bytes10 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_10_6(bytes10 self, bytes6 value, uint8 offset) internal pure returns (bytes10 result) {
        bytes6 oldValue = extract_10_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_10_8(bytes10 self, uint8 offset) internal pure returns (bytes8 result) {
        if (offset > 2) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(192, not(0)))
        }
    }

    function replace_10_8(bytes10 self, bytes8 value, uint8 offset) internal pure returns (bytes10 result) {
        bytes8 oldValue = extract_10_8(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(192, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_12_1(bytes12 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 11) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_12_1(bytes12 self, bytes1 value, uint8 offset) internal pure returns (bytes12 result) {
        bytes1 oldValue = extract_12_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_12_2(bytes12 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 10) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_12_2(bytes12 self, bytes2 value, uint8 offset) internal pure returns (bytes12 result) {
        bytes2 oldValue = extract_12_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_12_4(bytes12 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 8) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_12_4(bytes12 self, bytes4 value, uint8 offset) internal pure returns (bytes12 result) {
        bytes4 oldValue = extract_12_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_12_6(bytes12 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 6) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_12_6(bytes12 self, bytes6 value, uint8 offset) internal pure returns (bytes12 result) {
        bytes6 oldValue = extract_12_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_12_8(bytes12 self, uint8 offset) internal pure returns (bytes8 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(192, not(0)))
        }
    }

    function replace_12_8(bytes12 self, bytes8 value, uint8 offset) internal pure returns (bytes12 result) {
        bytes8 oldValue = extract_12_8(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(192, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_12_10(bytes12 self, uint8 offset) internal pure returns (bytes10 result) {
        if (offset > 2) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(176, not(0)))
        }
    }

    function replace_12_10(bytes12 self, bytes10 value, uint8 offset) internal pure returns (bytes12 result) {
        bytes10 oldValue = extract_12_10(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(176, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_16_1(bytes16 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 15) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_16_1(bytes16 self, bytes1 value, uint8 offset) internal pure returns (bytes16 result) {
        bytes1 oldValue = extract_16_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_16_2(bytes16 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 14) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_16_2(bytes16 self, bytes2 value, uint8 offset) internal pure returns (bytes16 result) {
        bytes2 oldValue = extract_16_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_16_4(bytes16 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 12) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_16_4(bytes16 self, bytes4 value, uint8 offset) internal pure returns (bytes16 result) {
        bytes4 oldValue = extract_16_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_16_6(bytes16 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 10) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_16_6(bytes16 self, bytes6 value, uint8 offset) internal pure returns (bytes16 result) {
        bytes6 oldValue = extract_16_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_16_8(bytes16 self, uint8 offset) internal pure returns (bytes8 result) {
        if (offset > 8) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(192, not(0)))
        }
    }

    function replace_16_8(bytes16 self, bytes8 value, uint8 offset) internal pure returns (bytes16 result) {
        bytes8 oldValue = extract_16_8(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(192, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_16_10(bytes16 self, uint8 offset) internal pure returns (bytes10 result) {
        if (offset > 6) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(176, not(0)))
        }
    }

    function replace_16_10(bytes16 self, bytes10 value, uint8 offset) internal pure returns (bytes16 result) {
        bytes10 oldValue = extract_16_10(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(176, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_16_12(bytes16 self, uint8 offset) internal pure returns (bytes12 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(160, not(0)))
        }
    }

    function replace_16_12(bytes16 self, bytes12 value, uint8 offset) internal pure returns (bytes16 result) {
        bytes12 oldValue = extract_16_12(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(160, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_20_1(bytes20 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 19) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_20_1(bytes20 self, bytes1 value, uint8 offset) internal pure returns (bytes20 result) {
        bytes1 oldValue = extract_20_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_20_2(bytes20 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 18) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_20_2(bytes20 self, bytes2 value, uint8 offset) internal pure returns (bytes20 result) {
        bytes2 oldValue = extract_20_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_20_4(bytes20 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 16) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_20_4(bytes20 self, bytes4 value, uint8 offset) internal pure returns (bytes20 result) {
        bytes4 oldValue = extract_20_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_20_6(bytes20 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 14) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_20_6(bytes20 self, bytes6 value, uint8 offset) internal pure returns (bytes20 result) {
        bytes6 oldValue = extract_20_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_20_8(bytes20 self, uint8 offset) internal pure returns (bytes8 result) {
        if (offset > 12) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(192, not(0)))
        }
    }

    function replace_20_8(bytes20 self, bytes8 value, uint8 offset) internal pure returns (bytes20 result) {
        bytes8 oldValue = extract_20_8(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(192, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_20_10(bytes20 self, uint8 offset) internal pure returns (bytes10 result) {
        if (offset > 10) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(176, not(0)))
        }
    }

    function replace_20_10(bytes20 self, bytes10 value, uint8 offset) internal pure returns (bytes20 result) {
        bytes10 oldValue = extract_20_10(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(176, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_20_12(bytes20 self, uint8 offset) internal pure returns (bytes12 result) {
        if (offset > 8) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(160, not(0)))
        }
    }

    function replace_20_12(bytes20 self, bytes12 value, uint8 offset) internal pure returns (bytes20 result) {
        bytes12 oldValue = extract_20_12(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(160, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_20_16(bytes20 self, uint8 offset) internal pure returns (bytes16 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(128, not(0)))
        }
    }

    function replace_20_16(bytes20 self, bytes16 value, uint8 offset) internal pure returns (bytes20 result) {
        bytes16 oldValue = extract_20_16(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(128, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_1(bytes22 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 21) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_22_1(bytes22 self, bytes1 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes1 oldValue = extract_22_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_2(bytes22 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 20) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_22_2(bytes22 self, bytes2 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes2 oldValue = extract_22_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_4(bytes22 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 18) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_22_4(bytes22 self, bytes4 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes4 oldValue = extract_22_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_6(bytes22 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 16) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_22_6(bytes22 self, bytes6 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes6 oldValue = extract_22_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_8(bytes22 self, uint8 offset) internal pure returns (bytes8 result) {
        if (offset > 14) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(192, not(0)))
        }
    }

    function replace_22_8(bytes22 self, bytes8 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes8 oldValue = extract_22_8(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(192, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_10(bytes22 self, uint8 offset) internal pure returns (bytes10 result) {
        if (offset > 12) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(176, not(0)))
        }
    }

    function replace_22_10(bytes22 self, bytes10 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes10 oldValue = extract_22_10(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(176, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_12(bytes22 self, uint8 offset) internal pure returns (bytes12 result) {
        if (offset > 10) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(160, not(0)))
        }
    }

    function replace_22_12(bytes22 self, bytes12 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes12 oldValue = extract_22_12(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(160, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_16(bytes22 self, uint8 offset) internal pure returns (bytes16 result) {
        if (offset > 6) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(128, not(0)))
        }
    }

    function replace_22_16(bytes22 self, bytes16 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes16 oldValue = extract_22_16(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(128, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_22_20(bytes22 self, uint8 offset) internal pure returns (bytes20 result) {
        if (offset > 2) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(96, not(0)))
        }
    }

    function replace_22_20(bytes22 self, bytes20 value, uint8 offset) internal pure returns (bytes22 result) {
        bytes20 oldValue = extract_22_20(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(96, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_1(bytes24 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 23) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_24_1(bytes24 self, bytes1 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes1 oldValue = extract_24_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_2(bytes24 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 22) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_24_2(bytes24 self, bytes2 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes2 oldValue = extract_24_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_4(bytes24 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 20) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_24_4(bytes24 self, bytes4 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes4 oldValue = extract_24_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_6(bytes24 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 18) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_24_6(bytes24 self, bytes6 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes6 oldValue = extract_24_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_8(bytes24 self, uint8 offset) internal pure returns (bytes8 result) {
        if (offset > 16) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(192, not(0)))
        }
    }

    function replace_24_8(bytes24 self, bytes8 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes8 oldValue = extract_24_8(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(192, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_10(bytes24 self, uint8 offset) internal pure returns (bytes10 result) {
        if (offset > 14) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(176, not(0)))
        }
    }

    function replace_24_10(bytes24 self, bytes10 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes10 oldValue = extract_24_10(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(176, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_12(bytes24 self, uint8 offset) internal pure returns (bytes12 result) {
        if (offset > 12) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(160, not(0)))
        }
    }

    function replace_24_12(bytes24 self, bytes12 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes12 oldValue = extract_24_12(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(160, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_16(bytes24 self, uint8 offset) internal pure returns (bytes16 result) {
        if (offset > 8) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(128, not(0)))
        }
    }

    function replace_24_16(bytes24 self, bytes16 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes16 oldValue = extract_24_16(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(128, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_20(bytes24 self, uint8 offset) internal pure returns (bytes20 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(96, not(0)))
        }
    }

    function replace_24_20(bytes24 self, bytes20 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes20 oldValue = extract_24_20(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(96, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_24_22(bytes24 self, uint8 offset) internal pure returns (bytes22 result) {
        if (offset > 2) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(80, not(0)))
        }
    }

    function replace_24_22(bytes24 self, bytes22 value, uint8 offset) internal pure returns (bytes24 result) {
        bytes22 oldValue = extract_24_22(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(80, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_1(bytes28 self, uint8 offset) internal pure returns (bytes1 result) {
        if (offset > 27) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_28_1(bytes28 self, bytes1 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes1 oldValue = extract_28_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_2(bytes28 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 26) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_28_2(bytes28 self, bytes2 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes2 oldValue = extract_28_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_4(bytes28 self, uint8 offset) internal pure returns (bytes4 result) {
        if (offset > 24) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_28_4(bytes28 self, bytes4 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes4 oldValue = extract_28_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_6(bytes28 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 22) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_28_6(bytes28 self, bytes6 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes6 oldValue = extract_28_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_8(bytes28 self, uint8 offset) internal pure returns (bytes8 result) {
        if (offset > 20) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(192, not(0)))
        }
    }

    function replace_28_8(bytes28 self, bytes8 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes8 oldValue = extract_28_8(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(192, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_10(bytes28 self, uint8 offset) internal pure returns (bytes10 result) {
        if (offset > 18) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(176, not(0)))
        }
    }

    function replace_28_10(bytes28 self, bytes10 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes10 oldValue = extract_28_10(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(176, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_12(bytes28 self, uint8 offset) internal pure returns (bytes12 result) {
        if (offset > 16) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(160, not(0)))
        }
    }

    function replace_28_12(bytes28 self, bytes12 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes12 oldValue = extract_28_12(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(160, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_16(bytes28 self, uint8 offset) internal pure returns (bytes16 result) {
        if (offset > 12) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(128, not(0)))
        }
    }

    function replace_28_16(bytes28 self, bytes16 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes16 oldValue = extract_28_16(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(128, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_20(bytes28 self, uint8 offset) internal pure returns (bytes20 result) {
        if (offset > 8) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(96, not(0)))
        }
    }

    function replace_28_20(bytes28 self, bytes20 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes20 oldValue = extract_28_20(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(96, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_22(bytes28 self, uint8 offset) internal pure returns (bytes22 result) {
        if (offset > 6) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(80, not(0)))
        }
    }

    function replace_28_22(bytes28 self, bytes22 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes22 oldValue = extract_28_22(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(80, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_28_24(bytes28 self, uint8 offset) internal pure returns (bytes24 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(64, not(0)))
        }
    }

    function replace_28_24(bytes28 self, bytes24 value, uint8 offset) internal pure returns (bytes28 result) {
        bytes24 oldValue = extract_28_24(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(64, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    // 从一个 bytes32（32字节）的数据块中，根据给定的字节偏移量 offset，提取出指定位置的单个字节 (bytes1)。
    function extract_32_1(bytes32 self, uint8 offset) internal pure returns (bytes1 result) {
        // 确保偏移量在有效范围内（0-31），否则抛出异常。
        if (offset > 31) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            // shl(mul(8, offset), self) 将 self 左移 offset*8 位，相当于将目标字节移动到最高位。
            // shl(248, not(0)) 创建一个掩码，只保留最高位的字节，其他位全部为0。
            // and 操作将提取出目标字节，并将其存储在 result
            result := and(shl(mul(8, offset), self), shl(248, not(0)))
        }
    }

    function replace_32_1(bytes32 self, bytes1 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes1 oldValue = extract_32_1(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(248, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_2(bytes32 self, uint8 offset) internal pure returns (bytes2 result) {
        if (offset > 30) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(240, not(0)))
        }
    }

    function replace_32_2(bytes32 self, bytes2 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes2 oldValue = extract_32_2(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(240, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    // 从一个 bytes32（32字节）的数据块中，根据给定的字节偏移量 offset，提取出指定位置的4个连续字节 (bytes4)。
    function extract_32_4(bytes32 self, uint8 offset) internal pure returns (bytes4 result) {
        // 确保偏移量在有效范围内（0-28），否则抛出异常。
        if (offset > 28) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            // 通过位运算提取出指定位置的4个字节
            // shl(mul(8, offset), self) 将 self 左移 offset*8 位，相当于将目标4个字节移动到最高位。
            // shl(224, not(0)) 创建一个掩码，只保留最高位的4个字节，其他位全部为0。
            // and 操作将提取出目标4个字节，并将其存储在 result
            result := and(shl(mul(8, offset), self), shl(224, not(0)))
        }
    }

    function replace_32_4(bytes32 self, bytes4 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes4 oldValue = extract_32_4(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(224, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_6(bytes32 self, uint8 offset) internal pure returns (bytes6 result) {
        if (offset > 26) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(208, not(0)))
        }
    }

    function replace_32_6(bytes32 self, bytes6 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes6 oldValue = extract_32_6(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(208, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_8(bytes32 self, uint8 offset) internal pure returns (bytes8 result) {
        if (offset > 24) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(192, not(0)))
        }
    }

    function replace_32_8(bytes32 self, bytes8 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes8 oldValue = extract_32_8(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(192, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_10(bytes32 self, uint8 offset) internal pure returns (bytes10 result) {
        if (offset > 22) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(176, not(0)))
        }
    }

    function replace_32_10(bytes32 self, bytes10 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes10 oldValue = extract_32_10(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(176, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_12(bytes32 self, uint8 offset) internal pure returns (bytes12 result) {
        if (offset > 20) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(160, not(0)))
        }
    }

    function replace_32_12(bytes32 self, bytes12 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes12 oldValue = extract_32_12(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(160, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_16(bytes32 self, uint8 offset) internal pure returns (bytes16 result) {
        if (offset > 16) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(128, not(0)))
        }
    }

    function replace_32_16(bytes32 self, bytes16 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes16 oldValue = extract_32_16(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(128, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_20(bytes32 self, uint8 offset) internal pure returns (bytes20 result) {
        if (offset > 12) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(96, not(0)))
        }
    }

    function replace_32_20(bytes32 self, bytes20 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes20 oldValue = extract_32_20(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(96, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    // 从一个 bytes32（32字节）的数据块中，根据给定的字节偏移量 offset，提取出指定位置的22个连续字节 (bytes22)。
    function extract_32_22(bytes32 self, uint8 offset) internal pure returns (bytes22 result) {
        // 确保偏移量在有效范围内（0-10），否则抛出异常。
        if (offset > 10) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            // shl(mul(8, offset), self) 将 self 左移 offset*8 位，相当于将目标22个字节移动到最高位。
            // shl(80, not(0)) 创建一个掩码，只保留最高位的22个字节，其他位全部为0。
            // and 操作将提取出目标22个字节，并将其存储在 result
            result := and(shl(mul(8, offset), self), shl(80, not(0)))
        }
    }

    function replace_32_22(bytes32 self, bytes22 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes22 oldValue = extract_32_22(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(80, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_24(bytes32 self, uint8 offset) internal pure returns (bytes24 result) {
        if (offset > 8) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(64, not(0)))
        }
    }

    function replace_32_24(bytes32 self, bytes24 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes24 oldValue = extract_32_24(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(64, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }

    function extract_32_28(bytes32 self, uint8 offset) internal pure returns (bytes28 result) {
        if (offset > 4) revert OutOfRangeAccess();
        assembly ("memory-safe") {
            result := and(shl(mul(8, offset), self), shl(32, not(0)))
        }
    }

    function replace_32_28(bytes32 self, bytes28 value, uint8 offset) internal pure returns (bytes32 result) {
        bytes28 oldValue = extract_32_28(self, offset);
        assembly ("memory-safe") {
            value := and(value, shl(32, not(0)))
            result := xor(self, shr(mul(8, offset), xor(oldValue, value)))
        }
    }
}
