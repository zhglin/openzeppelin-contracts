// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/ERC20Permit.sol)

pragma solidity ^0.8.24;

import {IERC20Permit} from "./IERC20Permit.sol";
import {ERC20} from "../ERC20.sol";
import {ECDSA} from "../../../utils/cryptography/ECDSA.sol";
import {EIP712} from "../../../utils/cryptography/EIP712.sol";
import {Nonces} from "../../../utils/Nonces.sol";

/**
 * @dev ERC-20 Permit 扩展的实现，允许通过签名进行授权，如 https://eips.ethereum.org/EIPS/eip-2612[ERC-2612] 中所定义。
 *
 * 添加了 {permit} 方法，该方法可以通过提交由账户签名的消息来更改该账户的 ERC-20 授权额度（请参阅 {IERC20-allowance}）。
 * 由于不依赖于 {IERC20-approve}，代币持有者账户无需发送交易，因此也完全不需要持有以太币。
 */

/**
 *
 * EIP-712 的目标是为任何“类型化的结构数据”创建一个可验证的签名。为了实现这一点，它定义了一个统一的、可递归的哈希算法，我们称之为 hashStruct。
 * 任何一个结构体（struct）的哈希计算方式如下：
 *      hashStruct(结构体实例) = keccak256( abi.encode( typeHash, value1, value2, ... ) )
 * 其中：
 * typeHash: 是对“结构体类型定义”本身的哈希，即 keccak256("StructName(type1 member1,type2 member2,...)"。它唯一地标识了结构体的“骨架”。
 * value1, value2, ...: 是结构体实例中各个成员的实际值，按照定义顺序进行 abi.encode。
 *
 * 1. `_buildDomainSeparator` (域分隔符的哈希)
 * 它是什么？ 域分隔符本身就是对一个名叫 EIP712Domain 的特殊结构体的哈希。
 * 结构体类型定义: EIP712Domain(string name, string version, uint256 chainId, address verifyingContract)
 * TypeHash: keccak256("EIP712Domain(...)")，这正是 EIP712.sol 中的 TYPE_HASH 常量。
 * 成员的值: _hashedName, _hashedVersion, block.chainid, address(this)。（注意：根据规范，string 类型的成员需要先哈希一次再编码）。
 * 计算: keccak256(abi.encode(TYPE_HASH, _hashedName, ...))
 * 结论: _buildDomainSeparator 的计算完全遵循 hashStruct 规则。
 *
 * 2. `structHash` (Permit 许可的哈希)
 * 它是什么？ 它是对一个名叫 Permit 的应用层结构体的哈希。
 * 结构体类型定义: Permit(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
 * TypeHash: keccak256("Permit(...)")，这正是 ERC20Permit.sol 中的 PERMIT_TYPEHASH 常量。
 * 成员的值: owner, spender, value, _useNonce(owner), deadline。
 * 计算: keccak256(abi.encode(PERMIT_TYPEHASH, owner, ...))
 * 结论: structHash 的计算也完全遵循 hashStruct 规则。
 */

/**
 * StructName 这个名字本身并不是在 Solidity 代码中像 struct MyStruct { ... } 这样被明确“定义”的，
 * 它是由开发者在构造 `typeHash` 的那个字符串字面量中，自己约定的。
 * 换句话说，StructName 是您（开发者）为需要签名的那个数据结构所起的一个逻辑名称。
 * 客户端（例如用 ethers.js）和智能合约必须使用完全相同的 StructName 和字段定义字符串，这样它们才能计算出相同的哈希值，从而成功验证签名。
 *
 */
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712, Nonces {
    // 链下对象的结构,名称,类型,顺序必须和这里的PERMIT_TYPEHASH一致,否则链上链下计算出的 typeHash 就不同
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @dev 许可截止日期已过。
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev 签名者不匹配。
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @dev 使用 `name` 参数初始化 {EIP712} 域分隔符，并将 `version` 设置为 `"1"`。
     * 建议使用与 ERC-20 代币名称相同的 `name`。
     */
    constructor(string memory name) EIP712(name, "1") {}

    /// @inheritdoc IERC20Permit
    // 签名过程 (链下)：owner 在自己的钱包里（例如 MetaMask），用自己的私钥对这份“合同”的指紋 (hash) 进行签名。
    // 签名操作的输出就是 v, r, s这三个值。`v, r, s` 是 `owner` 私钥和 `hash` 结合的数学结果，是独一无二的授权凭证。
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        // 与链下同样的方式计算 EIP-712 的哈希。
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));
        bytes32 hash = _hashTypedDataV4(structHash);

        // 验证签名者是否为 owner。
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _approve(owner, spender, value);
    }

    /// @inheritdoc IERC20Permit
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /// @inheritdoc IERC20Permit
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
}
