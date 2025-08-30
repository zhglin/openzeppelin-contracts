// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/extensions/draft-ERC20TemporaryApproval.sol)

pragma solidity ^0.8.24;

import {IERC20, ERC20} from "../ERC20.sol";
import {IERC7674} from "../../../interfaces/draft-IERC7674.sol";
import {Math} from "../../../utils/math/Math.sol";
import {SlotDerivation} from "../../../utils/SlotDerivation.sol";
import {TransientSlot} from "../../../utils/TransientSlot.sol";

/**
 * @dev {ERC20} 的扩展，增加了对遵循 ERC-7674 的临时授权的支持。
 * 警告：这是一个草案合约。相应的 ERC 仍可能会有变动。
 *
 * _自 v5.1 版起可用。_
 * 
 * temporaryApprove 的核心思想是：授权和花费在同一笔交易（Transaction）中原子化地完成，授权的生命周期仅限于这笔交易。
 *  极高的安全性: 授权“阅后即焚”，没有任何残留。交易一结束，外部合约就再也没有权限动用你的资金，彻底消除了“无限授权”的风险。
 *  极佳的用户体验: 用户只需签名并发送一笔交易即可完成所有操作，流程大大简化，快速且方便。
 *  极低的 Gas 成本: 由于授权是临时的，存储在瞬态存储 (Transient Storage) 中，交易结束后自动清除，不会产生任何持久化存储成本。
 * 
 * 用户只需要发起一笔交易，这笔交易会像一个脚本一样，按顺序执行以下两个步骤：
 *  步骤一：临时授权
 *      交易首先调用 DAI 合约的 temporaryApprove 函数，授权给 DEX 路由合约可以花费 100 个 DAI。
 *      这个授权被记录在瞬时存储 (Transient Storage) 中，它的生命周期仅限于当前这笔交易。
 *  步骤二：执行兑换
 *      交易接着立即调用 DEX 路由合约的 swap 函数。
 *      swap 函数内部调用 transferFrom 来花费你的 100 个 DAI。由于上一步的临时授权在当前交易中有效，所以这一步会成功执行。
 */
abstract contract ERC20TemporaryApproval is ERC20, IERC7674 {
    using SlotDerivation for bytes32;
    using TransientSlot for bytes32;
    using TransientSlot for TransientSlot.Uint256Slot;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20_TEMPORARY_APPROVAL_STORAGE")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20_TEMPORARY_APPROVAL_STORAGE =
        0xea2d0e77a01400d0111492b1321103eed560d8fe44b9a7c2410407714583c400;

    /**
     * @dev {allowance} 的重写版本，在查询当前授权时会包含临时授权。如果
     * 永久授权和临时授权相加导致溢出，则返回 type(uint256).max。
     */
    function allowance(address owner, address spender) public view virtual override(IERC20, ERC20) returns (uint256) {
        (bool success, uint256 amount) = Math.tryAdd(
            super.allowance(owner, spender),
            _temporaryAllowance(owner, spender)
        );
        return success ? amount : type(uint256).max;
    }

    /**
     * @dev 用于获取 `spender` 对 `owner` 代币当前临时授权额度的内部 getter 函数。
     */
    function _temporaryAllowance(address owner, address spender) internal view virtual returns (uint256) {
        return _temporaryAllowanceSlot(owner, spender).tload();
    }

    /**
     * @dev {approve} 的替代方案，它将 `value` 数量的代币设置为 `spender` 对调用者代币的临时授权。
     * 返回一个布尔值，表示操作是否成功。
     * 要求：
     * - `spender` 不能是零地址。
     * 不会发出 {Approval} 事件。
     */
    function temporaryApprove(address spender, uint256 value) public virtual returns (bool) {
        _temporaryApprove(_msgSender(), spender, value);
        return true;
    }

    /**
     * @dev 将 `value` 设置为 `spender` 对 `owner` 代币的临时授权。
     * 这个内部函数等同于 `temporaryApprove`，可以用于例如为某些子系统设置自动授权等。
     * 要求：
     * - `owner` 不能是零地址。
     * - `spender` 不能是零地址。
     * 不会发出 {Approval} 事件。
     */
    function _temporaryApprove(address owner, address spender, uint256 value) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _temporaryAllowanceSlot(owner, spender).tstore(value);
    }

    /**
     * @dev {_spendAllowance} 的重写版本，它会先消耗临时授权（如果有的话），
     * 然后才会回退到消耗永久授权。
     * 注意：如果临时授权足以覆盖本次花费，此函数将跳过对 `super._spendAllowance` 的调用。
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual override {
        // 加载瞬时授权
        uint256 currentTemporaryAllowance = _temporaryAllowance(owner, spender);

        // 检查并更新（如果需要）临时授权 + 设置剩余值
        if (currentTemporaryAllowance > 0) {
            // 所有花费都被无限授权覆盖。没有剩余的花费，我们可以提前返回
            if (currentTemporaryAllowance == type(uint256).max) {
                return;
            }
            // 检查有多少花费被瞬时授权覆盖
            uint256 spendTemporaryAllowance = Math.min(currentTemporaryAllowance, value);
            unchecked {
                // 相应地减少瞬时授权
                _temporaryApprove(owner, spender, currentTemporaryAllowance - spendTemporaryAllowance);
                // 更新必要的值
                value -= spendTemporaryAllowance;
            }
        }
        // 从永久授权中扣除任何剩余的值
        if (value > 0) {
            super._spendAllowance(owner, spender, value);
        }
    }

    // 派生出给定所有者和支出者的临时授权槽 mapping[owner][spender] => uint256
    function _temporaryAllowanceSlot(address owner, address spender) private pure returns (TransientSlot.Uint256Slot) {
        return ERC20_TEMPORARY_APPROVAL_STORAGE.deriveMapping(owner).deriveMapping(spender).asUint256();
    }
}
