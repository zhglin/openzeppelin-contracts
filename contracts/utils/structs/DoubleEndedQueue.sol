// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/structs/DoubleEndedQueue.sol)
pragma solidity ^0.8.20;

import {Panic} from "../Panic.sol";

/**
 * @dev 一个可以在序列两端（称为前端和后端）高效地推入和弹出项目（即插入和移除）的序列。
 * 除了其他访问模式外，它还可以用于实现高效的后进先出（LIFO）和先进先出（FIFO）队列。
 * 存储使用经过优化，所有操作都是 O(1) 常数时间。这也包括 {clear}，因为现有的队列内容会留在存储中。
 *
 * 该结构体名为 `Bytes32Deque`。其他类型可以与 `bytes32`相互转换。此数据结构只能在存储中使用，不能在内存中使用。
 * ```solidity
 * DoubleEndedQueue.Bytes32Deque queue;
 * ```
 */
library DoubleEndedQueue {
    /**
     * @dev 索引是 128 位，因此 begin 和 end 被打包在单个存储槽中以实现高效访问。
     *
     * 结构体成员带有下划线前缀，表示它们是“私有的”，不应直接读取或写入。
     * 请改用下面提供的函数。手动修改结构体可能会违反假设并导致意外行为。
     *
     * 第一个项目位于 data[begin]，最后一个项目位于 data[end - 1]。这个范围可以环绕。
     */

    // 由于 uint128 是一个环形的空间（当一个数减到 0 以下时，它会从 2**128 - 1 开始；当加到最大值以上时，它会绕回 0），
    // _end 指针和 _start 指针最终有可能“相遇”。
    struct Bytes32Deque {
        uint128 _begin;
        uint128 _end;
        mapping(uint128 index => bytes32) _data;
    }

    /**
     * @dev 在队列末尾插入一个项目。
     *
     * 如果队列已满，则以 {Panic-RESOURCE_ERROR} revert。
     */
    function pushBack(Bytes32Deque storage deque, bytes32 value) internal {
        unchecked {
            uint128 backIndex = deque._end;
            // 
            if (backIndex + 1 == deque._begin) Panic.panic(Panic.RESOURCE_ERROR);
            deque._data[backIndex] = value;
            deque._end = backIndex + 1;
        }
    }

    /**
     * @dev 移除队列末尾的项目并返回它。
     *
     * 如果队列为空，则以 {Panic-EMPTY_ARRAY_POP} revert。
     */
    function popBack(Bytes32Deque storage deque) internal returns (bytes32 value) {
        unchecked {
            uint128 backIndex = deque._end;
            if (backIndex == deque._begin) Panic.panic(Panic.EMPTY_ARRAY_POP);
            --backIndex;
            value = deque._data[backIndex];
            delete deque._data[backIndex];
            deque._end = backIndex;
        }
    }

    /**
     * @dev 在队列开头插入一个项目。
     *
     * 如果队列已满，则以 {Panic-RESOURCE_ERROR} revert。
     */
    function pushFront(Bytes32Deque storage deque, bytes32 value) internal {
        unchecked {
            // 执行 _begin = _begin - 1。由于下溢，_begin 变成了 type(uint256).max。
            // pushFront 操作让队列在 uint128 的巨大地址空间里“向后”生长，
            uint128 frontIndex = deque._begin - 1;
            if (frontIndex == deque._end) Panic.panic(Panic.RESOURCE_ERROR);
            deque._data[frontIndex] = value;
            deque._begin = frontIndex;
        }
    }

    /**
     * @dev 移除队列开头的项目并返回它。
     *
     * 如果队列为空，则以 {Panic-EMPTY_ARRAY_POP} revert。
     */
    function popFront(Bytes32Deque storage deque) internal returns (bytes32 value) {
        unchecked {
            uint128 frontIndex = deque._begin;
            if (frontIndex == deque._end) Panic.panic(Panic.EMPTY_ARRAY_POP);
            value = deque._data[frontIndex];
            delete deque._data[frontIndex];
            deque._begin = frontIndex + 1;
        }
    }

    /**
     * @dev 返回队列开头的项目。
     *
     * 如果队列为空，则以 {Panic-ARRAY_OUT_OF_BOUNDS} revert。
     */
    function front(Bytes32Deque storage deque) internal view returns (bytes32 value) {
        if (empty(deque)) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        return deque._data[deque._begin];
    }

    /**
     * @dev 返回队列末尾的项目。
     *
     * 如果队列为空，则以 {Panic-ARRAY_OUT_OF_BOUNDS} revert。
     */
    function back(Bytes32Deque storage deque) internal view returns (bytes32 value) {
        if (empty(deque)) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        unchecked {
            return deque._data[deque._end - 1];
        }
    }

    /**
     * @dev 返回队列中由 `index` 给定位置的项目，第一个项目位于 0，最后一个项目位于 `length(deque) - 1`。
     *
     * 如果索引越界，则以 {Panic-ARRAY_OUT_OF_BOUNDS} revert。
     */
    function at(Bytes32Deque storage deque, uint256 index) internal view returns (bytes32 value) {
        if (index >= length(deque)) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        // 根据设计，length 是一个 uint128，所以上面的检查确保了 index 可以安全地向下转换为 uint128
        unchecked {
            return deque._data[deque._begin + uint128(index)];
        }
    }

    /**
     * @dev 将队列重置为空。
     *
     * 注意：当前的项目会留在存储中。这不影响队列的功能，但会错失潜在的 Gas 退款。
     */
    function clear(Bytes32Deque storage deque) internal {
        deque._begin = 0;
        deque._end = 0;
    }

    /**
     * @dev 返回队列中的项目数量。
     */
    function length(Bytes32Deque storage deque) internal view returns (uint256) {
        unchecked {
            return uint256(deque._end - deque._begin);
        }
    }

    /**
     * @dev 如果队列为空，则返回 true。
     */
    function empty(Bytes32Deque storage deque) internal view returns (bool) {
        return deque._end == deque._begin;
    }
}
