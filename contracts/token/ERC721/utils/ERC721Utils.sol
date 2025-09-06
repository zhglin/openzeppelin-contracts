// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC721/utils/ERC721Utils.sol)

pragma solidity ^0.8.20;

import {IERC721Receiver} from "../IERC721Receiver.sol";
import {IERC721Errors} from "../../../interfaces/draft-IERC6093.sol";

/**
 * @dev 提供通用 ERC-721 实用函数的库。
 *
 * 参见 https://eips.ethereum.org/EIPS/eip-721[ERC-721]。
 *
 * _自 v5.1 起可用。_
 */
library ERC721Utils {
    /**
     * @dev 通过在 `to` 地址上调用 {IERC721Receiver-onERC721Received} 来为提供的 `operator` 执行接受检查。
     * `operator` 通常是发起代币转移的地址 (即 `msg.sender`)。
     *
     * 如果目标地址不包含代码 (即 EOA)，则不执行接受调用并将其视为空操作。
     * 否则，接收者必须实现 {IERC721Receiver-onERC721Received} 并返回函数选择器以接受转移。
     */
    function checkOnERC721Received(
        address operator,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(operator, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    // 代币被拒绝
                    revert IERC721Errors.ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // 非 IERC721Receiver 实现者
                    revert IERC721Errors.ERC721InvalidReceiver(to);
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
    }
}
