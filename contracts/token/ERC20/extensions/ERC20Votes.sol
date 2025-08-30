// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.24;

import {ERC20} from "../ERC20.sol";
import {Votes} from "../../../governance/utils/Votes.sol";
import {Checkpoints} from "../../../utils/structs/Checkpoints.sol";

/**
 * @dev 对 ERC-20 的扩展，以支持类似 Compound 的投票和委托功能。此版本比 Compound 的更通用，
 * 支持最高达 2^208^ - 1 的代币供应量，而 COMP 的上限为 2^96^ - 1。
 *
 * 注意：此合约不提供与 Compound 的 COMP 代币的接口兼容性。
 *
 * 此扩展为每个账户的投票权保留一份历史记录（检查点）。投票权可以通过直接调用 {Votes-delegate} 函数来委托，
 * 或者通过提供一个用于 {Votes-delegateBySig} 的签名来委托。投票权可以通过公开的访问器 {Votes-getVotes} 和 {Votes-getPastVotes} 进行查询。
 *
 * 默认情况下，代币余额不计入投票权。这使得转账成本更低。
 * 缺点是，它要求用户将投票权委托给自己，以激活检查点并使其投票权被追踪。delegate(自己的地址)
 * 
 * ERC20Votes实现的是“一个代币一票”的财阀（Plutocracy）或股东（Shareholder）治理模式
 * 1. 抗女巫攻击 (Sybil Resistance)
 *      这是最主要的原因。在匿名的区块链上，我无法知道你是谁。如果实行“一人一票”，攻击者可以轻易地创建 10,000 个钱包地址
 *      从而获得 10,000票。这种攻击被称为“女巫攻击”。
 *      而“一币一票”模式可以很好地抵抗这种攻击。攻击者要想获得 10,000 票，他就必须去市场上真金白银地购买 10,000个代币，
 *      这需要付出巨大的经济成本，从而使攻击变得不划算。
 * 2. 利益绑定 (Skin in the Game)
 *      “一币一票”模式将决策权与经济利益深度绑定。持有代币越多的实体，其身家利益与这个协议的兴衰关联就越紧密。
 *      理论上，这会激励他们做出更有利于协议长期发展的决策，因为如果决策失误导致协议失败，他们将是损失最大的人。
 */
abstract contract ERC20Votes is ERC20, Votes {
    /**
     * @dev 已超过总供应量上限，存在票数溢出的风险。
     */
    error ERC20ExceededSafeSupply(uint256 increasedSupply, uint256 cap);

    /**
     * @dev 最大代币供应量。默认为 `type(uint208).max` (2^208^ - 1)。
     *
     * 这个最大值在 {_update} 中被强制执行。它限制了代币的总供应量（该值本应是 uint256），
     * 以便检查点可以存储在 {Votes} 使用的 Trace208 结构中。增加此值不会移除底层的限制，
     * 并且会因为 {Votes-_transferVotingUnits} 中的数学溢出而导致 {_update} 失败。如果额外的逻辑需要，
     * 可以通过重写（override）来进一步限制总供应量（到一个更低的值）。当解决此函数的重写冲突时，应返回最小值。
     */
    function _maxSupply() internal view virtual returns (uint256) {
        return type(uint208).max;
    }

    /**
     * @dev 在代币转移时移动投票权。
     * 触发 {IVotes-DelegateVotesChanged} 事件。
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);
        if (from == address(0)) {
            uint256 supply = totalSupply();
            uint256 cap = _maxSupply();
            if (supply > cap) {
                revert ERC20ExceededSafeSupply(supply, cap);
            }
        }
        _transferVotingUnits(from, to, value);
    }

    /**
     * @dev 返回一个 `account` 的投票单位。
     * 警告：重写此函数可能会危及内部的投票核算机制。
     * `ERC20Votes` 假定代币与投票单位是 1:1 映射的，这一点不容易改变。
     * 
     * ERC20Votes 的内部逻辑是紧密耦合的。它期望 _getVotingUnits 返回的“存量”与 _transferVotingUnits中传递的“流量”在数学上是匹配的。
     * 强行改变，就破坏了这个基本假设，导致系统无法正常运转。
     * 减法可能会发生数学下溢（subtraction underflow），导致整个交易失败回滚。
     */
    function _getVotingUnits(address account) internal view virtual override returns (uint256) {
        return balanceOf(account);
    }

    /**
     * @dev 获取 `account` 的检查点数量。
     */
    function numCheckpoints(address account) public view virtual returns (uint32) {
        return _numCheckpoints(account);
    }

    /**
     * @dev 获取 `account` 的第 `pos` 个检查点。
     */
    function checkpoints(address account, uint32 pos) public view virtual returns (Checkpoints.Checkpoint208 memory) {
        return _checkpoints(account, pos);
    }
}
