// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (最后更新于 v5.3.0) (access/manager/AuthorityUtils.sol)

pragma solidity ^0.8.20;

import {IAuthority} from "./IAuthority.sol";

library AuthorityUtils {
    /**
     * @dev 由于 `AccessManager` 实现了一个扩展的 IAuthority 接口，为了与预先存在的 `IAuthority` 接口向后兼容，
     * 调用 `canCall` 时需要特别小心，以避免因返回数据不足而回滚。
     * 这个辅助函数负责以向后兼容的方式调用 `canCall` 而不会回滚。
     */
    function canCallWithDelay(
        address authority,
        address caller,
        address target,
        bytes4 selector
    ) internal view returns (bool immediate, uint32 delay) {
        bytes memory data = abi.encodeCall(IAuthority.canCall, (caller, target, selector));

        assembly ("memory-safe") {
            // 从内存地址 0x00 开始的64个字节全部清零。
            mstore(0x00, 0x00)
            mstore(0x20, 0x00)
            // staticcall 是一个特殊的外部调用，它保证被调用的函数不能修改链上状态（类似 view 函数）。
            // 它如果成功则返回 1，如果失败（revert）则返回0。if 语句块只在成功时执行。
            // data，它代表的就是这个变量在内存中的起始地址。
            // `data`：这个地址本身，它指向一个32字节的槽，里面存放着字节数组的长度。
            // `data + 0x20` (也就是汇编里的 add(data, 0x20))：从长度槽之后开始，才是字节数组真正的、连续的内容。
            // add(data, 0x20)是数组实际数据内容开始的那个内存地址, mload(data)是数组的长度
            if staticcall(gas(), authority, add(data, 0x20), mload(data), 0x00, 0x40) {
                // 返回值内容存储在内存的前64个字节中
                immediate := mload(0x00)
                delay := mload(0x20)

                // 如果 delay 不适合 uint32，则返回 0 (无延迟)
                // 相当于: if gt(delay, 0xFFFFFFFF) { delay := 0 }
                // shr(32, delay) 将 delay 右移 32 位,delay是一个256位的数
                // 如果 delay 超过 32 位, 则 shr(32, delay) 非零, iszero(...) 为 0
                // 如果 delay 不超过 32 位, shr(32, delay) 为 0, iszero(...) 为 1
                delay := mul(delay, iszero(shr(32, delay)))
            }
        }
    }
}
