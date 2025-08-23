// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC3156FlashLender.sol)

pragma solidity >=0.5.0;

import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";

/**
 * @dev ERC-3156 闪电贷出借方（FlashLender）的接口，定义于
 * https://eips.ethereum.org/EIPS/eip-3156[ERC-3156]。
 */
interface IERC3156FlashLender {
    /**
     * @dev 可供借出的货币数量。
     * @param token 贷款的货币。
     * @return 可以借入的 `token` 的数量。
     */
    function maxFlashLoan(address token) external view returns (uint256);

    /**
     * @dev 对给定贷款收取的费用。
     * @param token 贷款的货币。
     * @param amount 借出的代币数量。
     * @return 在归还的本金之外，为贷款收取的 `token` 的数量。
     */
    function flashFee(address token, uint256 amount) external view returns (uint256);

    /**
     * @dev 发起一笔闪电贷。
     * @param receiver 贷款中代币的接收者，也是回调的接收者。
     * @param token 贷款的货币。
     * @param amount 借出的代币数量。
     * @param data 任意数据结构，旨在包含用户定义的参数。
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}
