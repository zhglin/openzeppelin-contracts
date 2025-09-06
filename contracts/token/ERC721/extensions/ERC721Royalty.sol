// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC721/extensions/ERC721Royalty.sol)

pragma solidity ^0.8.24;

import {ERC721} from "../ERC721.sol";
import {IERC165} from "../../../utils/introspection/ERC165.sol";
import {ERC2981} from "../../common/ERC2981.sol";

/**
 * @dev ERC-721 的扩展，带有 ERC-2981 NFT 版税标准，一种标准化的检索版税支付信息的方式。
 *
 * 版税信息可以通过 {ERC2981-_setDefaultRoyalty} 为所有代币 ID 全局指定，
 * and/or通过{ERC2981-_setTokenRoyalty} 为特定的代币 ID 单独指定。后者优先于前者。
 * 重要提示：ERC-2981 仅指定了一种信令版税信息的方式，并不强制其支付。
 * 请参阅ERC 中的 https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[基本原理]。
 * 市场应自愿支付版税以及销售款，但请注意，该标准尚未得到广泛支持。
 */
abstract contract ERC721Royalty is ERC2981, ERC721 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
