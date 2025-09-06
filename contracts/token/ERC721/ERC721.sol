// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.24;

import {IERC721} from "./IERC721.sol";
import {IERC721Metadata} from "./extensions/IERC721Metadata.sol";
import {ERC721Utils} from "./utils/ERC721Utils.sol";
import {Context} from "../../utils/Context.sol";
import {Strings} from "../../utils/Strings.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";
import {IERC721Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-721[ERC-721] 非同质化代币标准的实现，
 * 包括元数据扩展，但不包括可枚举扩展（可单独作为 {ERC721Enumerable} 使用）。
 */
abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    // 代币名称
    string private _name;

    // 代币符号
    string private _symbol;

    // tokenId 代币所有者
    mapping(uint256 tokenId => address) private _owners;

    // 账户中token数量（所有者地址 => 数量）
    mapping(address owner => uint256) private _balances;

    // tokenId 代币的授权地址
    mapping(uint256 tokenId => address) private _tokenApprovals;

    // 账户授权的操作员（所有者地址 => (操作员地址 => 是否授权)）
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    /**
     * @dev 通过为代币集合设置 `name` 和 `symbol` 来初始化合约。
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC721
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    /// @inheritdoc IERC721Metadata
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /// @inheritdoc IERC721Metadata
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /**
     * @dev 用于计算 {tokenURI} 的基础 URI。如果设置，每个代币的最终 URI
     * 将是 `baseURI` 和 `tokenId` 的串联。默认为空，
     * 可以在子合约中重写。
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender());
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // 设置 "auth" 参数会启用 `_isAuthorized` 检查，该检查会验证代币是否存在
        // (from != 0)。因此，此处无需验证返回值不为 0。
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
    }

    /**
     * @dev 返回 `tokenId` 的所有者。如果代币不存在，则不会回滚。
     *
     * 重要提示：任何对此函数的重写，如果添加了不由核心 ERC-721 逻辑跟踪的代币所有权，
     * 都必须与 {_increaseBalance} 的使用相匹配，以保持余额与所有权的一致性。
     * 需要保留的不变性是：对于任何地址 `a`，`balanceOf(a)` 返回的值必须等于
     * 使得 `_ownerOf(tokenId)` 为 `a` 的代币数量。
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev 返回 `tokenId` 的授权地址。如果 `tokenId` 未被铸造，则返回 0。
     */
    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev 返回 `spender` 是否被允许管理 `owner` 的代币，或特别是 `tokenId`
     * （忽略它是否由 `owner` 拥有）。
     *
     * 警告：此函数假定 `owner` 是 `tokenId` 的实际所有者，并且不验证此假设。
     */
    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    /**
     * @dev 检查 `spender` 是否可以操作 `tokenId`，假定提供的 `owner` 是实际所有者。
     * 如果出现以下情况则回滚：
     * - `spender` 没有 `owner` 对 `tokenId` 的授权。
     * - `spender` 没有管理 `owner` 所有资产的授权。
     *
     * 警告：此函数假定 `owner` 是 `tokenId` 的实际所有者，并且不验证此假设。
     */
    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    /**
     * @dev 对余额的不安全写访问，供使用 {ownerOf} 重写来“铸造”代币的扩展使用。
     *
     * 注意：该值被限制为 type(uint128).max。这可以防止余额溢出。
     * 当增量被限制为 uint128 值时，uint256 因增量而溢出是不现实的。
     *
     * 警告：使用此函数增加账户余额通常需要与重写 {_ownerOf} 函数配对，
     * 以解析相应代币的所有权，从而使余额和所有权保持一致。
     * 
     * “不安全写访问”主要是因为它只更新了账户的代币余额计数，但没有相应地处理代币的所有权归属。
     *  破坏数据一致性：在标准的 ERC-721 合约中，一个账户的余额 (balanceOf) 必须严格等于它实际拥有 (ownerOf) 的代币数量。
     *  调用者的责任：该函数是内部（internal）且虚拟（virtual）的，其设计初衷是供需要自定义铸币逻辑的扩展合约（例如，为了优化Gas费而连续铸造代币的合约）来重写和使用。
     *  “不安全”的含义：是指它是一个低阶（low-level）函数，如果使用不当，会破坏合约的核心逻辑和不变性（invariant），导致代币计数错误、代币“丢失”或无法转移等问题。
     */
    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            _balances[account] += value;
        }
    }

    /**
     * @dev 将 `tokenId` 从其当前所有者转移到 `to`，或者如果当前所有者（或 `to`）是零地址，则铸造（或销毁）。
     * 返回更新前 `tokenId` 的所有者。
     * `auth` 参数是可选的。如果传递的值不为 0，则此函数将检查 `auth` 是代币的所有者，还是被（所有者）授权操作该代币。
     * 触发 {Transfer} 事件。
     * 注意：如果以跟踪余额的方式重写此函数，另请参阅 {_increaseBalance}。
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address from = _ownerOf(tokenId);

        // 执行（可选的）操作员检查
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // 执行更新
        if (from != address(0)) {
            // 清除授权。无需重新授权或触发 Approval 事件
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                _balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                _balances[to] += 1;
            }
        }

        // `delete _owners[tokenId]` 和 `_owners[tokenId] = address(0)` 的效果是完全一样的。
        // 在 Solidity 中，delete 关键字的作用是将一个状态变量恢复到其类型的默认初始值。对于 address 类型来说，它的默认值就是 address(0)。
        // 所以，从功能和 Gas 消耗的角度来看，这两行代码是等价的。
        // delete 的确会释放存储槽，从而获得 Gas 返还。
        // 在 Solidity 中，`delete` 释放存储槽的方式就是将该存储槽的值设置为其类型的默认零值。
        // 这两行代码在底层编译成的 EVM（以太坊虚拟机）指令是完全一样的。
        // 它们都会将 _owners 映射中 tokenId对应的那个存储槽的值从一个非零地址改为零地址。
        // Gas 返还的机制是基于存储槽的值从“非零”变为“零”这个行为，而与你是用 delete 关键字还是用赋值语句来实现这个行为无关。
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        return from;
    }

    /**
     * @dev 铸造 `tokenId` 并将其转移给 `to`。
     * 警告：不鼓励使用此方法，请尽可能使用 {_safeMint}。
     * 要求：
     * - `tokenId` 不得存在。
     * - `to` 不能是零地址。
     * 触发 {Transfer} 事件。
     */
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    /**
     * @dev 铸造 `tokenId`，将其转移给 `to` 并检查 `to` 是否接受。
     *
     * 要求：
     * - `tokenId` 不得存在。
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC721Receiver-onERC721Received}，该函数在安全转移时被调用。
     *
     * 触发 {Transfer} 事件。
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev 与 {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`] 相同，但带有一个额外的 `data` 参数，
     * 该参数会转发给合约接收者的 {IERC721Receiver-onERC721Received}。
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), address(0), to, tokenId, data);
    }

    /**
     * @dev 销毁 `tokenId`。
     * 当代币被销毁时，授权被清除。
     * 这是一个内部函数，不检查发送者是否有权操作该代币。
     *
     * 要求：
     * - `tokenId` 必须存在。
     * 触发 {Transfer} 事件。
     */
    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    /**
     * @dev 将 `tokenId` 从 `from` 转移到 `to`。
     * 与 {transferFrom} 相反，这对 msg.sender 没有限制。
     *
     * 要求：
     * - `to` 不能是零地址。
     * - `tokenId` 代币必须由 `from` 拥有。
     * 触发 {Transfer} 事件。
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev 安全地将 `tokenId` 代币从 `from` 转移到 `to`，检查合约接收者
     * 是否了解 ERC-721 标准，以防止代币被永久锁定。
     * `data` 是附加数据，没有指定格式，它在调用 `to` 时发送。
     * 这个内部函数类似于 {safeTransferFrom}，因为它会在接收者上调用
     * {IERC721Receiver-onERC721Received}，并且可以用于例如
     * 实现执行代币转移的替代机制，例如基于签名的机制。
     *
     * 要求：
     * - `tokenId` 代币必须存在且由 `from` 拥有。
     * - `to` 不能是零地址。
     * - `from` 不能是零地址。
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC721Receiver-onERC721Received}，该函数在安全转移时被调用。
     *
     * 触发 {Transfer} 事件。
     */
    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @dev 与 {xref-ERC721-_safeTransfer-address-address-uint256-}[`_safeTransfer`] 相同，但带有一个额外的 `data` 参数，
     * 该参数会转发给合约接收者的 {IERC721Receiver-onERC721Received}。
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
    }

    /**
     * @dev 授权 `to` 操作 `tokenId`
     * `auth` 参数是可选的。如果传递的值不为 0，则此函数将检查 `auth`
     * 是代币的所有者，还是被授权操作此所有者持有的所有代币。
     * 触发 {Approval} 事件。
     * 对此逻辑的重写应在带有额外 `bool emitEvent` 参数的变体中完成。
     */
    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @dev `_approve` 的变体，带有一个可选标志以启用或禁用 {Approval} 事件。
     * 在转移上下文中不触发该事件。
     */
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        // 除非必要，否则避免读取所有者
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // 我们不使用 _isAuthorized，因为单一代币授权不应能调用 approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        _tokenApprovals[tokenId] = to;
    }

    /**
     * @dev 授权 `operator` 操作 `owner` 的所有代币
     * 要求：
     * - operator 不能是零地址。
     * 触发 {ApprovalForAll} 事件。
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev 如果 `tokenId` 没有当前所有者（尚未铸造或已被销毁），则回滚。
     * 返回所有者。
     *
     * 对所有权逻辑的重写应在 {_ownerOf} 中完成。
     */
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }
}
