// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.3.0) (token/ERC6909/draft-ERC6909.sol)

pragma solidity ^0.8.20;

import {IERC6909} from "../../interfaces/draft-IERC6909.sol";
import {Context} from "../../utils/Context.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";

/**
 * 为什么ERC6909不再是个抽象合约?
 *  一个合约在技术上是否为 abstract，只取决于一件事：它是否有未实现的函数。
 *  如果有任何未实现的函数（即没有函数体的函数），那么合约就是 abstract，不能被部署。
 *  你可以把 ERC6909.sol 的代码直接复制到 Remix 里，它是可以被成功编译和部署的。
 *  ERC721.sol 和 ERC1155.sol 在设计上就是不完整的框架，它们把一些关键部分（如 constructor 的参数、公开的 mint逻辑）留给开发者，因此是抽象合约。
 * 
 *  ERC6909 则不同，它被设计成一个“开箱即用”的、功能完备的多代币账本。
 *      1. 接口的完整实现：
 *          ERC6909.sol 这个合约完整地实现了 IERC6909 接口中定义的所有函数（balanceOf, allowance, approve, transfer, transferFrom等）。它没有任何未实现的函数。
 *      2. 无构造函数参数：
 *          基础的 ERC6909 合约没有 constructor，它不需要 name 或 symbol 这样的全局元数据。
 *          在 ERC6909 的世界里，元数据是通过可选的扩展接口（如IERC6909Metadata）为每一个 id 单独设置的。因此，这个基础合约不需要任何初始参数就能部署。
 *      3. 设计定位不同：
 *          ERC6909 的定位更像一个纯粹的、通用的“多资产记账本”。它的核心逻辑（谁拥有多少个什么ID的代币，授权了多少）是自洽且完备的。
 * 
 * `ERC6909`：像是一辆“功能齐全的基础款汽车”。它已经是一辆完整的车了，可以直接开上路（可以直接部署和使用）。你当然也可以对它进行改装，
 * 增加更多功能（比如继承它并添加复杂的铸币权限控制），但它本身已经是完备的了。
 * 
 * 你可能会想：“如果我必须通过继承来给 ERC6909 添加 mint 功能才能让它变得有用，那它和也需要被继承的 ERC721 又有什么本质区别呢？”
 *  这里的区别在于“继承的目的”。
 *      ERC721 的继承是为了补完一个框架。
 *      ERC6909 的继承是为了给一个已完备的基础模块添加业务逻辑。 
 *  两者虽然都用到了继承，但其出发点和合约本身的完备性是完全不同的。      
 */

/**
 * ERC6909 和 ERC1155 的主要区别:
 * ERC1155: 只有一种“一揽子”授权方式 setApprovalForAll。你要么授权一个操作员（比如 OpenSea）可以动你所有的 NFT，要么不授权。
 * 你不能说：“我只授权 OpenSea 卖我 10 个 id=1 的金币”。
 * 这种设计对于需要精细额度控制的 DeFi应用（如去中心化交易所、借贷协议）来说非常不便，甚至存在安全风险。
 * 它的强大之处在于能同时处理 FT 和 NFT。
 * 非常适合游戏领域，比如一个游戏角色可以同时拥有 100瓶可叠加的“红药水”（FT）和一把独一无二的“传奇之剑”（NFT）。
 * 
 * ERC6909: 提供了两种授权方式，完美复刻了 ERC20 的模式：
       1. `approve(spender, id, amount)`: 精细化授权。你可以像操作 ERC20 一样，授权某个 spender 可以动你指定 id 的代币，数量不超过 amount。
       2. `setOperator(spender, approved)`: 全局操作员授权。这和 ERC1155 的 setApprovalForAll 功能一样。
 * 这个区别使得 ERC6909 可以非常容易地被集成到现有的、为 ERC20 设计的 DeFi 生态中。
 * 它完全专注于可替代代币（FT）。非常适合需要在一个合约中管理多种不同代币资产的场景，
 * 比如一个去中心化交易所的流动性池凭证（LPToken），或者一个多资产的资金管理平台。
 *   
 */

/**
 * @dev ERC-6909 的实现。
 * 参见 https://eips.ethereum.org/EIPS/eip-6909
 */
