// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

pragma solidity ^0.8.20;

/**
 * @dev 多个合约中使用的通用自定义错误的集合
 *
 * 重要提示：在库的未来版本中不保证向后兼容。
 * 建议避免依赖错误 API 来实现关键功能。
 *
 * _自 v5.1 起可用。_
 */
library Errors {
    /**
     * @dev 账户的 ETH 余额不足以执行操作。
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev 对目标地址的调用失败。目标可能已回滚。
     */
    error FailedCall();

    /**
     * @dev 部署失败。
     */
    error FailedDeployment();

    /**
     * @dev 缺少必要的预编译合约。
     */
    error MissingPrecompile(address);
}
