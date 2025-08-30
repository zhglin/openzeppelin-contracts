// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (governance/utils/VotesExtended.sol)
pragma solidity ^0.8.24;

import {Checkpoints} from "../../utils/structs/Checkpoints.sol";
import {Votes} from "./Votes.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";

/**
 * @dev {Votes} 的扩展，增加了对委托和余额的检查点功能。
 *
 * 警告：虽然此合约扩展了 {Votes}，但若无额外考量，{Votes} 的有效用法可能与 {VotesExtended} 不兼容。
 * 此合约中 {_transferVotingUnits} 的实现必须在投票权重变动被注册之后运行，以使其能反映在 {_getVotingUnits} 中。
 *
 * 换言之，{VotesExtended} **必须**以这样一种方式集成：在资产转移被注册且余额更新**之后**才调用 {_transferVotingUnits}：
 *
 * ```solidity
 * contract VotingToken is Token, VotesExtended {
 *   function transfer(address from, address to, uint256 tokenId) public override {
 *     super.transfer(from, to, tokenId); // <- 首先执行转移...
 *     _transferVotingUnits(from, to, 1); // <- ...然后才调用 _transferVotingUnits。
 *   }
 *
 *   function _getVotingUnits(address account) internal view override returns (uint256) {
 *      return balanceOf(account);
 *   }
 * }
 * ```
 *
 * {ERC20Votes} 和 {ERC721Votes} 遵循此模式，因此可以安全地与 {VotesExtended} 一起使用。
 */
abstract contract VotesExtended is Votes {
    using Checkpoints for Checkpoints.Trace160;
    using Checkpoints for Checkpoints.Trace208;

    // 用户委托的检查点
    mapping(address delegator => Checkpoints.Trace160) private _userDelegationCheckpoints;
    // 用户投票的检查点
    mapping(address account => Checkpoints.Trace208) private _userVotingUnitsCheckpoints;

    /**
     * @dev 返回 `account` 在过去某一特定时间点的委托人。如果 `clock()` 被配置为使用区块号，
     * 则此函数将返回相应区块结束时的值。
     * 要求：
     * - `timepoint` 必须在过去。如果使用区块号操作，该区块必须已被挖出。
     */
    function getPastDelegate(address account, uint256 timepoint) public view virtual returns (address) {
        return address(_userDelegationCheckpoints[account].upperLookupRecent(_validateTimepoint(timepoint)));
    }

    /**
     * @dev 返回 `account` 在过去某一特定时间点的余额（`balanceOf`）。如果 `clock()` 被配置为使用区块号，
     * 则此函数将返回相应区块结束时的值。
     * 要求：
     * - `timepoint` 必须在过去。如果使用区块号操作，该区块必须已被挖出。
     */
    function getPastBalanceOf(address account, uint256 timepoint) public view virtual returns (uint256) {
        return _userVotingUnitsCheckpoints[account].upperLookupRecent(_validateTimepoint(timepoint));
    }

    /// @inheritdoc Votes
    function _delegate(address account, address delegatee) internal virtual override {
        super._delegate(account, delegatee);

        _userDelegationCheckpoints[account].push(clock(), uint160(delegatee));
    }

    /// @inheritdoc Votes
    function _transferVotingUnits(address from, address to, uint256 amount) internal virtual override {
        super._transferVotingUnits(from, to, amount);
        if (from != to) {
            if (from != address(0)) {
                _userVotingUnitsCheckpoints[from].push(clock(), SafeCast.toUint208(_getVotingUnits(from)));
            }
            if (to != address(0)) {
                _userVotingUnitsCheckpoints[to].push(clock(), SafeCast.toUint208(_getVotingUnits(to)));
            }
        }
    }
}
