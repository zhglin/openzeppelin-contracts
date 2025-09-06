// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.0.0) (utils/structs/BitMaps.sol)
pragma solidity ^0.8.20;

/**
 * @dev 用于以紧凑和高效的方式管理 uint256 到 bool 映射的库，前提是键是连续的。
 * 主要灵感来自 Uniswap 的 https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor]。
 *
 * BitMaps 将 256 个布尔值打包到 `uint256` 类型的单个 256 位插槽的每个位上。
 * 每一个 bit 代表一个 true(1) 或 false (0)。
 * 因此，对应于 256 个 _连续_ 索引的布尔值将只消耗一个插槽，
 * 而不像常规的 `bool` 那样会为一个值消耗整个插槽。
 *
 * 这通过两种方式节省了 gas：
 * - 每 256 次才会有一次将零值设置为非零值
 * - 每 256 个 _连续_ 索引访问同一个“热”插槽
 */
library BitMaps {
    struct BitMap {
        mapping(uint256 bucket => uint256) _data;
    }

    /**
     * @dev 返回 `index` 处的位是否已设置。
     */
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        // index >> 8 就完全等价于 index / 256,Gas成本极低的方式.
        // 计算出给定的 `index` 应该存储在哪一个‘桶’（bucket）里
        uint256 bucket = index >> 8;
        // (index & 0xff) 计算“槽内位置”, 0xff等于十进制的 255。它的二进制表示是 11111111,完全等价于取模运算 `index % 256`
        // 因为每个“桶”能存 256 个布尔值，所以我们需要知道 index 是这个桶里的第几个。取模 256 正好能得到这个范围在 0 到 255 之间的“槽内位置”。
        // (index & 0xff)返回的只是第几位,1 << position为了生成一个精准的“位掩码”,例如 position = 3,1 << 3 = 00001000
        uint256 mask = 1 << (index & 0xff);
        // 通过位与运算 (&) 检查该位是否被设置为 1
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev 将 `index` 处的位设置为布尔值 `value`。
     */
    function setTo(BitMap storage bitmap, uint256 index, bool value) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /**
     * @dev 设置 `index` 处的位。
     */
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        // 位运算 OR (|) 用于将特定位设置为 1，而不影响其他位
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev 取消设置 `index` 处的位。
     */
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        // ~mask 生成一个与 mask 相反的掩码
        // 位运算 AND (&) 用于将特定位设置为 0，而不影响其他位
        bitmap._data[bucket] &= ~mask;
    }
}
