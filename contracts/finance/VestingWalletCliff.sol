// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (finance/VestingWalletCliff.sol)

pragma solidity ^0.8.20;

import {SafeCast} from "../utils/math/SafeCast.sol";
import {VestingWallet} from "./VestingWallet.sol";

/**
 * @dev {VestingWallet} 的扩展，为归属时间表添加了悬崖期。
 *
 * _自 v5.1 起可用。_
 * 带有“锁定期”的归属钱包。
 */
abstract contract VestingWalletCliff is VestingWallet {
    using SafeCast for *;

    uint64 private immutable _cliff;

    /// @dev 指定的悬崖期持续时间大于归属持续时间。
    error InvalidCliffDuration(uint64 cliffSeconds, uint64 durationSeconds);

    /**
     * @dev 设置悬崖期的持续时间（以秒为单位）。悬崖期从归属时间表开始（请参阅 {VestingWallet} 的构造函数），并在 `cliffSeconds` 秒后结束。
     */
    constructor(uint64 cliffSeconds) {
        if (cliffSeconds > duration()) {
            revert InvalidCliffDuration(cliffSeconds, duration().toUint64());
        }
        _cliff = start().toUint64() + cliffSeconds;
    }

    /**
     * @dev 获取悬崖期时间戳。
     */
    function cliff() public view virtual returns (uint256) {
        return _cliff;
    }

    /**
     * @dev 归属公式的虚拟实现。对于给定的总历史分配，此函数返回归属金额作为时间的函数。如果未达到 {cliff} 时间戳，则返回 0。
     *
     * 重要提示：悬崖期不仅使时间表返回 0，而且还忽略了调用继承实现（即 `super._vestingSchedule`）的每个可能的副作用。
     * 如果此函数的重写实现有任何副作用（例如，写入内存或回滚），请仔细考虑此警告。
     *
     * 这个警告是在提醒那些想要继承 `VestingWalletCliff` 并重写 `_vestingSchedule` 函数的开发者。
     *  标准的 VestingWallet 中的 _vestingSchedule 是一个 view 函数，它只进行计算，不修改任何状态（没有“副作用”）。
     *  但是，假设一个开发者创建了一个自定义的归属合约，其 _vestingSchedule 函数包含了一些副作用。例如：
     *      每次计算时，都记录一下计算的时间戳。
     *      每次计算时，都触发一个事件（Event）。
     *      在某些特定条件下，函数会执行 revert 操作。(在您的版本里加入了 require 或 revert 语句时，它才有可能 revert。)
     *  只会在达到悬崖期后，才会调用 super._vestingSchedule。
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view virtual override returns (uint256) {
        return timestamp < cliff() ? 0 : super._vestingSchedule(totalAllocation, timestamp);
    }
}
