// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorVotesQuorumFraction.sol)

pragma solidity ^0.8.24;

import {GovernorVotes} from "./GovernorVotes.sol";
import {Math} from "../../utils/math/Math.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";
import {Checkpoints} from "../../utils/structs/Checkpoints.sol";

/**
 * @dev {Governor} 的扩展，用于从 {ERC20Votes} 代币中提取投票权重，并将法定人数表示为总供应量的一部分。
 */
abstract contract GovernorVotesQuorumFraction is GovernorVotes {
    using Checkpoints for Checkpoints.Trace208;

    Checkpoints.Trace208 private _quorumNumeratorHistory;

    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

    /**
     * @dev 设置的法定人数不是一个有效的分数。
     */
    error GovernorInvalidQuorumFraction(uint256 quorumNumerator, uint256 quorumDenominator);

    /**
     * @dev 将法定人数初始化为代币总供应量的一部分。
     *
     * 该分数被指定为 `分子 / 分母`。默认情况下，分母是100，因此法定人数被指定为百分比：分子为10对应于法定人数是总供应量的10%。分母可以通过重写 {quorumDenominator} 来定制。
     */
    constructor(uint256 quorumNumeratorValue) {
        _updateQuorumNumerator(quorumNumeratorValue);
    }

    /**
     * @dev 返回当前的法定人数分子。参见 {quorumDenominator}。
     */
    function quorumNumerator() public view virtual returns (uint256) {
        return _quorumNumeratorHistory.latest();
    }

    /**
     * @dev 返回特定时间点的法定人数分子。参见 {quorumDenominator}。
     */
    function quorumNumerator(uint256 timepoint) public view virtual returns (uint256) {
        return _optimisticUpperLookupRecent(_quorumNumeratorHistory, timepoint);
    }

    /**
     * @dev 返回法定人数分母。默认为100，但可以被重写。
     */
    function quorumDenominator() public view virtual returns (uint256) {
        return 100;
    }

    /**
     * @dev 返回一个时间点的法定人数，以投票数表示：`供应量 * 分子 / 分母`。
     */
    function quorum(uint256 timepoint) public view virtual override returns (uint256) {
        return Math.mulDiv(token().getPastTotalSupply(timepoint), quorumNumerator(timepoint), quorumDenominator());
    }

    /**
     * @dev 更改法定人数分子。
     *
     * 发出 {QuorumNumeratorUpdated} 事件。
     *
     * 要求：
     *
     * - 必须通过治理提案调用。
     * - 新的分子必须小于或等于分母。
     */
    function updateQuorumNumerator(uint256 newQuorumNumerator) external virtual onlyGovernance {
        _updateQuorumNumerator(newQuorumNumerator);
    }

    /**
     * @dev 更改法定人数分子。
     *
     * 发出 {QuorumNumeratorUpdated} 事件。
     *
     * 要求：
     *
     * - 新的分子必须小于或等于分母。
     */
    function _updateQuorumNumerator(uint256 newQuorumNumerator) internal virtual {
        uint256 denominator = quorumDenominator();
        if (newQuorumNumerator > denominator) {
            revert GovernorInvalidQuorumFraction(newQuorumNumerator, denominator);
        }

        uint256 oldQuorumNumerator = quorumNumerator();
        _quorumNumeratorHistory.push(clock(), SafeCast.toUint208(newQuorumNumerator));

        emit QuorumNumeratorUpdated(oldQuorumNumerator, newQuorumNumerator);
    }

    /**
     * @dev 返回特定时间点的分子。
     */
    function _optimisticUpperLookupRecent(
        Checkpoints.Trace208 storage ckpts,
        uint256 timepoint
    ) internal view returns (uint256) {
        // 如果轨迹为空，则键和值都等于0。
        // 在那种情况下，`key <= timepoint` 为真，返回0是可行的。
        (, uint48 key, uint208 value) = ckpts.latestCheckpoint();
        return key <= timepoint ? value : ckpts.upperLookupRecent(SafeCast.toUint48(timepoint));
    }
}
