// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (interfaces/IERC2309.sol)

pragma solidity >=0.4.11;

/**
 * @dev ERC-2309: ERC-721 连续转移扩展。
 */
interface IERC2309 {
    /**
     * @dev 当从 `fromTokenId` 到 `toTokenId` 的代币从 `fromAddress` 转移到 `toAddress` 时发出。
     */
    event ConsecutiveTransfer(
        uint256 indexed fromTokenId,
        uint256 toTokenId,
        address indexed fromAddress,
        address indexed toAddress
    );
}
