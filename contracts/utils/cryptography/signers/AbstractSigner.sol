// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/cryptography/signers/AbstractSigner.sol)

pragma solidity ^0.8.20;

/**
 * @dev 用于签名验证的抽象合约。
 *
 * 开发人员必须实现 {_rawSignatureValidation} 并将其用作最低级别的签名验证机制。
 *
 * @custom:stateless
 */
abstract contract AbstractSigner {
    /**
     * @dev 签名验证算法。
     *
     * 警告：实现签名验证算法是一项对安全敏感的操作，因为它涉及密码学验证。
     * 在部署之前进行彻底的审查和测试非常重要。
     * 考虑使用其中一个签名验证库 (xref:api:utils/cryptography#ECDSA[ECDSA],
     * xref:api:utils/cryptography#P256[P256] or xref:api:utils/cryptography#RSA[RSA])。
     */
    function _rawSignatureValidation(bytes32 hash, bytes calldata signature) internal view virtual returns (bool);
}
