// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.20;

import {IERC1155} from "./IERC1155.sol";
import {IERC1155MetadataURI} from "./extensions/IERC1155MetadataURI.sol";
import {ERC1155Utils} from "./utils/ERC1155Utils.sol";
import {Context} from "../../utils/Context.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";
import {Arrays} from "../../utils/Arrays.sol";
import {IERC1155Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev 基础标准多代币的实现。
 * 参见 https://eips.ethereum.org/EIPS/eip-1155
 * 最初基于 Enjin 的代码：https://github.com/enjin/erc-1155
 */
abstract contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI, IERC1155Errors {
    using Arrays for uint256[];
    using Arrays for address[];

    // 代币 ID => 账户地址 => 余额
    mapping(uint256 id => mapping(address account => uint256)) private _balances;

    // 账户地址 => 授权地址 => 批准状态
    mapping(address account => mapping(address operator => bool)) private _operatorApprovals;

    // 用作所有代币类型的 URI，依赖于 ID 替换，例如 https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev 参见 {_setURI}。
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev 参见 {IERC1155MetadataURI-uri}。
     *
     * 此实现为 *所有* 代币类型返回相同的 URI。它依赖于
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[ERC 中定义的]代币类型 ID 替换机制。
     *
     * 调用此函数的客户端必须将 `\{id\}` 子字符串替换为实际的代币类型 ID。
     */
    function uri(uint256 /* id */) public view virtual returns (string memory) {
        return _uri;
    }

    /// @inheritdoc IERC1155
    function balanceOf(address account, uint256 id) public view virtual returns (uint256) {
        return _balances[id][account];
    }

    /**
     * @dev 参见 {IERC1155-balanceOfBatch}。
     * 要求：
     * - `accounts` 和 `ids` 必须具有相同的长度。
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual returns (uint256[] memory) {
        if (accounts.length != ids.length) {
            revert ERC1155InvalidArrayLength(ids.length, accounts.length);
        }

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts.unsafeMemoryAccess(i), ids.unsafeMemoryAccess(i));
        }

        return batchBalances;
    }

    /// @inheritdoc IERC1155
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /// @inheritdoc IERC1155
    function isApprovedForAll(address account, address operator) public view virtual returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /// @inheritdoc IERC1155
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual {
        address sender = _msgSender();
        // 是否授权
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeTransferFrom(from, to, id, value, data);
    }

    /// @inheritdoc IERC1155
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeBatchTransferFrom(from, to, ids, values, data);
    }

    /**
     * @dev 将 `value` 数量的 `id` 类型代币从 `from` 转移到 `to`。如果 `from`（或 `to`）是零地址，则将铸造（或销毁）。
     * 如果数组包含一个元素，则发出 {TransferSingle} 事件，否则发出 {TransferBatch}。
     * 
     * 要求：
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC1155Receiver-onERC1155Received}
     *   或 {IERC1155Receiver-onERC1155BatchReceived} 并返回接受魔法值。
     * - `ids` 和 `values` 必须具有相同的长度。
     * 
     * 注意：此函数中不执行 ERC-1155 接受检查。请改用 {_updateWithAcceptanceCheck}。
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual {
        if (ids.length != values.length) {
            revert ERC1155InvalidArrayLength(ids.length, values.length);
        }

        // 操作发起者
        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids.unsafeMemoryAccess(i);
            uint256 value = values.unsafeMemoryAccess(i);

            if (from != address(0)) {
                // 减少余额
                uint256 fromBalance = _balances[id][from];
                if (fromBalance < value) {
                    revert ERC1155InsufficientBalance(from, fromBalance, value, id);
                }
                unchecked {
                    // 不可能溢出：value <= fromBalance
                    _balances[id][from] = fromBalance - value;
                }
            }

            // 增加余额
            if (to != address(0)) {
                _balances[id][to] += value;
            }
        }

        // 处理不同事件
        if (ids.length == 1) {
            uint256 id = ids.unsafeMemoryAccess(0);
            uint256 value = values.unsafeMemoryAccess(0);
            emit TransferSingle(operator, from, to, id, value);
        } else {
            emit TransferBatch(operator, from, to, ids, values);
        }
    }

    /**
     * @dev {_update} 的版本，通过在接收者地址上调用
     * {IERC1155Receiver-onERC1155Received} 或 {IERC1155Receiver-onERC1155BatchReceived} 来执行代币接受检查，
     * 如果它包含代码（例如，在执行时是智能合约）。
     *
     * 重要提示：不鼓励重写此函数，因为它会带来来自接收者的重入风险。
     * 因此，在此函数之后对合约状态的任何更新都将破坏检查-效果-交互模式。请考虑改为重写 {_update}。
     */
    function _updateWithAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        _update(from, to, ids, values);
        if (to != address(0)) {
            address operator = _msgSender();
            if (ids.length == 1) {
                uint256 id = ids.unsafeMemoryAccess(0);
                uint256 value = values.unsafeMemoryAccess(0);
                ERC1155Utils.checkOnERC1155Received(operator, from, to, id, value, data);
            } else {
                ERC1155Utils.checkOnERC1155BatchReceived(operator, from, to, ids, values, data);
            }
        }
    }

    /**
     * @dev 将 `value` 个 `id` 类型的代币从 `from` 转移到 `to`。
     * 发出 {TransferSingle} 事件。
     *
     * 要求：
     * - `to` 不能是零地址。
     * - `from` 必须拥有至少 `value` 数量的 `id` 类型代币的余额。
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC1155Receiver-onERC1155Received} 并返回接受魔法值。
     */
    function _safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        // 转换成数组
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[批处理] 版本的 {_safeTransferFrom}。
     * 发出 {TransferBatch} 事件。
     *
     * 要求：
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC1155Receiver-onERC1155BatchReceived} 并返回
     * 接受魔法值。
     * - `ids` 和 `values` 必须具有相同的长度。
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    /**
     * @dev 为所有代币类型设置一个新的 URI，依赖于
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[ERC 中定义的] 代币类型 ID 替换机制。
     *
     * 通过此机制，URI 或所述 URI 的 JSON 文件中任何值的 `\{id\}` 子字符串都将被客户端替换为代币类型 ID。
     *
     * 例如，`https://token-cdn-domain/\{id\}.json` URI 将被客户端
     * 解释为
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * 对于代币类型 ID 0x4cce0。
     *
     * 参见 {uri}。
     * 因为这些 URI 不能被 {URI} 事件有意义地表示，
     * 所以此函数不发出任何事件。
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev 创建 `value` 数量的 `id` 类型代币，并将其分配给 `to`。
     * 发出 {TransferSingle} 事件。
     *
     * 要求：
     * - `to` 不能是零地址。
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC1155Receiver-onERC1155Received} 并返回接受魔法值。
     */
    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        // 转换成数组
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[批处理] 版本的 {_mint}。
     * 发出 {TransferBatch} 事件。
     *
     * 要求：
     * - `ids` 和 `values` 必须具有相同的长度。
     * - `to` 不能是零地址。
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC1155Receiver-onERC1155BatchReceived} 并返回
     * 接受魔法值。
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

    /**
     * @dev 从 `from` 销毁 `value` 数量的 `id` 类型代币。
     * 发出 {TransferSingle} 事件。
     *
     * 要求：
     * - `from` 不能是零地址。
     * - `from` 必须拥有至少 `value` 数量的 `id` 类型代币。
     */
    function _burn(address from, uint256 id, uint256 value) internal {
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[批处理] 版本的 {_burn}。
     * 发出 {TransferBatch} 事件。
     *
     * 要求：
     * - `from` 不能是零地址。
     * - `from` 必须拥有至少 `value` 数量的 `id` 类型代币。
     * - `ids` 和 `values` 必须具有相同的长度。
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory values) internal {
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    /**
     * @dev 批准 `operator` 操作 `owner` 的所有代币。
     * 发出 {ApprovalForAll} 事件。
     * 要求：
     * - `operator` 不能是零地址。
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) {
            revert ERC1155InvalidOperator(address(0));
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev 在内存中创建一个数组，其中每个提供的元素只有一个值。
     */
    function _asSingletonArrays(
        uint256 element1,
        uint256 element2
    ) private pure returns (uint256[] memory array1, uint256[] memory array2) {
        assembly ("memory-safe") {
            // 加载空闲内存指针
            array1 := mload(0x40)
            // 将数组长度设置为 1
            mstore(array1, 1)
            // 在长度后的下一个字（内容开始处）存储单个元素
            mstore(add(array1, 0x20), element1)

            // 对下一个数组重复此操作，将其定位在第一个数组之后
            array2 := add(array1, 0x40)
            mstore(array2, 1)
            mstore(add(array2, 0x20), element2)

            // 通过指向第二个数组之后来更新空闲内存指针
            mstore(0x40, add(array2, 0x40))
        }
    }
}
