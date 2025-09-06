// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (interfaces/IERC4906.sol)

pragma solidity >=0.6.2;

import {IERC165} from "./IERC165.sol";
import {IERC721} from "./IERC721.sol";

/// @title ERC-721 元数据更新扩展
interface IERC4906 is IERC165, IERC721 {
    /// @dev 当代币的元数据被更改时，会发出此事件。
    /// 以便第三方平台（如 NFT 市场）可以
    /// 及时更新 NFT 的图像和相关属性。
    event MetadataUpdate(uint256 _tokenId);

    /// @dev 当一系列代币的元数据被更改时，会发出此事件。
    /// 以便第三方平台（如 NFT 市场）可以
    /// 及时更新 NFT 的图像和相关属性。
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}
