// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC7802.sol)

pragma solidity >=0.6.2;

import {IERC165} from "./IERC165.sol";

/// @title IERC7802
/// @notice 定义了跨链 ERC20 转移的接口。
interface IERC7802 is IERC165 {
    /// @notice 当一笔跨链转移铸造代币时发出。
    /// @param to       正在为其铸造代币的账户地址。
    /// @param amount   铸造的代币数量。
    /// @param sender   调用 crosschainMint 的调用者地址 (msg.sender)。
    event CrosschainMint(address indexed to, uint256 amount, address indexed sender);

    /// @notice 当一笔跨链转移销毁代币时发出。
    /// @param from     正在为其销毁代币的账户地址。
    /// @param amount   销毁的代币数量。
    /// @param sender   调用 crosschainBurn 的调用者地址 (msg.sender)。
    event CrosschainBurn(address indexed from, uint256 amount, address indexed sender);

    /// @notice 通过一笔跨链转移来铸造代币。
    /// @param _to     铸造代币的目标地址。
    /// @param _amount 要铸造的代币数量。
    function crosschainMint(address _to, uint256 _amount) external;

    /// @notice 通过一笔跨链转移来销毁代币。
    /// @param _from   销毁代币的来源地址。
    /// @param _amount 要销毁的代币数量。
    function crosschainBurn(address _from, uint256 _amount) external;
}
