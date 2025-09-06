// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC721/extensions/ERC721URIStorage.sol)

pragma solidity ^0.8.24;

import {ERC721} from "../ERC721.sol";
import {IERC721Metadata} from "./IERC721Metadata.sol";
import {Strings} from "../../../utils/Strings.sol";
import {IERC4906} from "../../../interfaces/IERC4906.sol";
import {IERC165} from "../../../interfaces/IERC165.sol";

/**
 * @dev 具有基于存储的代币 URI 管理功能的 ERC-721 代币。
 */
abstract contract ERC721URIStorage is IERC4906, ERC721 {
    using Strings for uint256;

    // ERC-4906 中定义的接口 ID。这不对应于传统的接口 ID，
    // 因为 ERC-4906 仅定义事件，不包括任何外部函数。
    // 由于没有函数选择器可以用来进行异或运算，type(IERC4906).interfaceId 无法算出一个有意义的、独特的ID。
    bytes4 private constant ERC4906_INTERFACE_ID = bytes4(0x49064906);

    // 可选的代币 URI 映射
    mapping(uint256 tokenId => string) private _tokenURIs;

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == ERC4906_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // 如果没有基础 URI，则返回代币 URI。
        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        // 如果两者都已设置，则连接 baseURI 和 tokenURI (通过 string.concat)。
        if (bytes(_tokenURI).length > 0) {
            return string.concat(base, _tokenURI);
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev 将 `_tokenURI` 设置为 `tokenId` 的 tokenURI。
     * 触发 {IERC4906-MetadataUpdate}。
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        _tokenURIs[tokenId] = _tokenURI;
        emit MetadataUpdate(tokenId);
    }
}
