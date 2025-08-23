// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

pragma solidity >=0.4.16;

/**
 * @dev ERC-165 标准的接口，如 https://eips.ethereum.org/EIPS/eip-165[ERC] 中所定义。
 *
 * 实现者可以声明对合约接口的支持，然后可以被其他人 ({ERC165Checker}) 查询。
 *
 * 有关实现，请参阅 {ERC165}。
 */
interface IERC165 {
    /**
     * @dev 如果此合约实现了 `interfaceId` 定义的接口，则返回 true。
     * 请参阅相应的 https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC 部分]
     * 以了解这些 id 是如何创建的。
     *
     * 此函数调用必须使用少于 30,000 gas。
     * 因此，这个限制不是由 Solidity 编译器或 EVM 在函数内部直接检查并强制执行的，而是一个由标准定义、由调用者通过 gas limit
     *      间接强制执行，并由整个生态系统（包括开发者、审计师和工具）共同维护的约定。
     *
     * 1. 防止拒绝服务攻击 (DoS)：如果没有 gas 限制，恶意合约可能会实现一个消耗大量 gas 的 supportsInterface
     *      函数。当其他合约尝试查询其支持的接口时，这将导致高昂的 gas 成本，甚至可能使查询失败，从而造成拒绝服务。
     * 2. 确保效率和低成本：ERC-165 的目的是提供一种轻量级且高效的方式来查询合约是否支持特定接口。30,000 gas
     *      的限制确保了接口检测操作始终是廉价且快速的，不会成为合约交互的负担。
     * 3. 链上互操作性：通过设定统一的 gas 限制，所有符合 ERC-165 标准的合约都能以可预测的成本进行接口查询，这对于链上互操作性至关重要。
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
