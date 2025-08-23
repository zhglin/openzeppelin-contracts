// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev 提供有关当前执行上下文的信息，包括交易的发送方及其数据。
 * 尽管通常可以通过 msg.sender 和 msg.data 来获取这些信息，但不应该以这种直接的方式访问，
 * 因为在处理元交易时，发送和支付执行费用的账户可能不是实际的发送方（就应用程序而言）。
 * 此合约仅适用于中间的、类似库的合约。
 *
 * 用户（真正的意图发起者）可能因为没有 ETH 来支付 Gas 费，而选择将签好名的“交易意图”发送给一个中继者（Relayer）。
 * 中继者会将这个签过名的消息打包成一个真正的链上交易并发送到网络中，由中继者来支付 Gas 费。
 * msg.sender 实际上是中继者的地址，而不是用户的地址。如果直接使用msg.sender，权限控制等逻辑就会出错。
 * 当需要支持元交易时，子合约可以重写（override） _msgSender()函数。重写后的逻辑可以从交易数据（msg.data）的末尾解析出真正的用户地址，并将其返回。
 * 这种封装是一种抽象，它将“谁是消息的发送方”这个问题的答案与底层的 msg.sender解耦。
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    // EIP-2771使用
    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}
