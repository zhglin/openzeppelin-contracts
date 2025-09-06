// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.1.0) (token/ERC721/extensions/ERC721Burnable.sol)

pragma solidity ^0.8.24;

import {ERC721} from "../ERC721.sol";
import {Context} from "../../../utils/Context.sol";

/**
 * @title ERC-721 可销毁代币
 * @dev 可被销毁 (destroyed) 的 ERC-721 代币。
 */
abstract contract ERC721Burnable is Context, ERC721 {
    /**
     * @dev 销毁 `tokenId`。参见 {ERC721-_burn}。
     *
     * 要求：
     * - 调用者必须拥有 `tokenId` 或被授权为操作员。
     */
    function burn(uint256 tokenId) public virtual {
        // 设置 "auth" 参数会启用 `_isAuthorized` 检查，该检查会验证代币是否存在
        // (from != 0)。因此，此处无需验证返回值不为 0。
        _update(address(0), tokenId, _msgSender());
    }
}
