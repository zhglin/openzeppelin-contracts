// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.3.0) (token/ERC6909/extensions/draft-ERC6909Metadata.sol)

pragma solidity ^0.8.20;

import {ERC6909} from "../draft-ERC6909.sol";
import {IERC6909Metadata} from "../../../interfaces/draft-IERC6909.sol";

/**
 * @dev ERC6909 中定义的元数据扩展的实现。公开每个代币 ID 的名称、符号和小数位数。
 */
contract ERC6909Metadata is ERC6909, IERC6909Metadata {
    struct TokenMetadata {
        string name;
        string symbol;
        uint8 decimals;
    }

    // id => TokenMetadata
    mapping(uint256 id => TokenMetadata) private _tokenMetadata;

    /// @dev `id` 类型代币的名称已更新为 `newName`。
    event ERC6909NameUpdated(uint256 indexed id, string newName);

    /// @dev `id` 类型代币的符号已更新为 `newSymbol`。
    event ERC6909SymbolUpdated(uint256 indexed id, string newSymbol);

    /// @dev `id` 类型代币的小数位数已更新为 `newDecimals`。
    event ERC6909DecimalsUpdated(uint256 indexed id, uint8 newDecimals);

    /// @inheritdoc IERC6909Metadata
    function name(uint256 id) public view virtual override returns (string memory) {
        return _tokenMetadata[id].name;
    }

    /// @inheritdoc IERC6909Metadata
    function symbol(uint256 id) public view virtual override returns (string memory) {
        return _tokenMetadata[id].symbol;
    }

    /// @inheritdoc IERC6909Metadata
    function decimals(uint256 id) public view virtual override returns (uint8) {
        return _tokenMetadata[id].decimals;
    }

    /**
     * @dev 为给定的 `id` 类型代币设置 `name`。
     * 发出 {ERC6909NameUpdated} 事件。
     */
    function _setName(uint256 id, string memory newName) internal virtual {
        _tokenMetadata[id].name = newName;

        emit ERC6909NameUpdated(id, newName);
    }

    /**
     * @dev 为给定的 `id` 类型代币设置 `symbol`。
     * 发出 {ERC6909SymbolUpdated} 事件。
     */
    function _setSymbol(uint256 id, string memory newSymbol) internal virtual {
        _tokenMetadata[id].symbol = newSymbol;

        emit ERC6909SymbolUpdated(id, newSymbol);
    }

    /**
     * @dev 为给定的 `id` 类型代币设置 `decimals`。
     * 发出 {ERC6909DecimalsUpdated} 事件。
     */
    function _setDecimals(uint256 id, uint8 newDecimals) internal virtual {
        _tokenMetadata[id].decimals = newDecimals;

        emit ERC6909DecimalsUpdated(id, newDecimals);
    }
}
