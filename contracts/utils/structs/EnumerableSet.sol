// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/structs/EnumerableSet.sol)
// 此文件是根据 scripts/generate/templates/EnumerableSet.js 程序生成的。

pragma solidity ^0.8.20;

import {Arrays} from "../Arrays.sol";
import {Math} from "../math/Math.sol";

/**
 * @dev 用于管理原始类型
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[集] 的库。
 *
 * 集具有以下属性：
 *
 * - 元素的添加、删除和存在性检查的时间复杂度为常量时间 (O(1))。
 * - 元素的枚举时间复杂度为 O(n)。不保证排序。
 * - 可以 O(n) 的时间复杂度清除集（删除所有元素）。
 *
 * ```solidity
 * contract Example {
 *     // 添加库方法
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // 声明一个集状态变量
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * 支持以下类型：
 *
 * - `bytes32` (`Bytes32Set`) since v3.3.0
 * - `address` (`AddressSet`) since v3.3.0
 * - `uint256` (`UintSet`) since v3.3.0
 * - `string` (`StringSet`) since v5.4.0
 * - `bytes` (`BytesSet`) since v5.4.0
 *
 * [警告]
 * ====
 * 尝试从存储中删除此类结构可能会导致数据损坏，使结构无法使用。
 * 有关更多信息，请参阅 https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843]。
 * 直接对 `EnumerableSet` 这种复杂的数据结构使用 `delete`关键字，会破坏它的内部数据一致性，导致它彻底无法再正常工作。
 * 首先，我们得看 EnumerableSet 是如何组成的。它内部主要由两部分构成：
 *  1. 一个 数组（Array）：用来存储集合中的所有元素，这样我们就可以遍历它们（“Enumerable”这个词的来源）。
 *  2. 一个 映射（Mapping）：用来记录每个元素是否存在，以及它在数组中的位置。这使得添加、删除和检查元素存在的操作非常快（O(1) 复杂度）。
 * Solidity 的 delete 关键字如何工作？
 *  对于简单类型（如 uint, address），delete 会将其重置为默认值（0 或 address(0)）。
 *  对于 数组，delete 会删除所有元素，使其长度变为 0。
 *  对于 映射（Mapping），delete 什么也不做！Solidity 的设计无法遍历一个映射的所有键并删除它们，所以 delete对映射无效，里面的数据会原封不动地保留下来。
 * 所以delete mySet这时会发生以下情况：
 *  delete 会作用于 EnumerableSet 内部的 数组，将其清空，长度变为 0。
 *  delete 不会 作用于内部的 映射，之前存储在映射里的所有“元素 -> 位置”的记录都还完好无损地留在那里。
 * 此时，数据损坏 就发生了：数组是空的，但映射“认为”里面还有很多元素，并且记录着它们已经不存在的位置。EnumerableSet的内部一致性被彻底破坏。
 * 为了清理 EnumerableSet，您可以逐个删除所有元素，或使用 EnumerableSet 数组创建一个新实例。
 * ====
 */
