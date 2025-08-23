// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/ERC20Pausable.sol)

pragma solidity ^0.8.20;

import {ERC20} from "../ERC20.sol";
import {Pausable} from "../../../utils/Pausable.sol";

/**
 * @dev 带有可暂停的代币转移、铸造和销毁功能的 ERC-20 代币。
 *
 * 适用于以下场景：例如在评估期结束前阻止交易，或在出现重大漏洞时作为紧急开关冻结所有代币转移。
 *
 * 重要提示：此合约不包含公开的暂停和取消暂停功能。除了继承此合约外，您还必须定义这两个功能，
 * 调用 {Pausable-_pause} 和 {Pausable-_unpause} 内部函数，并使用适当的访问控制，例如使用 {AccessControl} 或 {Ownable}。
 * 否则，合约的暂停机制将无法访问，从而无法使用。
 */
abstract contract ERC20Pausable is ERC20, Pausable {
    /**
     * @dev 参见 {ERC20-_update}。
     *
     * 要求：
     *
     * - 合约必须未被暂停。
     */
    function _update(address from, address to, uint256 value) internal virtual override whenNotPaused {
        super._update(from, to, value);
    }
}
