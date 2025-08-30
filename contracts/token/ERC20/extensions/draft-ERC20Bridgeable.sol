// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/draft-ERC20Bridgeable.sol)

pragma solidity ^0.8.20;

import {ERC20} from "../ERC20.sol";
import {ERC165, IERC165} from "../../../utils/introspection/ERC165.sol";
import {IERC7802} from "../../../interfaces/draft-IERC7802.sol";

/**
 * @dev 实现了 https://eips.ethereum.org/EIPS/eip-7802[ERC-7802] 中定义的标准代币接口的 ERC20 扩展。
 */
abstract contract ERC20Bridgeable is ERC20, ERC165, IERC7802 {
    /// @dev 用于限制只有代币桥可以访问的修饰器。
    modifier onlyTokenBridge() {
        // 代币桥永远不应该被中继器/转发器所冒充。出于安全原因，
        // 使用 msg.sender 比使用 _msgSender() 更可取。
        _checkTokenBridge(msg.sender);
        _;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC7802).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev 参见 {IERC7802-crosschainMint}。发出一个 {IERC7802-CrosschainMint} 事件。
     */
    function crosschainMint(address to, uint256 value) public virtual override onlyTokenBridge {
        _mint(to, value);
        emit CrosschainMint(to, value, _msgSender());
    }

    /**
     * @dev 参见 {IERC7802-crosschainBurn}。发出一个 {IERC7802-CrosschainBurn} 事件。
     */
    function crosschainBurn(address from, uint256 value) public virtual override onlyTokenBridge {
        _burn(from, value);
        emit CrosschainBurn(from, value, _msgSender());
    }

    /**
     * @dev 检查调用者是否是受信任的代币桥。如果不是，则必须 revert。
     *
     * 开发者应该使用一种允许自定义许可发送者列表的访问控制机制来实现此函数。
     * 可以考虑使用 {AccessControl} 或 {AccessManaged}。
     */
    function _checkTokenBridge(address caller) internal virtual;
}
