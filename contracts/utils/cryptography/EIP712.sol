// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.24;

import {MessageHashUtils} from "./MessageHashUtils.sol";
import {ShortStrings, ShortString} from "../ShortStrings.sol";
import {IERC5267} from "../../interfaces/IERC5267.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP-712] 是一个用于哈希和签名类型化结构化数据的标准。
 *
 * EIP 中指定的编码方案需要一个域分隔符和类型化结构化数据的哈希，其编码非常通用，因此在 Solidity 中实现它并不可行，
 * 因此此合约不实现编码本身。协议需要实现它们所需的特定类型编码，以便结合使用 `abi.encode` 和 `keccak256` 来生成其类型化数据的哈希。
 *
 * // 此合约实现了 EIP-712 域分隔符 ({_domainSeparatorV4})，它作为编码方案的一部分使用，以及编码的最后一步，
 * // 以获取消息摘要，然后通过 ECDSA ({_hashTypedDataV4}) 进行签名。
 *
 * 域分隔符的实现旨在尽可能高效，同时仍能正确更新链 ID，以防止在链的最终分叉上发生重放攻击。
 *
 * 注意：此合约实现了编码的“v4”版本，如 MetaMask 中 JSON RPC 方法
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4`] 所实现。
 *
 * 注意：在此合约的可升级版本中，缓存的值将对应于实现合约的地址和域分隔符。
 * 这将导致 {_domainSeparatorV4} 函数始终从不可变值重建分隔符，这比访问冷存储中的缓存版本更便宜。
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable
 */
abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;

    // 协议规范的,不能改
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // 将域分隔符缓存为不可变值，但也存储其对应的链 ID，以便在链 ID 更改时使缓存的域分隔符失效。
    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;

    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;

    ShortString private immutable _name;
    ShortString private immutable _version;
    // slither-disable-next-line constable-states
    string private _nameFallback;
    // slither-disable-next-line constable-states
    string private _versionFallback;

    /**
     * @dev 初始化域分隔符和参数缓存。
     * `name` 和 `version` 的含义在
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP-712] 中指定：
     * - `name`：签名域的用户可读名称，即 DApp 或协议的名称。
     * - `version`：签名域的当前主要版本。
     * 注意：这些参数不能更改，除非通过 xref:learn::upgrading-smart-contracts.adoc[智能合约升级]。
     */
    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        // EIP-712 规范的要求，旨在为动态长度的数据创建一个固定长度的哈希值，以便进行后续的签名和验证。
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }

    /**
     * @dev 返回当前链的域分隔符。
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    /**
     * EIP-712 哈希与 call/delegatecall 参数之间的数据准备相似性并非巧合。
     * 这是为了利用 EVM 已经建立的、确定性的、受工具支持的 ABI 编码标准而做出的深思熟虑的设计选择。
     * 这确保了 EIP-712 签名的加密完整性，促进了其验证，并通过建立在现有知识和工具之上，使开发者更容易使用。
     */
    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }

    /**
     * @dev 给定一个已经 https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[哈希化的结构体]，
     * 此函数返回此域的完全编码的 EIP712 消息的哈希。
     * 此哈希可以与 {ECDSA-recover} 一起使用，以获取消息的签名者。例如：
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     *
     * 给定一个已经哈希化的结构体，此函数返回此域的完全编码的 EIP712 消息的哈希。
     * 按照协议的要求，structHash的生成算法与dominSeparator的生成算法相同。
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /// @inheritdoc IERC5267
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            _EIP712Name(),
            _EIP712Version(),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    /**
     * @dev EIP712 域的名称参数。
     *
     * 注意：默认情况下，此函数读取 _name，它是一个不可变值。
     * 仅在必要时（如果值太大而无法放入 ShortString 中）才从存储中读取。
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Name() internal view returns (string memory) {
        return _name.toStringWithFallback(_nameFallback);
    }

    /**
     * @dev EIP712 域的版本参数。
     *
     * 注意：默认情况下，此函数读取 _version，它是一个不可变值。
     * 仅在必要时（如果值太大而无法放入 ShortString 中）才从存储中读取。
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Version() internal view returns (string memory) {
        return _version.toStringWithFallback(_versionFallback);
    }
}
