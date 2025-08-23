// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/SlotDerivation.sol)
// This file was procedurally generated from scripts/generate/templates/SlotDerivation.js.

pragma solidity ^0.8.20;

/**
 * @dev 用于从命名空间计算存储（和瞬态存储）位置以及派生与标准模式对应的槽的库。
 * 数组和映射的派生方法与 Solidity 语言/编译器使用的存储布局匹配。
 *
 * 请参阅 https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays[Solidity 映射和动态数组文档]。
 *
 * 示例用法：
 * ```solidity
 * contract Example {
 *     // 添加库方法
 *     using StorageSlot for bytes32;
 *     using SlotDerivation for bytes32;
 *
 *     // 声明一个命名空间
 *     string private constant _NAMESPACE = "<namespace>"; // 例如 OpenZeppelin.Slot
 *
 *     function setValueInNamespace(uint256 key, address newValue) internal {
 *         _NAMESPACE.erc7201Slot().deriveMapping(key).getAddressSlot().value = newValue;
 *     }
 *
 *     function getValueInNamespace(uint256 key) internal view returns (address) {
 *         return _NAMESPACE.erc7201Slot().deriveMapping(key).getAddressSlot().value;
 *     }
 * }
 * ```
 *
 * 提示：考虑将此库与 {StorageSlot} 一起使用。
 * 
 * 注意：此库提供了一种以非标准方式操作存储位置的方法。用于检查升级安全性的工具将忽略通过此库访问的槽。
 *  这种方式绕过了编译器默认的顺序分配机制。能操作的最小单位是一个slot,不再支持紧打包的形式
 * 
 * 用于检查升级安全性的工具将忽略通过此库访问的槽”：
 * 这是警告中最关键的部分。像 OpenZeppelin Upgrades Plugins（用于 Hardhat 或
        Foundry）这样的工具，其设计目的是分析合约的存储布局，并在你执行升级时检测潜在的存储冲突。
 * 这些工具的工作原理是理解 Solidity 的标准存储分配规则。
 *      然而，当你使用 SlotDerivation来访问那些不属于编译器标准顺序分配的槽位（即通过哈希或自定义计算派生出来的槽位）时，
 *      这些工具无法自动跟踪或验证它们。
 * 这些工具只会看到你明确声明的状态变量。它们不会知道 _NAMESPACE.erc7201Slot().deriveMapping(key)
 *      实际上正在写入一个特定的、可能是关键的存储位置。
 * 
 *  这个注意事项是一个强烈的警告，它表明尽管 SlotDerivation 为高级存储管理提供了强大的功能，但其代价是失去了自动化的升级安全性检查。开发者在使
    用此库时必须极其谨慎，并进行彻底的手动验证，以防止存储冲突。它是一个为那些理解底层 EVM 存储模型并准备手动管理风险的专家提供的工具。
 * _自 v5.1 起可用。_
 * 
 * SlotDerivation 用于计算存储槽地址，而 StorageSlot 用于读写这些地址。
 */
