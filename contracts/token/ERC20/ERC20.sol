// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IERC20Metadata} from "./extensions/IERC20Metadata.sol";
import {Context} from "../../utils/Context.sol";
import {IERC20Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev {IERC20} 接口的实现。
 * 这个实现与代币的创建方式无关。这意味着必须在派生合约中使用 {_mint} 添加供应机制。
 * 提示：有关详细的说明，请参阅我们的指南
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[如何实现供应机制]。
 * {decimals} 的默认值为 18。要更改此值，您应该重写此函数，使其返回不同的值。
 * 我们遵循了通用的 OpenZeppelin 合约指南：函数在失败时会还原，而不是返回 `false`。
 * 尽管如此，这种行为是常规的，并且不与 ERC-20 应用程序的期望冲突。
 */
/**
 * 从技术和编译器的角度来看，因为 IERC20Metadata 已经继承了 IERC20，所以 ERC20 合约在继承时只写 IERC20Metadata
 * 就足够了，编译器同样会要求它实现 IERC20 的所有函数。这么写主要是出于以下几个非技术性但至关重要的原因：
 *  清晰地表明核心意图（Clarity of Intent）
 *  提高代码可读性（Readability）
 *  代码的健壮性和未来的可维护性
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev 设置 {name} 和 {symbol} 的值。
     * 这两个值都是不可变的：它们只能在构造期间设置一次。
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev 返回代币的名称。
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev 返回代币的符号，通常是名称的缩写。
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev 返回用于获取其用户表示的小数位数。
     * 例如，如果 `decimals` 等于 `2`，则 `505` 个代币的余额应向用户显示为 `5.05` (`505 / 10 ** 2`)。
     * 代币通常选择值为 18，模仿以太币和 Wei 之间的关系。这是此函数返回的默认值，除非被重写。
     * 注意：此信息仅用于_显示_目的：它绝不会影响合约的任何算术，包括 {IERC20-balanceOf} 和 {IERC20-transfer}。
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /// @inheritdoc IERC20
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev 参见 {IERC20-transfer}。
     * 要求：
     * - `to` 不能是零地址。
     * - 调用者必须拥有至少 `value` 的余额。
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /// @inheritdoc IERC20
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev 参见 {IERC20-approve}。
     * 注意：如果 `value` 是 `uint256` 的最大值，则在 `transferFrom` 上不会更新津贴。这在语义上等同于无限批准。
     * 要求：
     * - `spender` 不能是零地址。
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev 参见 {IERC20-transferFrom}。
     * 跳过发出指示津贴更新的 {Approval} 事件。这不是 ERC 所要求的。请参阅 {xref-ERC20-_approve-address-address-uint256-bool-}[_approve]。
     * 注意：如果当前津贴是 `uint256` 的最大值，则不更新津贴。
     * 要求：
     * - `from` 和 `to` 不能是零地址。
     * - `from` 必须拥有至少 `value` 的余额。
     * - 调用者必须拥有至少 `value` 的 `from` 代币津贴。
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev 将 `value` 数量的代币从 `from` 移至 `to`。
     * 此内部函数等效于 {transfer}，可用于例如实现自动代币费用、削减机制等。
     * 发出 {Transfer} 事件。
     * 注意：此函数不是虚拟的，应重写 {_update}。
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev 将 `value` 数量的代币从 `from` 转移到 `to`，或者如果 `from`（或 `to`）是零地址，则或者铸造（或销毁）。
     * 对转账、铸造和销毁的所有自定义都应通过重写此函数来完成。
     * 发出 {Transfer} 事件。
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev 创建 `value` 数量的代币并将其分配给 `account`，方法是从 address(0) 转移。
     * 依赖于 `_update` 机制
     * 发出 `from` 设置为零地址的 {Transfer} 事件。
     * 注意：此函数不是虚拟的，应重写 {_update}。
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev 从 `account` 销毁 `value` 数量的代币，从而降低总供应量。
     * 依赖于 `_update` 机制。
     * 发出 `to` 设置为零地址的 {Transfer} 事件。
     * 注意：此函数不是虚拟的，应重写 {_update}。
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev 将 `value` 设置为 `spender` 对 `owner` 代币的津贴。
     * 此内部函数等效于 `approve`，可用于例如为某些子系统设置自动津贴等。
     * 发出 {Approval} 事件。
     * 要求：
     * - `owner` 不能是零地址。
     * - `spender` 不能是零地址。
     * 对此逻辑的重写应针对带有附加 `bool emitEvent` 参数的变体进行。
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev {_approve} 的变体，带有一个可选标志以启用或禁用 {Approval} 事件。
     *
     * 默认情况下（调用 {_approve} 时），该标志设置为 true。另一方面，
     * `_spendAllowance` 在 `transferFrom` 操作期间所做的批准更改会将该标志设置为 false。
     * 这通过在 `transferFrom` 操作期间不发出任何 `Approval` 事件来节省 gas。
     * 任何希望在 `transferFrom` 操作上继续发出 `Approval` 事件的人都可以使用以下重写将标志强制为 true：
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     * 要求与 {_approve} 相同。
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev 根据花费的 `value` 更新 `owner` 对 `spender` 的津贴。
     * 在无限津贴的情况下不更新津贴值。如果津贴不足，则还原。
     * 不发出 {Approval} 事件。
     *
     * 消费 `value` 个 `owner` 对 `spender` 的津贴。
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