contract ERC6909 is Context, ERC165, IERC6909 {
    // owner => id => balance
    mapping(address owner => mapping(uint256 id => uint256)) private _balances;

    // owner => operator => approved
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    // owner => spender => id => allowance
    mapping(address owner => mapping    (address spender => mapping(uint256 id => uint256))) private _allowances;

    error ERC6909InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 id);
    error ERC6909InsufficientAllowance(address spender, uint256 allowance, uint256 needed, uint256 id);
    error ERC6909InvalidApprover(address approver);
    error ERC6909InvalidReceiver(address receiver);
    error ERC6909InvalidSender(address sender);
    error ERC6909InvalidSpender(address spender);

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC6909).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC6909
    function balanceOf(address owner, uint256 id) public view virtual override returns (uint256) {
        return _balances[owner][id];
    }

    /// @inheritdoc IERC6909
    function allowance(address owner, address spender, uint256 id) public view virtual override returns (uint256) {
        return _allowances[owner][spender][id];
    }

    /// @inheritdoc IERC6909
    function isOperator(address owner, address spender) public view virtual override returns (bool) {
        return _operatorApprovals[owner][spender];
    }

    /// @inheritdoc IERC6909
    function approve(address spender, uint256 id, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    function setOperator(address spender, bool approved) public virtual override returns (bool) {
        _setOperator(_msgSender(), spender, approved);
        return true;
    }

    /// @inheritdoc IERC6909
    function transfer(address receiver, uint256 id, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), receiver, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    function transferFrom(
        address sender,
        address receiver,
        uint256 id,
        uint256 amount
    ) public virtual override returns (bool) {
        address caller = _msgSender();
        if (sender != caller && !isOperator(sender, caller)) {
            // 减去授权额度
            _spendAllowance(sender, caller, id, amount);
        }
        _transfer(sender, receiver, id, amount);
        return true;
    }

    /**
     * @dev 创建 `amount` 数量的 `id` 类型代币，并将其分配给 `account`，通过从 address(0) 转移实现。
     * 依赖于 `_update` 机制。
     * 发出 {Transfer} 事件，其中 `from` 设置为零地址。
     * 注意：此函数不是虚拟的，应改为重写 {_update}。
     */
    function _mint(address to, uint256 id, uint256 amount) internal {
        if (to == address(0)) {
            revert ERC6909InvalidReceiver(address(0));
        }
        _update(address(0), to, id, amount);
    }

    /**
     * @dev 将 `amount` 数量的 `id` 类型代币从 `from` 移动到 `to`，不检查批准。此函数验证
     * 发送者和接收者都不是 address(0)，这意味着它不能铸造或销毁代币。
     * 依赖于 `_update` 机制。
     * 发出 {Transfer} 事件。
     * 注意：此函数不是虚拟的，应改为重写 {_update}。
     */
    function _transfer(address from, address to, uint256 id, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC6909InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC6909InvalidReceiver(address(0));
        }
        _update(from, to, id, amount);
    }

    /**
     * @dev 从 `account` 销毁 `amount` 数量的 `id` 类型代币。
     * 依赖于 `_update` 机制。
     * 发出 {Transfer} 事件，其中 `to` 设置为零地址。
     * 注意：此函数不是虚拟的，应改为重写 {_update}。
     */
    function _burn(address from, uint256 id, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC6909InvalidSender(address(0));
        }
        _update(from, address(0), id, amount);
    }

    /**
     * @dev 将 `amount` 数量的 `id` 类型代币从 `from` 转移到 `to`，或者如果 `from`
     * （或 `to`）是零地址，则铸造（或销毁）。所有对转移、铸造和销毁的自定义都应通过重写此函数来完成。
     * 发出 {Transfer} 事件。
     */
    function _update(address from, address to, uint256 id, uint256 amount) internal virtual {
        address caller = _msgSender();

        if (from != address(0)) {
            uint256 fromBalance = _balances[from][id];
            if (fromBalance < amount) {
                revert ERC6909InsufficientBalance(from, fromBalance, amount, id);
            }
            unchecked {
                // 不可能溢出：amount <= fromBalance。
                _balances[from][id] = fromBalance - amount;
            }
        }
        if (to != address(0)) {
            _balances[to][id] += amount;
        }

        emit Transfer(caller, from, to, id, amount);
    }

    /**
     * @dev 将 `spender` 对 `owner` 的 `id` 类型代币的授权额度设置为 `amount`。
     * 此内部函数等同于 `approve`，可用于例如为某些子系统等设置自动授权额度。
     * 发出 {Approval} 事件。
     * 要求：
     * - `owner` 不能是零地址。
     * - `spender` 不能是零地址。
     */
    function _approve(address owner, address spender, uint256 id, uint256 amount) internal virtual {
        if (owner == address(0)) {
            revert ERC6909InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC6909InvalidSpender(address(0));
        }
        _allowances[owner][spender][id] = amount;
        emit Approval(owner, spender, id, amount);
    }

    /**
     * @dev 批准 `spender` 操作 `owner` 的所有代币。
     * 此内部函数等同于 `setOperator`，可用于例如为某些子系统等设置自动授权额度。
     * 发出 {OperatorSet} 事件。
     * 要求：
     * - `owner` 不能是零地址。
     * - `spender` 不能是零地址。
     */
    function _setOperator(address owner, address spender, bool approved) internal virtual {
        if (owner == address(0)) {
            revert ERC6909InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC6909InvalidSpender(address(0));
        }
        _operatorApprovals[owner][spender] = approved;
        emit OperatorSet(owner, spender, approved);
    }

    /**
     * @dev 根据花费的 `amount` 更新 `owner` 对 `spender` 的授权额度。
     * 在无限授权额度的情况下不更新授权额度值。
     * 如果没有足够的授权额度，则回滚。
     * 不发出 {Approval} 事件。
     */
    function _spendAllowance(address owner, address spender, uint256 id, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender, id);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC6909InsufficientAllowance(spender, currentAllowance, amount, id);
            }
            unchecked {
                _allowances[owner][spender][id] = currentAllowance - amount;
            }
        }
    }
}
