// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorVotesSuperQuorumFraction.sol)

pragma solidity ^0.8.24;

import {Governor} from "../Governor.sol";
import {GovernorSuperQuorum} from "./GovernorSuperQuorum.sol";
import {GovernorVotesQuorumFraction} from "./GovernorVotesQuorumFraction.sol";
import {Math} from "../../utils/math/Math.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";
import {Checkpoints} from "../../utils/structs/Checkpoints.sol";

/**
 * @dev {GovernorVotesQuorumFraction} 的扩展，带有一个表示为总供应量一部分的超级法定人数。
 * 满足超级法定人数（并且赞成票占多数）的提案会在提案截止日期前进入 `Succeeded` 状态。
 */
abstract contract GovernorVotesSuperQuorumFraction is GovernorVotesQuorumFraction, GovernorSuperQuorum {
    using Checkpoints for Checkpoints.Trace208;

    Checkpoints.Trace208 private _superQuorumNumeratorHistory;

    event SuperQuorumNumeratorUpdated(uint256 oldSuperQuorumNumerator, uint256 newSuperQuorumNumerator);

    /**
     * @dev 设置的超级法定人数无效，因为它超过了法定人数的分母。
     */
    error GovernorInvalidSuperQuorumFraction(uint256 superQuorumNumerator, uint256 denominator);

    /**
     * @dev 设置的超级法定人数无效，因为它小于或等于法定人数。
     */
    error GovernorInvalidSuperQuorumTooSmall(uint256 superQuorumNumerator, uint256 quorumNumerator);

    /**
     * @dev 设置的法定人数无效，因为它超过了超级法定人数。
     */
    error GovernorInvalidQuorumTooLarge(uint256 quorumNumerator, uint256 superQuorumNumerator);

    /**
     * @dev 将超级法定人数初始化为代币总供应量的一部分。
     *
     * 超级法定人数被指定为代币总供应量的一部分，并且必须大于法定人数。
     */
    constructor(uint256 superQuorumNumeratorValue) {
        _updateSuperQuorumNumerator(superQuorumNumeratorValue);
    }

    /**
     * @dev 返回当前的超级法定人数分子。
     */
    function superQuorumNumerator() public view virtual returns (uint256) {
        return _superQuorumNumeratorHistory.latest();
    }

    /**
     * @dev 返回特定 `timepoint` 的超级法定人数分子。
     */
    function superQuorumNumerator(uint256 timepoint) public view virtual returns (uint256) {
        return _optimisticUpperLookupRecent(_superQuorumNumeratorHistory, timepoint);
    }

    /**
     * @dev 返回一个 `timepoint` 的超级法定人数，以投票数表示：`供应量 * 分子 / 分母`。
     * 更多详情请参见 {GovernorSuperQuorum-superQuorum}。
     */
    function superQuorum(uint256 timepoint) public view virtual override returns (uint256) {
        return Math.mulDiv(token().getPastTotalSupply(timepoint), superQuorumNumerator(timepoint), quorumDenominator());
    }

    /**
     * @dev 更改超级法定人数分子。
     *
     * 发出 {SuperQuorumNumeratorUpdated} 事件。
     *
     * 要求：
     *
     * - 必须通过治理提案调用。
     * - 新的超级法定人数分子必须小于或等于分母。
     * - 新的超级法定人数分子必须大于或等于法定人数分子。
     */
    function updateSuperQuorumNumerator(uint256 newSuperQuorumNumerator) public virtual onlyGovernance {
        _updateSuperQuorumNumerator(newSuperQuorumNumerator);
    }

    /**
     * @dev 更改超级法定人数分子。
     *
     * 发出 {SuperQuorumNumeratorUpdated} 事件。
     *
     * 要求：
     *
     * - 新的超级法定人数分子必须小于或等于分母。
     * - 新的超级法定人数分子必须大于或等于法定人数分子。
     */
    function _updateSuperQuorumNumerator(uint256 newSuperQuorumNumerator) internal virtual {
        uint256 denominator = quorumDenominator();
        if (newSuperQuorumNumerator > denominator) {
            revert GovernorInvalidSuperQuorumFraction(newSuperQuorumNumerator, denominator);
        }

        uint256 quorumNumerator = quorumNumerator();
        if (newSuperQuorumNumerator < quorumNumerator) {
            revert GovernorInvalidSuperQuorumTooSmall(newSuperQuorumNumerator, quorumNumerator);
        }

        uint256 oldSuperQuorumNumerator = _superQuorumNumeratorHistory.latest();
        _superQuorumNumeratorHistory.push(clock(), SafeCast.toUint208(newSuperQuorumNumerator));

        emit SuperQuorumNumeratorUpdated(oldSuperQuorumNumerator, newSuperQuorumNumerator);
    }

    /**
     * @dev 重写 {GovernorVotesQuorumFraction-_updateQuorumNumerator} 以确保超级法定人数分子大于或等于法定人数分子。
     */
    function _updateQuorumNumerator(uint256 newQuorumNumerator) internal virtual override {
        // 当 superQuorum 从未设置时忽略检查（构造函数在 superQuorum 之前设置 quorum）
        if (_superQuorumNumeratorHistory.length() > 0) {
            uint256 superQuorumNumerator_ = superQuorumNumerator();
            if (newQuorumNumerator > superQuorumNumerator_) {
                revert GovernorInvalidQuorumTooLarge(newQuorumNumerator, superQuorumNumerator_);
            }
        }
        super._updateQuorumNumerator(newQuorumNumerator);
    }

    /// @inheritdoc GovernorSuperQuorum
    function state(
        uint256 proposalId
    ) public view virtual override(Governor, GovernorSuperQuorum) returns (ProposalState) {
        return super.state(proposalId);
    }
}
