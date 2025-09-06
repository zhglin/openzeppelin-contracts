// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.0.0) (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.20;

import {IERC721Receiver} from "../IERC721Receiver.sol";

/**
 * @dev {IERC721Receiver} 接口的实现。
 *
 * 接受所有代币转移。
 * 确保合约能够使用其代币，通过 {IERC721-safeTransferFrom}、{IERC721-approve} 或
 * {IERC721-setApprovalForAll}。
 */
abstract contract ERC721Holder is IERC721Receiver {
    /**
     * @dev 参见 {IERC721Receiver-onERC721Received}。
     * 总是返回 `IERC721Receiver.onERC721Received.selector`。
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
