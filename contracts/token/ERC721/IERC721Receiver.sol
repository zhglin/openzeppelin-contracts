// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity >=0.5.0;

/**
 * @title ERC-721 代币接收者接口
 * @dev 任何希望支持从 ERC-721 资产合约进行 safeTransfers 的合约的接口。
 */
interface IERC721Receiver {
    /**
     * @dev 每当一个 {IERC721} `tokenId` 代币通过 {IERC721-safeTransferFrom} 由 `operator` 从 `from` 转移到此合约时，
     * 此函数就会被调用。
     *
     * 它必须返回其 Solidity 选择器以确认代币转移。
     * 如果返回任何其他值或接收者未实现该接口，则转移将被回滚。
     *
     * 在 Solidity 中可以使用 `IERC721Receiver.onERC721Received.selector` 获取选择器。
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
