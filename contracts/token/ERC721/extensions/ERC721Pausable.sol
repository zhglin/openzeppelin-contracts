// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.1.0) (token/ERC721/extensions/ERC721Pausable.sol)

pragma solidity ^0.8.24;

import {ERC721} from "../ERC721.sol";
import {Pausable} from "../../../utils/Pausable.sol";

/**
 * @dev 具有可暂停的代币转移、铸造和销毁功能的 ERC-721 代币。
 *
 * 适用于诸如在评估期结束前阻止交易，或在出现重大漏洞时作为紧急开关冻结所有代币转移等场景。
 *
 * 重要提示：此合约不包含公共的暂停和取消暂停功能(指的是你需要在自己的合约里亲手编写的、`public` 或 `external` 可见的函数)。
 * 除了继承此合约外，您还必须定义这两个功能，调用{Pausable-_pause} 和 {Pausable-_unpause} 内部函数，
 * 并使用适当的访问控制，例如使用 {AccessControl} 或 {Ownable}。
 * 否则将导致合约的暂停机制无法访问，从而无法使用。
 */
abstract contract ERC721Pausable is ERC721, Pausable {
    /**
     * @dev 参见 {ERC721-_update}。
     *
     * 要求：
     * - 合约必须未被暂停。
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }
}
