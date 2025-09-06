// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/structs/Checkpoints.sol)
// This file was procedurally generated from scripts/generate/templates/Checkpoints.js.

pragma solidity ^0.8.20;

import {Math} from "../math/Math.sol";

/**
 * @dev 这个库定义了 `Trace*` 结构体，用于在不同时间点为变化的值创建检查点，
 * 并在之后通过区块号查找过去的值。可以参考 {Votes} 合约作为例子。
 *
 * 要创建一个检查点的历史记录，请在你的合约中定义一个 `Checkpoints.Trace*` 类型的变量，
 * 并使用 {push} 函数为当前交易区块存储一个新的检查点。
 * 
 * 高效地存储和查询某个数值的“历史快照”。
 * 简单来说，它能帮你回答这样一个问题：“在过去的某个时间点（比如某个区块高度），某个值是多少？”
 */
library Checkpoints {
    /**
     * @dev 尝试在过去的检查点上插入一个值。
     */
    error CheckpointUnorderedInsertion();

    struct Trace256 {
        Checkpoint256[] _checkpoints;
    }

    struct Checkpoint256 {
        uint256 _key;
        uint256 _value;
    }

    /**
     * @dev 将一个 (`key`, `value`) 对推入到一个 Trace256 中，以将其存储为检查点。
     * 返回旧值和新值。
     * 重要提示：永远不要接受用户输入的 `key`，因为一个任意设置的 `type(uint256).max` 的 key 将会禁用此库。
     */
    function push(
        Trace256 storage self,
        uint256 key,
        uint256 value
    ) internal returns (uint256 oldValue, uint256 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @dev 返回第一个（最旧的）key 大于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     */
    function lowerLookup(Trace256 storage self, uint256 key) internal view returns (uint256) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        return pos == len ? 0 : _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @dev 返回最后一个（最新的）key 小于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     */
    function upperLookup(Trace256 storage self, uint256 key) internal view returns (uint256) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回最后一个（最新的）key 小于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     * 注意：这是 {upperLookup} 的一个变体，经过优化以查找“最近的”检查点（即具有较大 key 的检查点）。
     */
    function upperLookupRecent(Trace256 storage self, uint256 key) internal view returns (uint256) {
        uint256 len = self._checkpoints.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - Math.sqrt(len);
            if (key < _unsafeAccess(self._checkpoints, mid)._key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);

        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回最新检查点中的值，如果没有检查点则返回零。
     */
    function latest(Trace256 storage self) internal view returns (uint256) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回结构体中是否存在检查点（即它不为空），如果存在，则返回最新检查点的 key 和 value。
     */
    function latestCheckpoint(Trace256 storage self) internal view returns (bool exists, uint256 _key, uint256 _value) {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, 0);
        } else {
            Checkpoint256 storage ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt._key, ckpt._value);
        }
    }

    /**
     * @dev 返回检查点的数量。
     */
    function length(Trace256 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @dev 返回给定位置的检查点。
     */
    function at(Trace256 storage self, uint32 pos) internal view returns (Checkpoint256 memory) {
        return self._checkpoints[pos];
    }

    /**
     * @dev 将一个 (`key`, `value`) 对推入到一个有序的检查点列表中，可以通过插入新检查点，
     * 或者更新最后一个检查点来完成。
     */
    function _insert(
        Checkpoint256[] storage self,
        uint256 key,
        uint256 value
    ) private returns (uint256 oldValue, uint256 newValue) {
        uint256 pos = self.length;

        if (pos > 0) {
            Checkpoint256 storage last = _unsafeAccess(self, pos - 1);
            uint256 lastKey = last._key;
            uint256 lastValue = last._value;

            // 检查点的 key 必须是非递减的。
            if (lastKey > key) {
                revert CheckpointUnorderedInsertion();
            }

            // 更新或推入新的检查点
            if (lastKey == key) {
                last._value = value;
            } else {
                self.push(Checkpoint256({_key: key, _value: value}));
            }
            return (lastValue, value);
        } else {
            self.push(Checkpoint256({_key: key, _value: value}));
            return (0, value);
        }
    }

    /**
     * @dev 返回第一个（最旧的）key 严格大于搜索 key 的检查点的索引，如果不存在则返回 `high`。
     * `low` 和 `high` 定义了搜索的区间，其中 `low` 是包含的，`high` 是不包含的。
     *
     * 警告：`high` 不应大于数组的长度。
     */
    function _upperBinaryLookup(
        Checkpoint256[] storage self,
        uint256 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev 返回第一个（最旧的）key 大于或等于搜索 key 的检查点的索引，如果不存在则返回 `high`。
     * `low` 和 `high` 定义了搜索的区间，其中 `low` 是包含的，`high` 是不包含的。
     * 警告：`high` 不应大于数组的长度。
     * 二分查找
     */
    function _lowerBinaryLookup(
        Checkpoint256[] storage self,
        uint256 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev 访问数组的一个元素而不执行边界检查。假定位置在边界之内。
     *   1. 节省 Gas：绕过数组边界检查
     *      在标准的 Solidity 代码中，当你访问一个数组元素时，比如 myArray[i]，编译器为了安全，会自动插入一段检查代码，来判断 i 是否小于myArray.length。
     *      这个“边界检查”可以防止你访问到无效的内存区域，从而避免错误和潜在的攻击。
     */
    function _unsafeAccess(
        Checkpoint256[] storage self,
        uint256 pos
    ) private pure returns (Checkpoint256 storage result) {
        assembly {
            mstore(0, self.slot)
            // 因为 Checkpoint256 结构体包含两个 uint256 成员（_key 和 _value），所以每个元素占据 2 个存储槽。
            // 因此第 pos个元素的偏移量就是 pos * 2。（对于其他 Trace 版本，如果 _key 和 _value 可以被打包进一个槽，那么偏移量就是 pos）。
            result.slot := add(keccak256(0, 0x20), mul(pos, 2))
        }
    }

    struct Trace224 {
        Checkpoint224[] _checkpoints;
    }

    struct Checkpoint224 {
        uint32 _key;
        uint224 _value;
    }

    /**
     * @dev 将一个 (`key`, `value`) 对推入到一个 Trace224 中，以将其存储为检查点。
     *
     * 返回旧值和新值。
     *
     * 重要提示：永远不要接受用户输入的 `key`，因为一个任意设置的 `type(uint32).max` 的 key 将会禁用此库。
     */
    function push(
        Trace224 storage self,
        uint32 key,
        uint224 value
    ) internal returns (uint224 oldValue, uint224 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @dev 返回第一个（最旧的）key 大于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     */
    function lowerLookup(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        return pos == len ? 0 : _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @dev 返回最后一个（最新的）key 小于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     */
    function upperLookup(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回最后一个（最新的）key 小于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     *
     * 注意：这是 {upperLookup} 的一个变体，经过优化以查找“最近的”检查点（即具有较大 key 的检查点）。
     */
    function upperLookupRecent(Trace224 storage self, uint32 key) internal view returns (uint224) {
        uint256 len = self._checkpoints.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - Math.sqrt(len);
            if (key < _unsafeAccess(self._checkpoints, mid)._key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);

        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回最新检查点中的值，如果没有检查点则返回零。
     */
    function latest(Trace224 storage self) internal view returns (uint224) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回结构体中是否存在检查点（即它不为空），如果存在，则返回最新检查点的 key 和 value。
     */
    function latestCheckpoint(Trace224 storage self) internal view returns (bool exists, uint32 _key, uint224 _value) {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, 0);
        } else {
            Checkpoint224 storage ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt._key, ckpt._value);
        }
    }

    /**
     * @dev 返回检查点的数量。
     */
    function length(Trace224 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @dev 返回给定位置的检查点。
     */
    function at(Trace224 storage self, uint32 pos) internal view returns (Checkpoint224 memory) {
        return self._checkpoints[pos];
    }

    /**
     * @dev 将一个 (`key`, `value`) 对推入到一个有序的检查点列表中，可以通过插入新检查点，
     * 或者更新最后一个检查点来完成。
     */
    function _insert(
        Checkpoint224[] storage self,
        uint32 key,
        uint224 value
    ) private returns (uint224 oldValue, uint224 newValue) {
        uint256 pos = self.length;

        if (pos > 0) {
            Checkpoint224 storage last = _unsafeAccess(self, pos - 1);
            uint32 lastKey = last._key;
            uint224 lastValue = last._value;

            // 检查点的 key 必须是非递减的。
            if (lastKey > key) {
                revert CheckpointUnorderedInsertion();
            }

            // 更新或推入新的检查点
            if (lastKey == key) {
                last._value = value;
            } else {
                self.push(Checkpoint224({_key: key, _value: value}));
            }
            return (lastValue, value);
        } else {
            self.push(Checkpoint224({_key: key, _value: value}));
            return (0, value);
        }
    }

    /**
     * @dev 返回第一个（最旧的）key 严格大于搜索 key 的检查点的索引，如果不存在则返回 `high`。
     * `low` 和 `high` 定义了搜索的区间，其中 `low` 是包含的，`high` 是不包含的。
     *
     * 警告：`high` 不应大于数组的长度。
     */
    function _upperBinaryLookup(
        Checkpoint224[] storage self,
        uint32 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev 返回第一个（最旧的）key 大于或等于搜索 key 的检查点的索引，如果不存在则返回 `high`。
     * `low` 和 `high` 定义了搜索的区间，其中 `low` 是包含的，`high` 是不包含的。
     *
     * 警告：`high` 不应大于数组的长度。
     */
    function _lowerBinaryLookup(
        Checkpoint224[] storage self,
        uint32 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev 访问数组的一个元素而不执行边界检查。假定位置在边界之内。
     */
    function _unsafeAccess(
        Checkpoint224[] storage self,
        uint256 pos
    ) private pure returns (Checkpoint224 storage result) {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    struct Trace208 {
        Checkpoint208[] _checkpoints;
    }

    struct Checkpoint208 {
        uint48 _key;
        uint208 _value;
    }

    /**
     * @dev 将一个 (`key`, `value`) 对推入到一个 Trace208 中，以将其存储为检查点。
     *
     * 返回旧值和新值。
     *
     * 重要提示：永远不要接受用户输入的 `key`，因为一个任意设置的 `type(uint48).max` 的 key 将会禁用此库。
     */
    function push(
        Trace208 storage self,
        uint48 key,
        uint208 value
    ) internal returns (uint208 oldValue, uint208 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @dev 返回第一个（最旧的）key 大于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     */
    function lowerLookup(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        return pos == len ? 0 : _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @dev 返回最后一个（最新的）key 小于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     */
    function upperLookup(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回最后一个（最新的）key 小于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     *
     * 注意：这是 {upperLookup} 的一个变体，经过优化以查找“最近的”检查点（即具有较大 key 的检查点）。
     */
    function upperLookupRecent(Trace208 storage self, uint48 key) internal view returns (uint208) {
        uint256 len = self._checkpoints.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - Math.sqrt(len);
            if (key < _unsafeAccess(self._checkpoints, mid)._key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);

        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回最新检查点中的值，如果没有检查点则返回零。
     */
    function latest(Trace208 storage self) internal view returns (uint208) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回结构体中是否存在检查点（即它不为空），如果存在，则返回最新检查点的 key 和 value。
     */
    function latestCheckpoint(Trace208 storage self) internal view returns (bool exists, uint48 _key, uint208 _value) {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, 0);
        } else {
            Checkpoint208 storage ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt._key, ckpt._value);
        }
    }

    /**
     * @dev 返回检查点的数量。
     */
    function length(Trace208 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @dev 返回给定位置的检查点。
     */
    function at(Trace208 storage self, uint32 pos) internal view returns (Checkpoint208 memory) {
        return self._checkpoints[pos];
    }

    /**
     * @dev 将一个 (`key`, `value`) 对推入到一个有序的检查点列表中，可以通过插入新检查点，
     * 或者更新最后一个检查点来完成。
     */
    function _insert(
        Checkpoint208[] storage self,
        uint48 key,
        uint208 value
    ) private returns (uint208 oldValue, uint208 newValue) {
        uint256 pos = self.length;

        if (pos > 0) {
            Checkpoint208 storage last = _unsafeAccess(self, pos - 1);
            uint48 lastKey = last._key;
            uint208 lastValue = last._value;

            // 检查点的 key 必须是非递减的。
            if (lastKey > key) {
                revert CheckpointUnorderedInsertion();
            }

            // 更新或推入新的检查点
            if (lastKey == key) {
                last._value = value;
            } else {
                self.push(Checkpoint208({_key: key, _value: value}));
            }
            return (lastValue, value);
        } else {
            self.push(Checkpoint208({_key: key, _value: value}));
            return (0, value);
        }
    }

    /**
     * @dev 返回第一个（最旧的）key 严格大于搜索 key 的检查点的索引，如果不存在则返回 `high`。
     * `low` 和 `high` 定义了搜索的区间，其中 `low` 是包含的，`high` 是不包含的。
     *
     * 警告：`high` 不应大于数组的长度。
     */
    function _upperBinaryLookup(
        Checkpoint208[] storage self,
        uint48 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev 返回第一个（最旧的）key 大于或等于搜索 key 的检查点的索引，如果不存在则返回 `high`。
     * `low` 和 `high` 定义了搜索的区间，其中 `low` 是包含的，`high` 是不包含的。
     *
     * 警告：`high` 不应大于数组的长度。
     */
    function _lowerBinaryLookup(
        Checkpoint208[] storage self,
        uint48 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev 访问数组的一个元素而不执行边界检查。假定位置在边界之内。
     */
    function _unsafeAccess(
        Checkpoint208[] storage self,
        uint256 pos
    ) private pure returns (Checkpoint208 storage result) {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    struct Trace160 {
        Checkpoint160[] _checkpoints;
    }

    struct Checkpoint160 {
        uint96 _key;
        uint160 _value;
    }

    /**
     * @dev 将一个 (`key`, `value`) 对推入到一个 Trace160 中，以将其存储为检查点。
     *
     * 返回旧值和新值。
     *
     * 重要提示：永远不要接受用户输入的 `key`，因为一个任意设置的 `type(uint96).max` 的 key 将会禁用此库。
     */
    function push(
        Trace160 storage self,
        uint96 key,
        uint160 value
    ) internal returns (uint160 oldValue, uint160 newValue) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @dev 返回第一个（最旧的）key 大于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     */
    function lowerLookup(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        return pos == len ? 0 : _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @dev 返回最后一个（最新的）key 小于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     */
    function upperLookup(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回最后一个（最新的）key 小于或等于搜索 key 的检查点中的值，如果不存在则返回零。
     *
     * 注意：这是 {upperLookup} 的一个变体，经过优化以查找“最近的”检查点（即具有较大 key 的检查点）。
     */
    function upperLookupRecent(Trace160 storage self, uint96 key) internal view returns (uint160) {
        uint256 len = self._checkpoints.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - Math.sqrt(len);
            if (key < _unsafeAccess(self._checkpoints, mid)._key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);

        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回最新检查点中的值，如果没有检查点则返回零。
     */
    function latest(Trace160 storage self) internal view returns (uint160) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? 0 : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev 返回结构体中是否存在检查点（即它不为空），如果存在，则返回最新检查点的 key 和 value。
     */
    function latestCheckpoint(Trace160 storage self) internal view returns (bool exists, uint96 _key, uint160 _value) {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, 0);
        } else {
            Checkpoint160 storage ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt._key, ckpt._value);
        }
    }

    /**
     * @dev 返回检查点的数量。
     */
    function length(Trace160 storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @dev 返回给定位置的检查点。
     */
    function at(Trace160 storage self, uint32 pos) internal view returns (Checkpoint160 memory) {
        return self._checkpoints[pos];
    }

    /**
     * @dev 将一个 (`key`, `value`) 对推入到一个有序的检查点列表中，可以通过插入新检查点，
     * 或者更新最后一个检查点来完成。
     */
    function _insert(
        Checkpoint160[] storage self,
        uint96 key,
        uint160 value
    ) private returns (uint160 oldValue, uint160 newValue) {
        uint256 pos = self.length;

        if (pos > 0) {
            Checkpoint160 storage last = _unsafeAccess(self, pos - 1);
            uint96 lastKey = last._key;
            uint160 lastValue = last._value;

            // 检查点的 key 必须是非递减的。
            if (lastKey > key) {
                revert CheckpointUnorderedInsertion();
            }

            // 更新或推入新的检查点
            if (lastKey == key) {
                last._value = value;
            } else {
                self.push(Checkpoint160({_key: key, _value: value}));
            }
            return (lastValue, value);
        } else {
            self.push(Checkpoint160({_key: key, _value: value}));
            return (0, value);
        }
    }

    /**
     * @dev 返回第一个（最旧的）key 严格大于搜索 key 的检查点的索引，如果不存在则返回 `high`。
     * `low` 和 `high` 定义了搜索的区间，其中 `low` 是包含的，`high` 是不包含的。
     *
     * 警告：`high` 不应大于数组的长度。
     */
    function _upperBinaryLookup(
        Checkpoint160[] storage self,
        uint96 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev 返回第一个（最旧的）key 大于或等于搜索 key 的检查点的索引，如果不存在则返回 `high`。
     * `low` 和 `high` 定义了搜索的区间，其中 `low` 是包含的，`high` 是不包含的。
     *
     * 警告：`high` 不应大于数组的长度。
     */
    function _lowerBinaryLookup(
        Checkpoint160[] storage self,
        uint96 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev 访问数组的一个元素而不执行边界检查。假定位置在边界之内。
     */
    function _unsafeAccess(
        Checkpoint160[] storage self,
        uint256 pos
    ) private pure returns (Checkpoint160 storage result) {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }
}
