// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorNoncesKeyed.sol)

pragma solidity ^0.8.24;

import {Governor} from "../Governor.sol";
import {Nonces} from "../../utils/Nonces.sol";
import {NoncesKeyed} from "../../utils/NoncesKeyed.sol";
import {SignatureChecker} from "../../utils/cryptography/SignatureChecker.sol";

/**
 * @dev {Governor} 的一个扩展，它扩展了现有的 nonce 管理以使用 {NoncesKeyed}，其中密钥（key）是 `proposalId` 的低192位。
 * 这对于通过签名投票同时为每个提案维护独立的 nonce 序列非常有用。
 *
 * 注意：传统的（无密钥的）nonce 仍然受支持，并且可以像此扩展不存在一样继续使用。
 */
abstract contract GovernorNoncesKeyed is Governor, NoncesKeyed {
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual override(Nonces, NoncesKeyed) {
        super._useCheckedNonce(owner, nonce);
    }

    /**
     * @dev 根据带密钥的 nonce 检查签名，如果失败则回退到传统的 nonce。
     *
     * 注意：如果带密钥的 nonce 有效，此函数将不会调用 `super._validateVoteSig`。
     * 根据函数的线性化，可能会跳过某些副作用。
     */
    function _validateVoteSig(
        uint256 proposalId,
        uint8 support,
        address voter,
        bytes memory signature
    ) internal virtual override returns (bool) {
        if (
            // 对带有密钥的 nonce 进行签名验证
            SignatureChecker.isValidSignatureNow(
                voter,
                _hashTypedDataV4(
                    keccak256(
                        abi.encode(BALLOT_TYPEHASH, proposalId, support, voter, nonces(voter, uint192(proposalId)))
                    )
                ),
                signature
            )
        ) {
            // 如果验证通过，消耗该带密钥的 nonce
            _useNonce(voter, uint192(proposalId));
            return true;
        } else {
            // 否则，回退到传统的 nonce 验证
            return super._validateVoteSig(proposalId, support, voter, signature);
        }
    }

    /**
     * @dev 根据带密钥的 nonce 检查签名，如果失败则回退到传统的 nonce。
     *
     * 注意：如果带密钥的 nonce 有效，此函数将不会调用 `super._validateExtendedVoteSig`。
     * 根据函数的线性化，可能会跳过某些副作用。
     */
    function _validateExtendedVoteSig(
        uint256 proposalId,
        uint8 support,
        address voter,
        string memory reason,
        bytes memory params,
        bytes memory signature
    ) internal virtual override returns (bool) {
        if (
            // 对带有密钥的 nonce 进行签名验证
            SignatureChecker.isValidSignatureNow(
                voter,
                _hashTypedDataV4(
                    keccak256(
                        abi.encode(
                            EXTENDED_BALLOT_TYPEHASH,
                            proposalId,
                            support,
                            voter,
                            nonces(voter, uint192(proposalId)),
                            keccak256(bytes(reason)),
                            keccak256(params)
                        )
                    )
                ),
                signature
            )
        ) {
            // 如果验证通过，消耗该带密钥的 nonce
            _useNonce(voter, uint192(proposalId));
            return true;
        } else {
            // 否则，回退到传统的 nonce 验证
            return super._validateExtendedVoteSig(proposalId, support, voter, reason, params, signature);
        }
    }
}
