// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC7674.sol)

pragma solidity >=0.6.2;

import {IERC20} from "./IERC20.sol";

/**
 * @dev ERC-20 的临时授权扩展 (https://github.com/ethereum/ERCs/pull/358[ERC-7674])
 */
interface IERC7674 is IERC20 {
    /**
     * @dev 设置临时授权，允许 `spender` (在同一笔交易内) 提取调用者持有的资产。
     */
    function temporaryApprove(address spender, uint256 value) external returns (bool success);
}