library SlotDerivation {
    /**
     * @dev 从字符串（命名空间）派生 ERC-7201 槽。
     */
    function erc7201Slot(string memory namespace) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            mstore(0x00, sub(keccak256(add(namespace, 0x20), mload(namespace)), 1))
            slot := and(keccak256(0x00, 0x20), not(0xff))
            /**
             * namespace: 这是一个指向内存中字符串的指针。在 Solidity 中，string 类型在内存中的存储方式是：前 32 字节（0x20）存储字符串的长度，后面跟着字符串的实际内容。
             * mload(namespace):这会加载 namespace 指针指向的内存位置的数据，也就是字符串的长度。
             * add(namespace, 0x20): 这将 namespace 指针加上 32 字节（0x20），使其指向字符串实际内容的起始位置。
             * keccak256(...) 计算hash值,参数是(数据起始位置,数据长度)
             * sub(keccak256(...), 1): 这会将计算出的哈希值减去 1。这是为了进一步混淆和确保生成的槽位地址的唯一性和随机性。确保了结果不会是 0
             * mstore(0x00, ...): 将上一步计算出的最终结果（哈希值减 1）存入内存的 0x00 位置。这步是为下一步的哈希计算做准备。
             * 
             * keccak256(0x00, 0x20): 再次计算哈希。
             * not(0xff): 这是位操作。0xff 在 256 位中表示为 0x00...00ff。not(0xff) 的作用是将所有位取反，变为 0xff...ff00。
             * and(..., not(0xff)): 这一步是为了确保生成的槽位地址的最后一个字节为 0。这是因为 ERC-7201 的规范要求槽位地址的最后一个字节必须为 0。
             *      在以太坊存储中，数组和 mapping 类型的值会从一个基础槽位（由哈希值确定）开始，并根据索引或键值向后偏移。将最低字节置为 0，可以为这些值提供一个可用的“基础槽位”，确保其子项（如 mapping 的值）存储在正确的地址，并避免与其他变量的存储位置重叠。
             */
        }
    }

    /**
     * @dev 向槽添加偏移量以获取结构体或数组的第 n 个元素。
     * 返回的也是一个存储槽的地址
     */
    function offset(bytes32 slot, uint256 pos) internal pure returns (bytes32 result) {
        unchecked {
            return bytes32(uint256(slot) + pos);
        }
    }

    /**
     * @dev 从存储长度的槽派生数组中第一个元素的位置。
     * slot是动态数组变量本身在存储中声明的位置
     * 
     * 当你在 Solidity 合约中声明一个动态数组（例如 uint256[] public myArray;）时，这个数组变量本身所占据的存储槽（我们称之为P）并不直接存储数组的元素。相反，槽 P 存储的是这个动态数组的长度。
     * 数组的实际元素是从另一个存储槽开始存储的，这个槽的地址是通过对 P 进行 keccak256 哈希计算得出的。
     * 所以，myArray[0] 的存储槽地址是 keccak256(P)。
     * myArray[1] 的存储槽地址是 keccak256(P) + 1。
     */
    function deriveArray(bytes32 slot) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, slot)
            result := keccak256(0x00, 0x20)
        }
    }

    /**
     * @dev 从键派生映射元素的位置。
     */
    function deriveMapping(bytes32 slot, address key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // Solidity 映射的存储规则：keccak256(key || slot)
            // 键（key）会被填充到 32 字节，然后与 32 字节的槽（slot）进行拼接。
            // 这个 64 字节（key || slot）组合的哈希值就是存储位置。

            // mstore(0x00, and(key, shr(96, not(0))))
            // 准备用于哈希的键。
            // 'key' 是一个地址（20 字节）。它需要被填充到 32 字节。
            // 'shr(96, not(0))' 创建一个掩码：0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            // 这个掩码有效地将 32 字节字的前 12 字节（96 位）清零。
            // 'and(key, ...)' 确保地址 'key' 被放置在 32 字节字的低 20 字节，
            // 而高 12 字节被清零。这是 Solidity 填充地址以进行哈希的方式。
            mstore(0x00, and(key, shr(96, not(0)))) // 将填充后的键存储在内存地址 0x00

            // mstore(0x20, slot)
            // 将 'slot'（映射变量本身的基槽）紧接着键存储在内存中。
            // 内存地址 0x20 紧跟在 0x00 之后（因为 0x00 存储了 32 字节）。
            mstore(0x20, slot) // 将映射的基槽存储在内存地址 0x20

            // result := keccak256(0x00, 0x40)
            // 计算拼接后的键和槽的 keccak256 哈希。
            // 要哈希的数据从内存地址 0x00 开始，长度为 0x40（64 字节）。
            // 这 64 字节由 32 字节的填充键和 32 字节的槽组成。
            result := keccak256(0x00, 0x40) // 哈希 64 字节 (key || slot)
        }
    }

    /**
     * @dev 从键派生映射元素的位置。
     * key 是一个布尔值。
     * 注意：布尔值在 Solidity 中通常表示为 false 为 0，true 为 1。
     * 在 Solidity 中，布尔值通常被填充到 32 字节（0x00...00 或 0x00...01）。
     * 这个函数确保布尔值被正确填充到 32 字节以进行哈希。 
     */
    function deriveMapping(bytes32 slot, bool key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // Solidity 映射的存储规则：keccak256(key || slot)
            // 键（key）会被填充到 32 字节，然后与 32 字节的槽（slot）进行拼接。
            // 这个 64 字节（key || slot）组合的哈希值就是存储位置。

            // mstore(0x00, iszero(iszero(key)))
            // 准备布尔键以进行哈希。
            // 'key' 是一个布尔值。在 Solidity 中，布尔值通常表示为 false 为 0，true 为 1。
            // 'iszero(key)' 返回 a == 0。
            // 'iszero(iszero(key))' 有效地将任何非零值转换为 1，将 0 转换为 0。
            // 这确保布尔值被正确填充到 32 字节（0x00...00 或 0x00...01）以进行哈希。
            mstore(0x00, iszero(iszero(key))) // 将填充后的布尔键（0 或 1）存储在内存地址 0x00

            // mstore(0x20, slot)
            // 将 'slot'（映射变量本身的基槽）紧接着键存储在内存中。
            // 内存地址 0x20 紧跟在 0x00 之后（因为 0x00 存储了 32 字节）。
            mstore(0x20, slot) // 将映射的基槽存储在内存地址 0x20

            // result := keccak256(0x00, 0x40)
            // 计算拼接后的键和槽的 keccak256 哈希。
            // 要哈希的数据从内存地址 0x00 开始，长度为 0x40（64 字节）。
            // 这 64 字节由 32 字节的填充键和 32 字节的槽组成。
            result := keccak256(0x00, 0x40) // 哈希 64 字节 (key || slot)
        }
    }

    /**
     * @dev 从键派生映射元素的位置。
     * key 是一个字节数组。
     */
    function deriveMapping(bytes32 slot, bytes32 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev 从键派生映射元素的位置。
     */
    function deriveMapping(bytes32 slot, uint256 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev 从键派生映射元素的位置。
     */
    function deriveMapping(bytes32 slot, int256 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev 从键派生映射元素的位置。
     */
    function deriveMapping(bytes32 slot, string memory key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // let length := mload(key)
            // 加载字符串的长度。内存中字符串的前 32 字节存储其长度。
            let length := mload(key)

            // let begin := add(key, 0x20)
            // 计算实际字符串数据开始的内存地址（在 32 字节长度前缀之后）。
            let begin := add(key, 0x20)

            // let end := add(begin, length)
            // 计算字符串数据结束后的内存地址。
            let end := add(begin, length)

            // let cache := mload(end)
            // 临时存储 'end' 内存地址处的值。这是内存安全的关键步骤。
            // 我们即将把 'slot' 值写入 'end'，这可能会覆盖现有数据。
            // 这个 'cache' 允许我们在哈希操作后恢复 'end' 的原始内容。
            let cache := mload(end)

            // mstore(end, slot)
            // 将 'slot'（映射变量的基槽）紧接着字符串数据存储在内存中。
            // 这有效地将字符串数据与映射的基槽在内存中拼接起来。
            mstore(end, slot)

            // result := keccak256(begin, add(length, 0x20))
            // 计算拼接后的字符串数据和映射基槽的 keccak256 哈希。
            // 要哈希的数据从 'begin'（字符串数据）开始，总长度为 'length + 0x20'（字符串数据 + 32 字节的槽）。
            result := keccak256(begin, add(length, 0x20))

            // mstore(end, cache)
            // 恢复 'end' 内存地址的原始内容。这对于防止副作用和确保操作后内存保持原始状态很重要。
            mstore(end, cache)
        }
    }

    /**
     * @dev 从键派生映射元素的位置。
     * 
     * string 和 bytes 在 Solidity 中都被视为动态大小的字节数组。它们在内存中的存储结构遵循以下模式：
     *1. 前 32 字节（偏移量 0x00）：
     * 这个 32 字节的字存储的是数组的长度（以字节为单位）。
     *2. 随后的字节（偏移量 0x20 开始）：
     * 紧接着长度字之后，存储的是 string 或 bytes 的实际数据。数据会从 0x20 偏移量开始，并根据需要进行填充，直到下一个 32 字节的边界。
     */
    function deriveMapping(bytes32 slot, bytes memory key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let length := mload(key)
            let begin := add(key, 0x20)
            let end := add(begin, length)
            let cache := mload(end)
            mstore(end, slot)
            result := keccak256(begin, add(length, 0x20))
            mstore(end, cache)
        }
    }
}
