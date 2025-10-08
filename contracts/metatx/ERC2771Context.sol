// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (metatx/ERC2771Context.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev 带有 ERC-2771 支持的 Context 变体。
 *
 * 警告：在依赖特定 calldata 长度的合约中避免使用此模式，
 * 因为它们会受到任何根据 ERC-2771 规范在其 `msg.data` 后缀 `from` 地址的转发器的影响，
 * 这会将地址大小（20字节）添加到 calldata 大小中。
 * 一个意外行为的例子可能是在尝试调用仅在 `msg.data.length == 0` 时可访问的 `receive` 函数时，无意中调用了 fallback（或其他函数）。
 *
 * 警告：在此合约中使用 `delegatecall` 是危险的，并可能导致上下文损坏。
 * 任何转发到此合约并触发对自身的 `delegatecall` 的请求都将导致无效的 {_msgSender} 恢复。
 */
abstract contract ERC2771Context is Context {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable _trustedForwarder;

    /**
     * @dev 使用一个受信任的转发器初始化合约，该转发器将能够代表其他账户调用此合约上的函数。
     *
     * 注意：可以通过重写 {trustedForwarder} 来替换受信任的转发器。
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder_) {
        _trustedForwarder = trustedForwarder_;
    }

    /**
     * @dev 返回受信任的转发器的地址。
     */
    function trustedForwarder() public view virtual returns (address) {
        return _trustedForwarder;
    }

    /**
     * @dev 指示任何特定地址是否是受信任的转发器。
     */
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == trustedForwarder();
    }

    /**
     * @dev `msg.sender` 的重写。当调用不是由受信任的转发器执行，或者 calldata 长度小于20字节（一个地址的长度）时，默认为原始的 `msg.sender`。
     */
    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) {
            unchecked {
                // 只取后面20位
                return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
            }
        } else {
            return super._msgSender();
        }
    }

    /**
     * @dev `msg.data` 的重写。当调用不是由受信任的转发器执行，或者 calldata 长度小于20字节（一个地址的长度）时，默认为原始的 `msg.data`。
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) {
            unchecked {
                // 去掉后面20位
                return msg.data[:calldataLength - contextSuffixLength];
            }
        } else {
            return super._msgData();
        }
    }

    /**
     * @dev ERC-2771 将上下文指定为单个地址（20字节）。
     */
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return 20;
    }
}
