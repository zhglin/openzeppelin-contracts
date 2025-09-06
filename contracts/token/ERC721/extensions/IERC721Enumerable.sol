// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity >=0.6.2;

import {IERC721} from "../IERC721.sol";

/**
 * @title ERC-721 不可替代代币标准，可选的枚举扩展
 * @dev 参见 https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev 返回合约存储的代币总数。
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev 返回 `owner` 在其代币列表的给定 `index` 处拥有的代币 ID。
     * 与 {balanceOf} 一起使用以枚举 `owner` 的所有代币。
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev 返回合约存储的所有代币中给定 `index` 处的代币 ID。
     * 与 {totalSupply} 一起使用以枚举所有代币。
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}
