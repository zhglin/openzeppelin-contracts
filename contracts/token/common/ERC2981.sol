// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.20;

import {IERC2981} from "../../interfaces/IERC2981.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";

/**
 * @dev NFT 版税标准的实现，一种标准化的检索版税支付信息的方式。
 *
 * 版税信息可以通过 {_setDefaultRoyalty} 为所有代币 ID 全局指定，
 * and/or通过 {_setTokenRoyalty}为特定的代币 ID 单独指定。后者优先于前者。
 * 版税被指定为销售价格的一部分。{_feeDenominator} 是可重写的，但默认为 10000，
 * 这意味着费用默认以基点表示。
 * 重要提示：ERC-2981 仅指定了一种信令版税信息的方式，并不强制其支付。请参阅
 * ERC 中的 https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[基本原理]。
 * 市场应自愿支付版税以及销售款，但请注意，该标准尚未得到广泛支持。
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    // 版税信息的结构体
    struct RoyaltyInfo {
        address receiver;       // 版税接收者地址
        uint96 royaltyFraction; // 版税比例
    }

    // 默认的版税信息,所有tokenId默认使用
    RoyaltyInfo private _defaultRoyaltyInfo;

    // 每个tokenId对应的版税信息
    mapping(uint256 tokenId => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @dev 设置的默认版税无效（例如 (numerator / denominator) >= 1）。
     */
    error ERC2981InvalidDefaultRoyalty(uint256 numerator, uint256 denominator);

    /**
     * @dev 默认版税接收者无效。
     */
    error ERC2981InvalidDefaultRoyaltyReceiver(address receiver);

    /**
     * @dev 为特定 `tokenId` 设置的版税无效（例如 (numerator / denominator) >= 1）。
     */
    error ERC2981InvalidTokenRoyalty(uint256 tokenId, uint256 numerator, uint256 denominator);

    /**
     * @dev `tokenId` 的版税接收者无效。
     */
    error ERC2981InvalidTokenRoyaltyReceiver(uint256 tokenId, address receiver);

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC2981
    // 返回tokenId的版税接收者和版税金额
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) public view virtual returns (address receiver, uint256 amount) {
        // 如果 _tokenRoyaltyInfo[tokenId] 这个键值对不存在,
        // 那么 _royaltyInfo会得到一个所有成员都为其类型默认值的 `RoyaltyInfo` 结构体。
        RoyaltyInfo storage _royaltyInfo = _tokenRoyaltyInfo[tokenId];
        address royaltyReceiver = _royaltyInfo.receiver;
        uint96 royaltyFraction = _royaltyInfo.royaltyFraction;

        if (royaltyReceiver == address(0)) {
            royaltyReceiver = _defaultRoyaltyInfo.receiver;
            royaltyFraction = _defaultRoyaltyInfo.royaltyFraction;
        }

        // 计算版税金额
        uint256 royaltyAmount = (salePrice * royaltyFraction) / _feeDenominator();

        return (royaltyReceiver, royaltyAmount);
    }

    /**
     * @dev 用于解释 {_setTokenRoyalty} 和 {_setDefaultRoyalty} 中设置的费用作为销售价格一部分的分母。
     * 默认为 10000，因此费用以基点表示，但可以通过重写进行自定义。
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev 设置此合约中所有 ID 将默认使用的版税信息。
     * 要求：
     * - `receiver` 不能是零地址。
     * - `feeNumerator` 不能大于费用分母。
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        uint256 denominator = _feeDenominator();
        if (feeNumerator > denominator) {
            // 版税费用将超过销售价格
            revert ERC2981InvalidDefaultRoyalty(feeNumerator, denominator);
        }
        if (receiver == address(0)) {
            revert ERC2981InvalidDefaultRoyaltyReceiver(address(0));
        }

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev 删除默认版税信息。
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev 为特定代币 ID 设置版税信息，覆盖全局默认值。
     *
     * 要求：
     * - `receiver` 不能是零地址。
     * - `feeNumerator` 不能大于费用分母。
     */
    function _setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) internal virtual {
        uint256 denominator = _feeDenominator();
        if (feeNumerator > denominator) {
            // 版税费用将超过销售价格
            revert ERC2981InvalidTokenRoyalty(tokenId, feeNumerator, denominator);
        }
        if (receiver == address(0)) {
            revert ERC2981InvalidTokenRoyaltyReceiver(tokenId, address(0));
        }

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev 将代币 ID 的版税信息重置为全局默认值。
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}
