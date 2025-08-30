// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363Receiver.sol)

pragma solidity >=0.5.0;

/**
 * @title IERC1363Receiver
 * @dev 为任何希望支持来自 ERC-1363 代币合约的 `transferAndCall` 或 `transferFromAndCall` 功能的合约提供的接口。
 */
interface IERC1363Receiver {
    /**
     * @dev 每当 ERC-1363 代币通过 `transferAndCall` 或 `transferFromAndCall` 由 `operator` 从 `from` 地址转移到此合约时，
     * 此函数就会被调用。
     *
     * 注意：要接受转账，此函数必须返回
     * `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))`
     * （即 0x88a7ca5c，或其自身的函数选择器）。
     *
     * @param operator 调用 `transferAndCall` 或 `transferFromAndCall` 函数的地址。
     * @param from 代币的转出地址。
     * @param value 转移的代币数量。
     * @param data 附加数据，无特定格式。
     * @return 如果允许转账（除非抛出异常），则返回 `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))`。
     */
    function onTransferReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}
