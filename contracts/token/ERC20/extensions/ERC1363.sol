// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/ERC1363.sol)

pragma solidity ^0.8.20;

import {ERC20} from "../ERC20.sol";
import {IERC165, ERC165} from "../../../utils/introspection/ERC165.sol";
import {IERC1363} from "../../../interfaces/IERC1363.sol";
import {ERC1363Utils} from "../utils/ERC1363Utils.sol";

/**
 * @title ERC1363
 * @dev {ERC20} 代币的扩展，增加了在接收者合约上进行转账和批准后执行代码的支持。
 * 转账后的调用通过 {ERC1363-transferAndCall} 和 {ERC1363-transferFromAndCall} 方法启用，
 * 而批准后的调用可以使用 {ERC1363-approveAndCall} 进行。
 *
 * _自 v5.1 版起可用。_
 */
abstract contract ERC1363 is ERC20, ERC165, IERC1363 {
    /**
     * @dev 表示 transferAndCall 操作的 {transfer} 部分失败。
     * @param receiver 接收代币的地址。
     * @param value 要转移的代币数量。
     */
    error ERC1363TransferFailed(address receiver, uint256 value);

    /**
     * @dev 表示 transferFromAndCall 操作的 {transferFrom} 部分失败。
     * @param sender 发送代币的地址。
     * @param receiver 接收代币的地址。
     * @param value 要转移的代币数量。
     */
    error ERC1363TransferFromFailed(address sender, address receiver, uint256 value);

    /**
     * @dev 表示 approveAndCall 操作的 {approve} 部分失败。
     * @param spender 将花费资金的地址。
     * @param value 要花费的代币数量。
     */
    error ERC1363ApproveFailed(address spender, uint256 value);

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1363).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev 将 `value` 数量的代币从调用者的账户移动到 `to`，
     * 然后在 `to` 上调用 {IERC1363Receiver-onTransferReceived}。返回一个标志，指示
     * 调用是否成功。
     *
     * 要求：
     * - 目标有代码（即是合约）。
     * - 目标 `to` 必须实现 {IERC1363Receiver} 接口。
     * - 目标必须返回 {IERC1363Receiver-onTransferReceived} 选择器以接受转账。
     * - 内部 {transfer} 必须成功（返回 `true`）。
     */
    function transferAndCall(address to, uint256 value) public returns (bool) {
        return transferAndCall(to, value, "");
    }

    /**
     * @dev {transferAndCall} 的变体，接受一个没有指定格式的额外 `data` 参数。
     */
    function transferAndCall(address to, uint256 value, bytes memory data) public virtual returns (bool) {
        if (!transfer(to, value)) {
            revert ERC1363TransferFailed(to, value);
        }
        ERC1363Utils.checkOnERC1363TransferReceived(_msgSender(), _msgSender(), to, value, data);
        return true;
    }

    /**
     * @dev 使用授权机制将 `value` 数量的代币从 `from` 移动到 `to`，
     * 然后在 `to` 上调用 {IERC1363Receiver-onTransferReceived}。返回一个标志，指示
     * 调用是否成功。
     *
     * 要求：
     * - 目标有代码（即是合约）。
     * - 目标 `to` 必须实现 {IERC1363Receiver} 接口。
     * - 目标必须返回 {IERC1363Receiver-onTransferReceived} 选择器以接受转账。
     * - 内部 {transferFrom} 必须成功（返回 `true`）。
     */
    function transferFromAndCall(address from, address to, uint256 value) public returns (bool) {
        return transferFromAndCall(from, to, value, "");
    }

    /**
     * @dev {transferFromAndCall} 的变体，接受一个没有指定格式的额外 `data` 参数。
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) public virtual returns (bool) {
        if (!transferFrom(from, to, value)) {
            revert ERC1363TransferFromFailed(from, to, value);
        }
        ERC1363Utils.checkOnERC1363TransferReceived(_msgSender(), from, to, value, data);
        return true;
    }

    /**
     * @dev 将 `value` 数量的代币设置为 `spender` 对调用者代币的授权额度，
     * 然后在 `spender` 上调用 {IERC1363Spender-onApprovalReceived}。
     * 返回一个标志，指示调用是否成功。
     *
     * 要求：
     * - 目标有代码（即是合约）。
     * - 目标 `spender` 必须实现 {IERC1363Spender} 接口。
     * - 目标必须返回 {IERC1363Spender-onApprovalReceived} 选择器以接受批准。
     * - 内部 {approve} 必须成功（返回 `true`）。
     */
    function approveAndCall(address spender, uint256 value) public returns (bool) {
        return approveAndCall(spender, value, "");
    }

    /**
     * @dev {approveAndCall} 的变体，接受一个没有指定格式的额外 `data` 参数。
     */
    function approveAndCall(address spender, uint256 value, bytes memory data) public virtual returns (bool) {
        if (!approve(spender, value)) {
            revert ERC1363ApproveFailed(spender, value);
        }
        ERC1363Utils.checkOnERC1363ApprovalReceived(_msgSender(), spender, value, data);
        return true;
    }
}
