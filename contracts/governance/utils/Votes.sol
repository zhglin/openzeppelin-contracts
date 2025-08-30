// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (governance/utils/Votes.sol)
pragma solidity ^0.8.24;

import {IERC5805} from "../../interfaces/IERC5805.sol";
import {Context} from "../../utils/Context.sol";
import {Nonces} from "../../utils/Nonces.sol";
import {EIP712} from "../../utils/cryptography/EIP712.sol";
import {Checkpoints} from "../../utils/structs/Checkpoints.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";
import {ECDSA} from "../../utils/cryptography/ECDSA.sol";
import {Time} from "../../utils/types/Time.sol";

/**
 * @dev 这是一个基础抽象合约，用于追踪“投票单位”（voting units），这是一种可以转移的投票权度量。
 * 它提供了一套投票委托系统，账户可以将其投票单位委托给一个“代表”，该代表可以汇集来自不同账户的委托投票单位，
 * 并用其在决策中投票。实际上，投票单位**必须**被委托才能计为实际选票，如果一个账户希望参与决策且没有信任的代表，
 * 它必须将投票权委托给自己。
 *
 * 这个合约通常与一个代币合约结合，使得投票单位与代币单位相对应。例如，请参阅 {ERC721Votes}。
 *
 * 委托投票的完整历史记录在链上被追踪，以便治理协议可以将在特定区块号时分布的投票考虑在内，
 * 以防止闪电贷攻击和双重投票。这种“选择性加入”（opt-in）的委托系统使得历史记录追踪的成本成为可选的。
 *
 * 当使用此模块时，派生合约必须实现 {_getVotingUnits}（例如，使其返回 {ERC721-balanceOf}），
 * 并且可以使用 {_transferVotingUnits} 来追踪这些单位分布的变化（在前面的例子中，它将被包含在 {ERC721-_update} 中）。
 */

/**
 * 安全性：防止通过闪电贷等金融工具在短时间内获得大量虚假投票权来操纵治理。
 * 公平性：确保投票权与对协议的长期持有和承诺成正比，而不是临时的资金实力。
 * 防止双重投票：防止用户在投票后转移代币给他人，让同一批代币在同一提案中被多次使用。
 */

