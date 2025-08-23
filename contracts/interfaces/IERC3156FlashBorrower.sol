// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC3156FlashBorrower.sol)

pragma solidity >=0.5.0;

/**
 * @dev ERC-3156 闪电贷借款方（FlashBorrower）的接口，定义于
 * https://eips.ethereum.org/EIPS/eip-3156[ERC-3156]。
 */
interface IERC3156FlashBorrower {
    /**
     * @dev 接收一笔闪电贷。
     * @param initiator 贷款的发起者。
     * @param token 贷款的货币。
     * @param amount 借出的代币数量。
     * @param fee 需要额外偿还的代币数量（手续费）。
     * @param data 任意数据结构，旨在包含用户定义的参数。
     * @return 必须返回 "ERC3156FlashBorrower.onFlashLoan" 的 keccak256 哈希值。
     */
    /**
     * 作为借款方 receiver 合约的编写者，您需要在 onFlashLoan 函数里完成所有操作，例如：
     * 利用刚刚收到的1000个DAI，去 Uniswap 买入 ETH。
     * 将买到的 ETH，立刻去 Sushiswap 卖掉，换回1002个DAI，赚取了2个DAI的利润。
     * 在函数结束前，必须调用 approve 函数，授权 ERC20FlashMint 合约可以从自己这里拿走“本金+手续费”（比如1000.1个DAI）。
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}
