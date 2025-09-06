// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (interfaces/IERC2981.sol)

pragma solidity >=0.6.2;

import {IERC165} from "../utils/introspection/IERC165.sol";

/**
 * @dev NFT 版税标准接口。
 *
 * 一种标准化的方式来检索非同质化代币（NFT）的版税支付信息，
 * 以实现所有 NFT 市场和生态系统参与者对版税支付的通用支持。
 */
interface IERC2981 is IERC165 {
    /**
     * @dev 根据可能以任何交换单位计价的销售价格，返回应支付多少版税以及支付给谁。
     * 版税金额以该交换单位计价，并应以该相同的交换单位支付。
     *
     * 注意：ERC-2981 允许将版税设置为价格的 100%。在这种情况下，所有价格都将发送给
     * 版税接收者，而 0 代币发送给卖方。处理版税的合约应考虑空转账。
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}