abstract contract Votes is Context, EIP712, Nonces, IERC5805 {
    using Checkpoints for Checkpoints.Trace208;

    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address account => address) private _delegatee;

    mapping(address delegatee => Checkpoints.Trace208) private _delegateCheckpoints;

    Checkpoints.Trace208 private _totalCheckpoints;

    /**
     * @dev 时钟被错误地修改了。
     */
    error ERC6372InconsistentClock();

    /**
     * @dev 无法查询未来的投票。
     */
    error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

    /**
     * @dev 用于标记检查点的时钟。可以被重写以实现基于时间戳的检查点（和投票），
     * 在这种情况下，{CLOCK_MODE} 也应被重写以匹配。
     */
    function clock() public view virtual returns (uint48) {
        return Time.blockNumber();
    }

    /**
     * @dev 根据 ERC-6372 规范，提供对时钟的机器可读的描述。
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        // 检查时钟是否被修改
        if (clock() != Time.blockNumber()) {
            revert ERC6372InconsistentClock();
        }
        return "mode=blocknumber&from=default";
    }

    /**
     * @dev 验证一个时间点是否在过去，并将其作为 uint48 返回。
     */
    function _validateTimepoint(uint256 timepoint) internal view returns (uint48) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) revert ERC5805FutureLookup(timepoint, currentTimepoint);
        return SafeCast.toUint48(timepoint);
    }

    /**
     * @dev 返回 `account` 当前拥有的投票数量。
     * 
     * getVotes() 返回 1000：这是你当前的投票潜力，代表你为未来的提案所做的准备。
     * getPastVotes() 返回 0：这是你对于那个特定的、过去的提案的实际投票能力。
     */
    function getVotes(address account) public view virtual returns (uint256) {
        return _delegateCheckpoints[account].latest();
    }

    /**
     * @dev 返回 `account` 在过去某一特定时间点拥有的投票数量。如果 `clock()` 被配置为使用区块号，
     * 则此函数将返回相应区块结束时的值。
     *
     * 要求：
     * - `timepoint` 必须在过去。如果使用区块号操作，该区块必须已被挖出。
     * 
     * 系统用的是 getPastVotes() 来获取提案快照时的票数，以确保公平和安全。
     * getPastVotes的设计目的，就是为了查询“历史状态”，从而防止用户在提案创建后，通过购买代币或借用代币（闪电贷）来临时增加票数，操纵投票结果。
     * timepoint 这个参数通常不是由投票的用户来设置的，而是由治理合约在内部自动管理的。一个标准的 DAO 治理流程如下：
     * 1. 创建提案 (Proposal Creation)
     *      用户调用治理合约的 propose() 函数来提交一项新提案。
     *      在 propose() 函数执行时，治理合约会立刻读取当前的区块号，并将其作为“快照区块”保存下来。
     *      例如：proposal.snapshotBlock = block.number;
     *      这个 snapshotBlock 会和提案的其他信息（如描述、执行代码等）一起被永久记录在链上。
     * 
     * 你必须在提案创建之前，就完成投票权的委托。
     *  这就像现实世界中的选举：
     *  选举登记截止日期：可以看作是提案创建的“快照区块”。
     *  你的授权（`delegate`）：相当于你去政府部门进行“选民登记”。
     *  如果你在“选举登记截止日期”之后才去登记，那么你将无法参与本次选举，但好消息是，你的登记已经生效，对于未来的所有选举，你都拥有了投票资格。
     */
    function getPastVotes(address account, uint256 timepoint) public view virtual returns (uint256) {
        return _delegateCheckpoints[account].upperLookupRecent(_validateTimepoint(timepoint));
    }

    /**
     * @dev 返回过去某一特定时间点的总投票供应量。如果 `clock()` 被配置为使用区块号，
     * 则此函数将返回相应区块结束时的值。
     *
     * 注意：这个值是所有可用投票的总和，不一定是所有已委托投票的总和。
     * 尚未被委托的投票仍然是总供应量的一部分，即使它们不会参与投票。
     *
     * 要求：
     * - `timepoint` 必须在过去。如果使用区块号操作，该区块必须已被挖出。
     */
    function getPastTotalSupply(uint256 timepoint) public view virtual returns (uint256) {
        return _totalCheckpoints.upperLookupRecent(_validateTimepoint(timepoint));
    }

    /**
     * @dev 返回当前的总投票供应量。
     */
    function _getTotalSupply() internal view virtual returns (uint256) {
        return _totalCheckpoints.latest();
    }

    /**
     * @dev 返回 `account` 已选择的投票委托人。
     */
    function delegates(address account) public view virtual returns (address) {
        return _delegatee[account];
    }

    /**
     * @dev 将投票权从发送者委托给 `delegatee`。
     */
    function delegate(address delegatee) public virtual {
        address account = _msgSender();
        _delegate(account, delegatee);
    }

    /**
     * @dev 将投票权从签名者委托给 `delegatee`。
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > expiry) {
            revert VotesExpiredSignature(expiry);
        }
        address signer = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );
        _useCheckedNonce(signer, nonce);
        _delegate(signer, delegatee);
    }

    /**
     * @dev 将 `account` 的所有投票单位委托给 `delegatee`。
     * 触发 {IVotes-DelegateChanged} 和 {IVotes-DelegateVotesChanged} 事件。
     */
    function _delegate(address account, address delegatee) internal virtual {
        address oldDelegate = delegates(account);
        _delegatee[account] = delegatee;

        emit DelegateChanged(account, oldDelegate, delegatee);
        _moveDelegateVotes(oldDelegate, delegatee, _getVotingUnits(account));
    }

    /**
     * @dev 转移、铸造或销毁投票单位。若要注册一次铸造，`from` 应为零地址。若要注册一次销毁，`to` 应为零地址。
     * 投票单位的总供应量将随着铸造和销毁而调整。
     */
    function _transferVotingUnits(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            _push(_totalCheckpoints, _add, SafeCast.toUint208(amount));
        }
        if (to == address(0)) {
            _push(_totalCheckpoints, _subtract, SafeCast.toUint208(amount));
        }
        _moveDelegateVotes(delegates(from), delegates(to), amount);
    }

    /**
     * @dev 将委托的投票从一个委托人转移到另一个。
     */
    function _moveDelegateVotes(address from, address to, uint256 amount) internal virtual {
        // 不能多次转移给自己,只能转移给自己一次.
        if (from != to && amount > 0) {
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[from],
                    _subtract,
                    SafeCast.toUint208(amount)
                );
                emit DelegateVotesChanged(from, oldValue, newValue);
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[to],
                    _add,
                    SafeCast.toUint208(amount)
                );
                emit DelegateVotesChanged(to, oldValue, newValue);
            }
        }
    }

    /**
     * @dev 获取 `account` 的检查点数量。
     */
    function _numCheckpoints(address account) internal view virtual returns (uint32) {
        return SafeCast.toUint32(_delegateCheckpoints[account].length());
    }

    /**
     * @dev 获取 `account` 的第 `pos` 个检查点。
     */
    function _checkpoints(
        address account,
        uint32 pos
    ) internal view virtual returns (Checkpoints.Checkpoint208 memory) {
        return _delegateCheckpoints[account].at(pos);
    }

    function _push(
        Checkpoints.Trace208 storage store,
        function(uint208, uint208) view returns (uint208) op,
        uint208 delta
    ) private returns (uint208 oldValue, uint208 newValue) {
        return store.push(clock(), op(store.latest(), delta));
    }

    function _add(uint208 a, uint208 b) private pure returns (uint208) {
        return a + b;
    }

    function _subtract(uint208 a, uint208 b) private pure returns (uint208) {
        return a - b;
    }

    /**
     * @dev 必须返回一个账户所持有的投票单位。
     */
    function _getVotingUnits(address) internal view virtual returns (uint256);
}
