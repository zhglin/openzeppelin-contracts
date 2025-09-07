// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC6909/extensions/draft-ERC6909ContentURI.sol)

pragma solidity ^0.8.20;

import {ERC6909} from "../draft-ERC6909.sol";
import {IERC6909ContentURI} from "../../../interfaces/draft-IERC6909.sol";

/**
 * @dev ERC6909中定义的内容URI扩展的实现。
 */
contract ERC6909ContentURI is ERC6909, IERC6909ContentURI {
    string private _contractURI;
    mapping(uint256 id => string) private _tokenURIs;

    /// @dev 当合约URI更改时触发的事件。详见 https://eips.ethereum.org/EIPS/eip-7572[ERC-7572]。
    event ContractURIUpdated();

    /// @dev 参见 {IERC1155-URI}
    event URI(string value, uint256 indexed id);

    /// @inheritdoc IERC6909ContentURI
    function contractURI() public view virtual override returns (string memory) {
        return _contractURI;
    }

    /// @inheritdoc IERC6909ContentURI
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return _tokenURIs[id];
    }

    /**
     * @dev 设置合约的 {contractURI}。
     * 触发 {ContractURIUpdated} 事件。
     */
    function _setContractURI(string memory newContractURI) internal virtual {
        _contractURI = newContractURI;

        emit ContractURIUpdated();
    }

    /**
     * @dev 为给定类型 `id` 的代币设置 {tokenURI}。
     * 触发 {URI} 事件。
     */
    function _setTokenURI(uint256 id, string memory newTokenURI) internal virtual {
        _tokenURIs[id] = newTokenURI;

        emit URI(newTokenURI, id);
    }
}
