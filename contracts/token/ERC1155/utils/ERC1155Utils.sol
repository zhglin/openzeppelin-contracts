// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC1155/utils/ERC1155Utils.sol)

pragma solidity ^0.8.20;

import {IERC1155Receiver} from "../IERC1155Receiver.sol";
import {IERC1155Errors} from "../../../interfaces/draft-IERC6093.sol";

/**
 * @dev 提供通用 ERC-1155 实用函数的库。
 *
 * 参见 https://eips.ethereum.org/EIPS/eip-1155[ERC-1155]。
 *
 * _自 v5.1 起可用。_
 */
library ERC1155Utils {
    /**
     * @dev 通过在 `to` 地址上调用 {IERC1155Receiver-onERC1155Received} 来为提供的 `operator` 执行接受检查。
     * `operator` 通常是发起代币转移的地址 (即 `msg.sender`)。
     *
     * 如果目标地址不包含代码 (即 EOA)，则不执行接受调用并将其视为空操作。
     * 否则，接收者必须实现 {IERC1155Receiver-onERC1155Received} 并返回接受魔法值以接受转移。
     */
    function checkOnERC1155Received(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, value, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    // 代币被拒绝
                    revert IERC1155Errors.ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // 非 IERC1155Receiver 实现者
                    revert IERC1155Errors.ERC1155InvalidReceiver(to);
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev 通过在 `to` 地址上调用 {IERC1155Receiver-onERC1155BatchReceived} 来为提供的 `operator` 执行批量接受检查。
     * `operator` 通常是发起代币转移的地址 (即 `msg.sender`)。
     *
     * 如果目标地址不包含代码 (即 EOA)，则不执行接受调用并将其视为空操作。
     * 否则，接收者必须实现 {IERC1155Receiver-onERC1155Received} 并返回接受魔法值以接受转移。
     */
    function checkOnERC1155BatchReceived(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, values, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    // 代币被拒绝
                    revert IERC1155Errors.ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // 非 IERC1155Receiver 实现者
                    revert IERC1155Errors.ERC1155InvalidReceiver(to);
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
    }
}
