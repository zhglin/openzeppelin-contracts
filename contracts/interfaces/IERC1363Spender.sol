// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363Spender.sol)

pragma solidity >=0.5.0;

/**
 * @title IERC1363Spender
 * @dev 为任何希望支持来自 ERC-1363 代币合约的 `approveAndCall` 功能的合约提供的接口。
 */
interface IERC1363Spender {
    /**
     * @dev 每当一个 ERC-1363 代币的 `owner` 通过 `approveAndCall` 授权此合约花费其代币时，
     * 此函数就会被调用。
     *
     * 注意：要接受授权，此函数必须返回
     * `bytes4(keccak256("onApprovalReceived(address,uint256,bytes)"))`
     * （即 0x7b04a2d0，或其自身的函数选择器）。
     *
     * @param owner 调用 `approveAndCall` 函数并曾拥有这些代币的地址。
     * @param value 将要花费的代币数量。
     * @param data 附加数据，无特定格式。
     * @return 如果允许授权（除非抛出异常），则返回 `bytes4(keccak256("onApprovalReceived(address,uint256,bytes)"))`。
     */
    function onApprovalReceived(address owner, uint256 value, bytes calldata data) external returns (bytes4);
}
