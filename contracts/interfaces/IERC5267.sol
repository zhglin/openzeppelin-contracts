// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC5267.sol)

pragma solidity >=0.4.16;

// 接口的主要作用是为智能合约提供一个标准化的方式，来公开其 EIP-712 签名所使用的域分隔符（Domain Separator）信息。
interface IERC5267 {
    /**
     * @dev 可能会发出此事件，以表示域可能已更改。
     * 这对于那些会缓存域信息的链下服务非常重要，它们在收到此事件后需要重新获取最新的域信息。
     */
    event EIP712DomainChanged();

    /**
     * @dev 返回描述此合约用于 EIP-712 签名的域分隔符的字段和值。
     * 通过提供这些信息，外部应用可以正确地构造 EIP-712 签名请求，并确保用户签署的数据是针对正确的合约和上下文。
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}
