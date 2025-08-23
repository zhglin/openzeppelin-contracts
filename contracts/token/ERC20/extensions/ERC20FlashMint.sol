// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/ERC20FlashMint.sol)

pragma solidity ^0.8.20;

import {IERC3156FlashBorrower} from "../../../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../../../interfaces/IERC3156FlashLender.sol";
import {ERC20} from "../ERC20.sol";

/**
 * @dev ERC-3156 闪电贷扩展的实现，定义于
 * https://eips.ethereum.org/EIPS/eip-3156[ERC-3156]。
 *
 * 添加了 {flashLoan} 方法，该方法在代币级别提供闪电贷支持。
 * 默认情况下不收取费用，但可以通过重写 {flashFee} 来更改。
 *
 * 注意：当此扩展与 {ERC20Capped} 或 {ERC20Votes} 扩展一起使用时，
 * {maxFlashLoan} 将无法正确反映可闪电铸造的最大数量。我们建议
 * 重写 {maxFlashLoan} 以便它能正确反映供应上限。
 */
abstract contract ERC20FlashMint is ERC20, IERC3156FlashLender {
    bytes32 private constant RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /**
     * @dev 贷款代币无效。
     */
    error ERC3156UnsupportedToken(address token);

    /**
     * @dev 请求的贷款超过了 `token` 的最大贷款额。
     */
    error ERC3156ExceededMaxLoan(uint256 maxLoan);

    /**
     * @dev 闪电贷的接收者不是一个有效的 {IERC3156FlashBorrower-onFlashLoan} 实现者。
     */
    error ERC3156InvalidReceiver(address receiver);

    /**
     * @dev 返回可供贷款的最大代币数量。
     * @param token 被请求的代币地址。
     * @return 可以借出的代币数量。
     *
     * 注意：此函数不考虑任何形式的供应上限，因此如果它在像 {ERC20Capped} 这样的
     * 有上限的代币中使用，请确保重写此函数以集成上限，而不是使用 `type(uint256).max`。
     */
    function maxFlashLoan(address token) public view virtual returns (uint256) {
        return token == address(this) ? type(uint256).max - totalSupply() : 0;
    }

    /**
     * @dev 返回执行闪电贷时应用的费用。此函数调用
     * {_flashFee} 函数，该函数返回执行闪电贷时应用的费用。
     * @param token 将要进行闪电贷的代币。
     * @param value 将要借出的代币数量。
     * @return 应用于相应闪电贷的费用。
     */
    function flashFee(address token, uint256 value) public view virtual returns (uint256) {
        if (token != address(this)) {
            revert ERC3156UnsupportedToken(token);
        }
        return _flashFee(token, value);
    }

    /**
     * @dev 返回执行闪电贷时应用的费用。默认情况下，此实现为 0 费用。
     * 可以重载此函数以使闪电贷机制具有通缩性。
     * @param token 将要进行闪电贷的代币。
     * @param value 将要借出的代币数量。
     * @return 应用于相应闪电贷的费用。
     */
    function _flashFee(address token, uint256 value) internal view virtual returns (uint256) {
        // silence warning about unused variable without the addition of bytecode.
        token;
        value;
        return 0;
    }

    /**
     * @dev 返回闪电贷费用的接收者地址。默认情况下，此实现返回 address(0)，
     * 这意味着费用金额将被销毁。可以重载此函数以更改费用接收者。
     * @return 将要发送闪电贷费用的地址。
     */
    function _flashFeeReceiver() internal view virtual returns (address) {
        return address(0);
    }

    /**
     * @dev 执行闪电贷。新的代币被铸造并发送给
     * `receiver`，该接收者需要实现 {IERC3156FlashBorrower}
     * 接口。在闪电贷结束时，接收者应拥有
     * value + fee 的代币，并将它们授权回代币合约本身，以便可以销毁它们。
     * @param receiver 闪电贷的接收者。应实现
     * {IERC3156FlashBorrower-onFlashLoan} 接口。
     * @param token 将要进行闪电贷的代币。仅支持 `address(this)`。
     * @param value 将要借出的代币数量。
     * @param data 传递给接收者的任意数据字段。
     * @return 如果闪电贷成功，则返回 `true`。
     */
    // 此函数可以重入，但这不会构成风险，因为它总是保持在开始时铸造的金额在结束时总是被收回和销毁的属性，否则整个函数将回滚。
    // slither-disable-next-line reentrancy-no-eth
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 value,
        bytes calldata data
    ) public virtual returns (bool) {
        uint256 maxLoan = maxFlashLoan(token);
        if (value > maxLoan) {
            revert ERC3156ExceededMaxLoan(maxLoan);
        }
        uint256 fee = flashFee(token, value);
        _mint(address(receiver), value);
        // 立刻调用借款方合约的函数，用来让借款方执行自己的业务逻辑。
        if (receiver.onFlashLoan(_msgSender(), token, value, fee, data) != RETURN_VALUE) {
            revert ERC3156InvalidReceiver(address(receiver));
        }
        address flashFeeReceiver = _flashFeeReceiver();
        _spendAllowance(address(receiver), address(this), value + fee);
        if (fee == 0 || flashFeeReceiver == address(0)) {
            _burn(address(receiver), value + fee);
        } else {
            _burn(address(receiver), value);
            _transfer(address(receiver), flashFeeReceiver, fee);
        }
        return true;
    }
}
