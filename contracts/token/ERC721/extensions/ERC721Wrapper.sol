// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.1.0) (token/ERC721/extensions/ERC721Wrapper.sol)

pragma solidity ^0.8.24;

import {IERC721, ERC721} from "../ERC721.sol";
import {IERC721Receiver} from "../IERC721Receiver.sol";

/**
 * @dev ERC-721 代币合约的扩展，以支持代币包装。
 *
 * 用户可以存入和提取“底层代币”并接收具有匹配 tokenId 的“包装代币”。这
 * 与其他模块结合使用非常有用。例如，将此包装机制与 {ERC721Votes} 结合
 * 将允许将现有的“基本”ERC-721 包装成治理代币。
 */
abstract contract ERC721Wrapper is ERC721, IERC721Receiver {
    IERC721 private immutable _underlying;

    /**
     * @dev 接收到的 ERC-721 代币无法被包装。
     */
    error ERC721UnsupportedToken(address token);

    constructor(IERC721 underlyingToken) {
        _underlying = underlyingToken;
    }

    /**
     * @dev 允许用户存入底层代币并铸造相应的 tokenId。
     */
    function depositFor(address account, uint256[] memory tokenIds) public virtual returns (bool) {
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 tokenId = tokenIds[i];

            // 这是一个“不安全”的转移，不会在接收者上调用任何钩子。由于 underlying() 是受信任的
            // （根据此合约的设计），并且预计不会从那里调用其他合约，因此我们是安全的。
            // slither-disable-next-line reentrancy-no-eth
            underlying().transferFrom(_msgSender(), address(this), tokenId); // forge-lint: disable-line(erc20-unchecked-transfer)
            // 会调用onERC721Received函数
            _safeMint(account, tokenId);
        }

        return true;
    }

    /**
     * @dev 允许用户销毁包装代币并提取底层代币的相应tokenId。
     */
    function withdrawTo(address account, uint256[] memory tokenIds) public virtual returns (bool) {
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 tokenId = tokenIds[i];
            // 设置 "auth" 参数会启用 `_isAuthorized` 检查，
            // 该检查会验证代币是否存在(from != 0)。因此，此处无需验证返回值不为 0。
            _update(address(0), tokenId, _msgSender());
            // 此时已经执行了检查，并且在此之后无法从包装的 tokenId 中重新获得所有权或批准，
            // 因此为下一行移除重入检查是安全的。
            // slither-disable-next-line reentrancy-no-eth
            underlying().safeTransferFrom(address(this), account, tokenId);
        }

        return true;
    }

    /**
     * @dev 重写 {IERC721Receiver-onERC721Received} 以允许在直接向此合约进行 ERC-721 转移时进行铸造。
     * 如果附加了数据，它会验证操作员是此合约，因此只接受来自 {depositFor} 的受信任数据。
     * 警告：不适用于不安全的转移（例如 {IERC721-transferFrom}）。
     * 在这种情况下，使用 {ERC721Wrapper-_recover} 进行恢复。
     */
    function onERC721Received(address, address from, uint256 tokenId, bytes memory) public virtual returns (bytes4) {
        // 仅允许从 underlying() 进行的转移。
        if (address(underlying()) != _msgSender()) {
            revert ERC721UnsupportedToken(_msgSender());
        }
        // 铸造包装代币给 `from`。
        _safeMint(from, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev 铸造一个包装代币以覆盖任何可能被错误转移的 underlyingToken。
     * 如果需要，可以通过访问控制公开的内部函数。
     */
    function _recover(address account, uint256 tokenId) internal virtual returns (uint256) {
        address owner = underlying().ownerOf(tokenId);
        // 仅当此合约拥有底层代币时才允许恢复。
        if (owner != address(this)) {
            revert ERC721IncorrectOwner(address(this), tokenId, owner);
        }
        _safeMint(account, tokenId);
        return tokenId;
    }

    /**
     * @dev 返回底层代币。
     */
    function underlying() public view virtual returns (IERC721) {
        return _underlying;
    }
}
