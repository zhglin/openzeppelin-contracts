// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/ShortStrings.sol)

pragma solidity ^0.8.20;

import {StorageSlot} from "./StorageSlot.sol";

// | 字符串 | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA |
// | 长度 | 0x                                                              BB |
type ShortString is bytes32;

/**
 * @dev 此库提供将短内存字符串转换为 `ShortString` 类型的功能，该类型可用作不可变变量。
 * 此外，对于所有其他情况，可以使用回退机制。
 *
 * 用于把“短字符串”紧凑编码进单个 bytes32 的工具库，并配合可选回退存储（fallback）解决“字符串不能做 immutable”的问题，从而降低读写开销、减小存储占用。
 * 任意长度的字符串如果足够短（最多 31 字节），可以通过将它们与长度（1 字节）打包到单个 EVM 字（32 字节）中来优化。
 *
 * Solidity 的 immutable 只支持值类型（最多 32 字节），string/动态 bytes 这种引用类型不允许做 immutable。
 * 因此像 token 的 name、symbol 这类部署后不再变化的元数据，没法直接写成 immutable string。
 *
 * immutable 变量：它们的值是在合约部署时（也就是构造函数执行时）才确定的。因此，它们的值无法在编译时被嵌入到字节码中。
 * 为了在部署后能被访问，immutable 变量的值被存储在合约的部署字节码中。
 * 当你调用一个读取 immutable 变量的函数时，EVM 必须从合约的代码部分加载这个值，加载 immutable 变量就是执行一个 PUSH 指令。
 * 编译阶段:
 *      编译器生成 creation code：里面有占位符（比如一段 00..00）代表 FEE 的位置。
 *      构造函数执行完后，编译器在返回 runtime code 前，把实际的 fee 值写进那个占位符。
 *      最终部署到链上的 runtime code 里，就包含了这个常量（例如 0x… PUSH32 <fee>）。
 * 运行时代码如何读取:
 *      EVM 运行 runtime code；
 *      到达访问 immutable 的地方时，字节码里已经是一个 PUSHn 指令，直接把 <fee> 压到栈上；
 *      然后把它 RETURN 出去
 *
 * 使用示例：
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *
 *     // 不使用 fallback：合约部署时没有 SSTORE，槽里是零，运行时访问也不会读到这里 → 几乎没有运行开销
 *     // 仅声明（预留槽位）在部署时会产生一次性的隐式成本。 这个成本是合约创建总 Gas 的一部分。
 *     // 首次显式地将数据存储到该槽位（从零到非零）会产生显著的 `SSTORE` Gas 成本（20,000 Gas）。
 *     // 后续 `sstore`（修改现有槽）：如果一个槽已经包含非零值，并且您写入一个新的非零值，成本会降低（目前为 5,000 Gas）。
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */
library ShortStrings {
    // 用作长度超过 31 字节的字符串的标识符。
    bytes32 private constant FALLBACK_SENTINEL = 0x00000000000000000000000000000000000000000000000000000000000000FF;

    error StringTooLong(string str);
    error InvalidShortString();

    /**
     * Solidity 的 string 类型是 UTF-8 编码的。这一点至关重要，因为在 UTF-8 中，一个“字符”（或字素簇）可以由一个或多个字节表示。
     * 例如，'a' 是 1 个字节，'é' 是 2 个字节，而某些表情符号可能需要 4 个或更多字节。
     * 您可以使用 bytes(myString).length 获取字符串的字节长度，但这只是字节数，而不是字符数。
     *
     * string类型只支持赋值(=), 比较(==), 拼接(`abi.encodePacked` 或 `string.concat`)
     */

    /**
     * @dev 将最多 31 个字符的字符串编码为 `ShortString`。
     * 如果输入字符串太长，这将触发 `StringTooLong` 错误。
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        // 转换字符串为字节数组
        bytes memory bstr = bytes(str);
        // 如果字符串长度超过 31 字节，抛出错误。
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        // 高 248 位存储字符串内容（最多 31 字节）。低 8 位存储字符串长度。
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev 将 `ShortString` 解码回“普通”字符串。
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        // 使用 `new string(len)` 在本地有效，但不是内存安全的。因为它可能导致内存对齐问题或覆盖相邻内存。
        // 字符串自身分配的 32 字节数据块内部的填充字节被 sstr 的填充内容（可能包含意外值，如 sstr的长度字节）覆盖。这使得字符串的内部表示“不干净”，

        // memory 中的 string 和 bytes 类型通常表示为：一个 32 字节的字，包含数据的长度。紧随其后的是实际数据（并填充到 32 字节的倍数）。

        // 32 指的是为字符串内容分配的字节数。
        // 分配一个 `string` 对象的内存。
        // 这个 string 对象将包含一个长度前缀（它本身总是 32 字节，用于存储字符串的实际字节长度）。然后，它将有空间容纳32 字节的实际字符串数据。
        string memory str = new string(32);
        assembly ("memory-safe") {
            mstore(str, len)
            // 将整个 32 字节的 sstr 值写入从 add(str, 0x20) 开始的内存中。
            // 由于 sstr在其高位字节中包含字符串数据，这有效地将字符串数据复制到 str 对象的正确位置。
            // sstr的最后一个字节（存储长度）也会被写入，但它不会影响字符串的内容，因为长度已经由 mstore(str, len) 设置
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }

    /**
     * @dev 返回 `ShortString` 的长度。
     * ShortString` 本质上是 `bytes32` 类型,理论上，你可以直接创建一个 bytes32 值，它的最后一个字节（被解释为长度时）可能大于 31。
     * 要判断是否符合stortStrings的规范，必须检查最后一个字节是否小于等于 31。
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }

    /**
     * @dev 将字符串编码为 `ShortString`，如果太长则写入存储。
     */
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            // 超过32字节的标识符
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }

    /**
     * @dev 解码使用 {toShortStringWithFallback} 编码为 `ShortString` 或写入存储的字符串。
     */
    function toStringWithFallback(ShortString value, string storage store) internal pure returns (string memory) {
        // 是否超过32字节
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @dev 返回使用 {toShortStringWithFallback} 编码为 `ShortString` 或写入存储的字符串的长度。
     * 警告：这将返回字符串的“字节长度”。这可能无法反映实际字符的实际长度，因为单个字符的 UTF-8 编码可能跨越多个字节。
     */
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}
