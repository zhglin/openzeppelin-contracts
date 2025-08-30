// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/utils/IVotes.sol)

pragma solidity >=0.8.4;

/**
 * @dev 为 {ERC20Votes}、{ERC721Votes} 以及其他启用了 {Votes} 功能的合约提供的通用接口。
 */
interface IVotes {
    /**
     * @dev 所使用的签名已过期。
     */
    error VotesExpiredSignature(uint256 expiry);

    /**
     * @dev 当一个账户更改其投票委托人时发出。
     */
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /**
     * @dev 当代币转移或委托变更导致委托人投票单位数量发生变化时发出。
     */
    event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes);

    /**
     * @dev 返回 `account` 当前拥有的投票数量。
     */
    function getVotes(address account) external view returns (uint256);

    /**
     * @dev 返回 `account` 在过去某一特定时间点拥有的投票数量。如果 `clock()` 被配置为使用区块号，
     * 则此函数将返回相应区块结束时的值。
     */
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);

    /**
     * @dev 返回过去某一特定时间点的总投票供应量。如果 `clock()` 被配置为使用区块号，
     * 则此函数将返回相应区块结束时的值。
     *
     * 注意：这个值是所有可用投票的总和，不一定是所有已委托投票的总和。
     * 尚未被委托的投票仍然是总供应量的一部分，即使它们不会参与投票。
     */
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);

    /**
     * @dev 返回 `account` 已选择的投票委托人。
     */
    function delegates(address account) external view returns (address);

    /**
     * @dev 将投票权从发送者委托给 `delegatee`。
     */
    function delegate(address delegatee) external;

    /**
     * @dev 将投票权从签名者委托给 `delegatee`。
     */
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
}