library EnumerableSet {
    // 为了以尽可能少的代码重复为多种类型实现此库，
    // 我们以具有 bytes32 值的通用 Set 类型来编写它。
    // Set 实现使用私有函数，面向用户的实现
    //（例如 AddressSet）只是底层 Set 的包装器。
    // 这意味着我们只能为适合 bytes32 的类型创建新的 EnumerableSet。

    struct Set {
        // 集合值的存储
        bytes32[] _values;
        // Position 是值在 `values` 数组中的索引加 1。
        // Position 0 用于表示值不在集合中。
        mapping(bytes32 value => uint256) _positions;
    }

    /**
     * @dev 向集合中添加一个值。O(1)。
     * 如果值已添加到集合中（即之前不存在），则返回 true。
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // 值存储在 length-1 处，但我们将所有索引加 1
            // 并使用 0 作为哨兵值
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev 从集合中删除一个值。O(1)。
     *
     * 如果值已从集合中删除（即之前存在），则返回 true。
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // 我们缓存值的位置以防止从同一存储槽进行多次读取
        uint256 position = set._positions[value];

        if (position != 0) {
            // 等效于 contains(set, value)
            // 要在 O(1) 内从 _values 数组中删除一个元素，我们将要删除的元素与
            // 数组中的最后一个元素交换，然后删除最后一个元素（有时称为“交换并弹出”）。
            // 正如 {at} 中所述，这会修改数组的顺序。

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // 将 lastValue 移动到要删除的值的索引处
                set._values[valueIndex] = lastValue;
                // 更新刚移动的 lastValue 的跟踪位置
                set._positions[lastValue] = position;
            }

            // 删除存储移动值的槽
            set._values.pop();

            // 删除已删除槽的跟踪位置
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev 从集合中删除所有值。O(n)。
     *
     * 警告：此函数具有与集合大小成比例的无界成本。开发人员应记住，
     * 如果集合增长到清除它消耗过多 gas 以致无法容纳在一个区块中的程度，
     * 使用它可能会使该函数无法调用。
     */
    function _clear(Set storage set) private {
        uint256 len = _length(set);
        for (uint256 i = 0; i < len; ++i) {
            delete set._positions[set._values[i]];
        }
        Arrays.unsafeSetLength(set._values, 0);
    }

    /**
     * @dev 如果值在集合中，则返回 true。O(1)。
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev 返回集合中的值的数量。O(1)。
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev 返回存储在集合中 `index` 位置的值。O(1)。
     * 请注意，不保证数组中值的顺序，添加或删除更多值时，顺序可能会更改。
     * 要求：
     * - `index` 必须严格小于 {length}。
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev 以数组形式返回整个集合
     * 警告：此操作会将整个存储复制到内存中，这可能非常昂贵。
     * 以太坊的每个区块都有一个总的 Gas 上限（Block Gas Limit）。任何一笔交易的总 Gas 消耗都不能超过这个上限。
     * 如果你的 EnumerableSet 不断增长，总有一天，调用 values() 函数所需要的 Gas 会 超过单个区块的 Gas 上限。
     * 一旦发生这种情况：
     *  任何 在链上交易中 尝试调用 values() 函数（或者调用了其他内部使用了 values() 的函数）的操作，都将 永远失败。
     *  因为没有任何一个区块能容纳下这笔交易所需要的 Gas，所以这个函数对于状态变更型交易来说，实际上已经变得永久无法调用。这可能会锁死合约的某些关键功能。
     * 
     * 链下查询（Off-chain Queries）：当你通过 Web3.js 或 Ethers.js 等工具从外部读取合约数据时，
     *  调用 view 或 pure 函数是不消耗 Gas的（因为它不产生交易，只是查询节点数据）。
     *  在这种情况下，使用 values() 是完全安全的，也是它被设计出来的主要目的。
     * 链上只读（On-chain View Calls）：在一个 view 函数中调用另一个 view 函数也是安全的。
     *  链上交易 (On-chain Transaction)  =>  写请求 (Write Request)
     *      一个“写请求”是任何试图 改变区块链状态的操作。它必须通过一笔“交易”来完成，因为你需要网络中的所有节点都对这个状态变化达成共识，并将其永久记录下来。
     *      因为这些操作需要全网的共识和记录，所以它们必须作为交易被打包进区块，因此 需要消耗 Gas。
     *  链下调用 (Off-chain Call)  =>  读请求 (Read Request)
     *      读操作不改变任何东西，所以任何一个单独的以太坊节点都可以直接查询自己的数据副本并告诉你结果，无需全网共识。因此，它们是免费的，并且通过 view 或 pure 函数来实现。
     * 绝对要避免的错误用法是：
     *  在一个会改变合约状态的函数（即需要发送交易的函数）中调用 values()。
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    /**
     * @dev 以数组形式返回集合的切片
     *
     * 警告：同_values(Set storage set)
     */
    function _values(Set storage set, uint256 start, uint256 end) private view returns (bytes32[] memory) {
        unchecked {
            end = Math.min(end, _length(set));
            start = Math.min(start, end);

            uint256 len = end - start;
            bytes32[] memory result = new bytes32[](len);
            for (uint256 i = 0; i < len; ++i) {
                result[i] = Arrays.unsafeAccess(set._values, start + i).value;
            }
            return result;
        }
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev 向集合中添加一个值。O(1)。
     *
     * 如果值已添加到集合中（即之前不存在），则返回 true。
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev 从集合中删除一个值。O(1)。
     *
     * 如果值已从集合中删除（即之前存在），则返回 true。
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev 从集合中删除所有值。O(n)。
     *
     * 警告：开发人员应记住，此函数具有无界成本，如果集合增长到
     * 清除它消耗过多 gas 以致无法容纳在一个区块中的程度，使用它可能会使该函数无法调用。
     */
    function clear(Bytes32Set storage set) internal {
        _clear(set._inner);
    }

    /**
     * @dev 如果值在集合中，则返回 true。O(1)。
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev 返回集合中的值的数量。O(1)。
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev 返回存储在集合中 `index` 位置的值。O(1)。
     *
     * 请注意，不保证数组中值的顺序，
     * 添加或删除更多值时，顺序可能会更改。
     *
     * 要求：
     *
     * - `index` 必须严格小于 {length}。
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    /**
     * @dev Return a slice of the set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner, start, end);
        bytes32[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes all the values from a set. O(n).
     *
     * WARNING: Developers should keep in mind that this function has an unbounded cost and using it may render the
     * function uncallable if the set grows to the point where clearing it consumes too much gas to fit in a block.
     */
    function clear(AddressSet storage set) internal {
        _clear(set._inner);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    /**
     * @dev Return a slice of the set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set, uint256 start, uint256 end) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner, start, end);
        address[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Removes all the values from a set. O(n).
     *
     * WARNING: Developers should keep in mind that this function has an unbounded cost and using it may render the
     * function uncallable if the set grows to the point where clearing it consumes too much gas to fit in a block.
     */
    function clear(UintSet storage set) internal {
        _clear(set._inner);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    /**
     * @dev Return a slice of the set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set, uint256 start, uint256 end) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner, start, end);
        uint256[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    struct StringSet {
        // Storage of set values
        string[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(string value => uint256) _positions;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(StringSet storage set, string memory value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(StringSet storage set, string memory value) internal returns (bool) {
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                string memory lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes all the values from a set. O(n).
     *
     * WARNING: Developers should keep in mind that this function has an unbounded cost and using it may render the
     * function uncallable if the set grows to the point where clearing it consumes too much gas to fit in a block.
     */
    function clear(StringSet storage set) internal {
        uint256 len = length(set);
        for (uint256 i = 0; i < len; ++i) {
            delete set._positions[set._values[i]];
        }
        Arrays.unsafeSetLength(set._values, 0);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(StringSet storage set, string memory value) internal view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(StringSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(StringSet storage set, uint256 index) internal view returns (string memory) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(StringSet storage set) internal view returns (string[] memory) {
        return set._values;
    }

    /**
     * @dev Return a slice of the set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(StringSet storage set, uint256 start, uint256 end) internal view returns (string[] memory) {
        unchecked {
            end = Math.min(end, length(set));
            start = Math.min(start, end);

            uint256 len = end - start;
            string[] memory result = new string[](len);
            for (uint256 i = 0; i < len; ++i) {
                result[i] = Arrays.unsafeAccess(set._values, start + i).value;
            }
            return result;
        }
    }

    struct BytesSet {
        // Storage of set values
        bytes[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes value => uint256) _positions;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(BytesSet storage set, bytes memory value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(BytesSet storage set, bytes memory value) internal returns (bool) {
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes memory lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes all the values from a set. O(n).
     *
     * WARNING: Developers should keep in mind that this function has an unbounded cost and using it may render the
     * function uncallable if the set grows to the point where clearing it consumes too much gas to fit in a block.
     */
    function clear(BytesSet storage set) internal {
        uint256 len = length(set);
        for (uint256 i = 0; i < len; ++i) {
            delete set._positions[set._values[i]];
        }
        Arrays.unsafeSetLength(set._values, 0);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(BytesSet storage set, bytes memory value) internal view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(BytesSet storage set) internal view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(BytesSet storage set, uint256 index) internal view returns (bytes memory) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(BytesSet storage set) internal view returns (bytes[] memory) {
        return set._values;
    }

    /**
     * @dev Return a slice of the set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(BytesSet storage set, uint256 start, uint256 end) internal view returns (bytes[] memory) {
        unchecked {
            end = Math.min(end, length(set));
            start = Math.min(start, end);

            uint256 len = end - start;
            bytes[] memory result = new bytes[](len);
            for (uint256 i = 0; i < len; ++i) {
                result[i] = Arrays.unsafeAccess(set._values, start + i).value;
            }
            return result;
        }
    }
}