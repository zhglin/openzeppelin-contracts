// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC5313.sol)

pragma solidity >=0.4.16;

/**
 * @dev 轻量级合约所有权标准的接口。
 *
 * 用于识别控制合约的帐户所需的标准化最小接口。
 */
interface IERC5313 {
    /**
     * @dev 获取所有者的地址。
     */
    function owner() external view returns (address);
}
