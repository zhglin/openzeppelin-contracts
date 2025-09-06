// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.1.0) (token/ERC721/extensions/ERC721Votes.sol)

pragma solidity ^0.8.24;

import {ERC721} from "../ERC721.sol";
import {Votes} from "../../../governance/utils/Votes.sol";

/**
 * @dev ERC-721 的扩展，以支持由 {Votes} 实现的投票和委托，其中每个单独的 NFT 计为 1 个投票单位。
 *
 * 在被委托之前，代币不计为投票权，因为必须跟踪投票，这会在每次转移时产生额外成本。
 * 代币持有者可以委托给一个受信任的代表，该代表将决定如何在治理决策中利用投票权，
 * 或者他们可以委托给自己，成为自己的代表。
 */
abstract contract ERC721Votes is ERC721, Votes {
    /**
     * @dev 参见 {ERC721-_update}。在代币转移时调整投票权。
     * 触发 {IVotes-DelegateVotesChanged} 事件。
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);

        _transferVotingUnits(previousOwner, to, 1);

        return previousOwner;
    }

    /**
     * @dev 返回 `account` 的余额。
     * 警告：重写此函数可能会导致不正确的投票跟踪。
     */
    function _getVotingUnits(address account) internal view virtual override returns (uint256) {
        return balanceOf(account);
    }

    /**
     * @dev 参见 {ERC721-_increaseBalance}。我们需要它来核算批量铸造的代币。
     */
    function _increaseBalance(address account, uint128 amount) internal virtual override {
        super._increaseBalance(account, amount);
        _transferVotingUnits(address(0), account, amount);
    }
}
