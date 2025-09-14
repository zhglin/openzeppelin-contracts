// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (最后更新于 v5.1.0) (utils/types/Time.sol)

pragma solidity ^0.8.20;

import {Math} from "../math/Math.sol";
import {SafeCast} from "../math/SafeCast.sol";

/**
 * @dev 此库提供用于操作时间相关对象的辅助函数。
 *
 * 它使用以下类型：
 * - `uint48` 用于时间点
 * - `uint32` 用于持续时间
 *
 * 虽然该库没有为时间点和持续时间提供特定的类型，但它确实提供了：
 * - 一个 `Delay` 类型，用于表示可以在给定点自动更改值的持续时间
 * - 其他辅助函数
 */
library Time {
    using Time for *;

    /**
     * @dev 获取区块时间戳作为一个时间点（Timepoint）。
     */
    function timestamp() internal view returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    /**
     * 在区块链的世界里，“时间”有两个主要的度量衡：
     *  1. 物理时间 (Wall-Clock Time): 这就是我们通常意义上的时间，通过 block.timestamp 获取，表示自 Unix 纪元以来的秒数。
     *  2. 区块进程 (Block Progression): 也就是区块高度，通过 block.number 获取。
     * 将区块号（block.number）作为一个“时间点”有以下几个原因和优势：
     *  确定性和不可篡改性: 区块号是严格单调递增的整数，一个接一个，非常稳定。
     *  而 block.timestamp 在一定程度上可以被矿工微调（通常在几秒到几十秒的范围内），因此区块号在某些场景下更可靠。
     * 可预测的“滴答”: 你可以把每一个新区块的产生看作是链上时钟的一次“滴答”。
     *  如果你想让一个操作在“100次滴答”之后才能执行，你就可以设置一个起始区块号 + 100 的截止区块号。
     *  这比计算 起始时间戳 + N秒 要更贴近区块链自身的节奏。
     */
   
    /**
     * @dev 获取区块号作为一个时间点（Timepoint）。
     */
    function blockNumber() internal view returns (uint48) {
        return SafeCast.toUint48(block.number);
    }

    // ==================================================== Delay =====================================================
    /**
     * @dev `Delay` 是一个 uint32 类型的持续时间，可以被编程为在未来的一个给定时间点自动改变其值。
     * “effect”时间点描述了从“旧”值到“新”值的转换何时发生。
     * 这允许在更新应用于某些操作的延迟的同时保留一些保证。
     *
     * 特别是，{update} 函数保证，如果延迟减少，旧的延迟仍然在一段时间内适用。
     * 例如，如果当前完成一次升级的延迟是7天，管理员不应该能够将延迟设置为0并立即升级。
     * 如果管理员想要减少延迟，旧的延迟（7天）应该仍然在一段时间内适用。
     *
     *
     * `Delay` 类型长112位，打包了以下内容：
     *
     * ```
     *   | [uint48]: effect date (timepoint)
     *   |           | [uint32]: value before (duration)
     *   ↓           ↓       ↓ [uint32]: value after (duration) 
     *   | [uint48]: 生效日期 (时间点)
     *   |           | [uint32]: 生效之前的旧值 (持续时间)
     *   ↓           ↓       ↓ [uint32]: 生效之后的新值 (持续时间)
     * 0xAAAAAAAAAAAABBBBBBBBCCCCCCCC
     * ```
     *
     * 注意：{get} 和 {withUpdate} 函数使用时间戳进行操作。目前不支持基于区块号的延迟。
     * 
     * 把这三个信息（当前值、待定值、生效时间）分别存在三个独立的存储变量里，会非常消耗Gas（至少需要3个存储槽）。
     * Delay 的核心目标就是：将这三个相关的信息“打包”到一个变量里，以极大地节省Gas。
     */
    type Delay is uint112;

    /**
     * @dev 将一个持续时间包装成一个 Delay 对象，以添加“未来更新”的一步式功能。
     * duration 的值会被放在 CCCCCCCC 这部分，
     */
    function toDelay(uint32 duration) internal pure returns (Delay) {
        return Delay.wrap(duration);
    }

    /**
     * @dev 获取在给定时间点的值，以及在该时间点之后是否有已调度的变更的待定值和生效时间点。
     * 如果生效时间点为0，则不应考虑待定值。
     * effect生效时间小于timepoint，则表示变更已经生效，返回valueAfter，并且待定值和生效时间点都为0。
     * effect生效时间大于timepoint，则表示变更尚未生效，返回valueBefore、valueAfter和effect。
     */
    function _getFullAt(
        Delay self,
        uint48 timepoint
    ) private pure returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        (valueBefore, valueAfter, effect) = self.unpack();
        return effect <= timepoint ? (valueAfter, 0, 0) : (valueBefore, valueAfter, effect);
    }

    /**
     * @dev 获取当前值，以及是否有已调度的变更的待定值和生效时间点。
     * 如果生效时间点为0，则不应考虑待定值。
     */
    function getFull(Delay self) internal view returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        return _getFullAt(self, timestamp());
    }

    /**
     * @dev 获取当前值。
     */
    function get(Delay self) internal view returns (uint32) {
        (uint32 delay, , ) = self.getFull();
        return delay;
    }

    /**
     * @dev 更新一个 Delay 对象，使其在一个自动计算出的时间点之后采用新的持续时间，
     * 以在更新时刻强制执行旧的延迟。返回更新后的 Delay 对象和新延迟生效的时间戳。
     * minSetback 最小生效间隔
     * 它保证了任何对延迟规则的修改，都不能悄无声息地、零时差地发生。
     * 它确保了总会有一个时间窗口，让外部观察者（如社区成员、监控机器人）能够注意并有时间去审查这个变更。
     */
    function withUpdate(
        Delay self,
        uint32 newValue,
        uint32 minSetback
    ) internal view returns (Delay updatedDelay, uint48 effect) {
        uint32 value = self.get();
        uint32 setback = uint32(Math.max(minSetback, value > newValue ? value - newValue : 0));
        effect = timestamp() + setback;
        return (pack(value, newValue, effect), effect);
    }

    /**
     * @dev 将一个延迟拆分为其组成部分：valueBefore（之前的值）、valueAfter（之后的值）和 effect（转换时间点）。
     */
    function unpack(Delay self) internal pure returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        uint112 raw = Delay.unwrap(self);

        valueAfter = uint32(raw);
        valueBefore = uint32(raw >> 32);
        effect = uint48(raw >> 64);

        return (valueBefore, valueAfter, effect);
    }

    /**
     * @dev 将各个组成部分打包成一个 Delay 对象。
     * 移位运算符号 `<<` 和按位或运算符 `|` 用于将各个部分组合成一个单一的 uint112 值，
     */
    function pack(uint32 valueBefore, uint32 valueAfter, uint48 effect) internal pure returns (Delay) {
        return Delay.wrap((uint112(effect) << 64) | (uint112(valueBefore) << 32) | uint112(valueAfter));
    }
}
