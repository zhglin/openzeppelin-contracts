// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.20;

import {ERC20} from "../ERC20.sol";
import {Context} from "../../../utils/Context.sol";

/**
 * @dev {ERC20} 的扩展，允许代币{持有者}销毁其持有的代币，以及他们获得授权额度的代币。
 * 这种销毁可以通过链下工具（通过分析事件）识别。
 *
 * `burn`: 赋予每个用户自我管理的权利，可以随时销毁自己的资产。这是一个普遍权利，所以是 public。
 * `burnFrom`: 允许一个用户在得到他人明确授权后，代为销毁他人的资产。
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev 从调用者处销毁数量为 `value` 的代币。
     * 参见 {ERC20-_burn}。
     */
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    /**
     * @dev 从 `account` 处销毁数量为 `value` 的代币，并从调用者的授权额度中扣除。
     * 参见 {ERC20-_burn} 和 {ERC20-allowance}。
     * 要求：
     * - 调用者必须拥有 `account` 代币至少 `value` 的授权额度。
     */
    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}
