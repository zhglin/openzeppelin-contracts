// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC6372.sol)

pragma solidity >=0.4.16;

interface IERC6372 {
    /**
     * @dev 用于标记检查点（checkpoints）的时钟。可以重写此函数以实现基于时间戳的检查点（和投票）。
     */
    function clock() external view returns (uint48);

    /**
     * @dev 对时钟的描述。
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() external view returns (string memory);
}
