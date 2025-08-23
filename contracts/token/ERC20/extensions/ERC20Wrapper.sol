// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/ERC20Wrapper.sol)

pragma solidity ^0.8.20;

import {IERC20, IERC20Metadata, ERC20} from "../ERC20.sol";
import {SafeERC20} from "../utils/SafeERC20.sol";

/**
 * @dev ERC-20 代币合约的扩展，以支持代币包装。
 *
 * 用户可以存入和取出“底层代币”，并收到相应数量的“包装代币”。这与其他模块结合使用时非常有用。
 * 例如，将此包装机制与 {ERC20Votes} 结合，可以将现有的“基本”ERC-20 包装成一个治理代币。
 *
 * 警告：任何底层代币在没有显式转移的情况下改变账户 {balanceOf} 的机制，
 * 都可能导致此合约的供应量与其底层余额不同步。在包装那些可能导致包装器抵押不足
 * （即包装器的总供应量高于其底层余额）的代币时，请务必谨慎。请参阅 {_recover}
 * 以恢复累积到包装器的价值。
 */
abstract contract ERC20Wrapper is ERC20 {
    // 被包装的底层代币
    IERC20 private immutable _underlying;

    /**
     * @dev 底层代币无法被包装。
     */
    error ERC20InvalidUnderlying(address token);

    constructor(IERC20 underlyingToken) {
        if (underlyingToken == this) {
            revert ERC20InvalidUnderlying(address(this));
        }
        _underlying = underlyingToken;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override returns (uint8) {
        try IERC20Metadata(address(_underlying)).decimals() returns (uint8 value) {
            return value;
        } catch {
            return super.decimals();
        }
    }

    /**
     * @dev 返回正在被包装的底层 ERC-20 代币的地址。
     */
    function underlying() public view returns (IERC20) {
        return _underlying;
    }

    /**
     * @dev 允许用户存入底层代币，并铸造相应数量的包装代币。
     */
    function depositFor(address account, uint256 value) public virtual returns (bool) {
        address sender = _msgSender();
        if (sender == address(this)) {
            revert ERC20InvalidSender(address(this));
        }
        if (account == address(this)) {
            revert ERC20InvalidReceiver(account);
        }
        // 把value个底层代币存入当前合约
        SafeERC20.safeTransferFrom(_underlying, sender, address(this), value);
        // 铸造相应数量的包装代币
        _mint(account, value);
        return true;
    }

    /**
     * @dev 允许用户销毁一定数量的包装代币，并取出相应数量的底层代币。
     */
    function withdrawTo(address account, uint256 value) public virtual returns (bool) {
        if (account == address(this)) {
            revert ERC20InvalidReceiver(account);
        }
        // 销毁value个包装代币
        _burn(_msgSender(), value);
        // 把value个底层代币转回给account
        SafeERC20.safeTransfer(_underlying, account, value);
        return true;
    }

    /**
     * @dev 铸造包装代币以覆盖任何可能因错误转移或从变基机制中获得的底层代币。
     * 这是一个内部函数，如果需要，可以通过访问控制来暴露。
     *
     * 同步“包装代币的总供应量”与“合约持有的底层代币的实际数量”，以处理那些意外多出来的底层代币。
     * 理想状态: 包装代币与底层代币的数量应该是相等的。
     * 但如果底层代币的数量多于包装代币的数量，则需要调用此函数来恢复。（错误转账，变基代币，空投或分红）
     */
    function _recover(address account) internal virtual returns (uint256) {
        uint256 value = _underlying.balanceOf(address(this)) - totalSupply();
        _mint(account, value);
        return value;
    }
}
