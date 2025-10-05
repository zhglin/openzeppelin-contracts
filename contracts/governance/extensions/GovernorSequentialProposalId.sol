// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorSequentialProposalId.sol)

pragma solidity ^0.8.24;

import {IGovernor, Governor} from "../Governor.sol";

/**
 * @dev {Governor} 的扩展，将提案ID的编号方式从默认的基于哈希的方法更改为顺序ID。
 */
abstract contract GovernorSequentialProposalId is Governor {
    // 最后一个提案ID
    uint256 private _latestProposalId;

    // 提案哈希到提案ID的映射
    mapping(uint256 proposalHash => uint256 proposalId) private _proposalIds;

    /**
     * @dev {latestProposalId} 只能在尚未设置时（通过初始化或创建提案）进行初始化。
     */
    error GovernorAlreadyInitializedLatestProposalId();

    /// @inheritdoc IGovernor
    function getProposalId(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public view virtual override returns (uint256) {
        uint256 proposalHash = hashProposal(targets, values, calldatas, descriptionHash);
        uint256 storedProposalId = _proposalIds[proposalHash];
        // 必须先进行propose才能获取提案ID。
        if (storedProposalId == 0) {
            revert GovernorNonexistentProposal(0);
        }
        return storedProposalId;
    }

    /**
     * @dev 返回最新的提案ID。返回值为0意味着尚未创建任何提案。
     */
    function latestProposalId() public view virtual returns (uint256) {
        return _latestProposalId;
    }

    /**
     * @dev 参见 {IGovernor-_propose}。
     * 挂接到提议机制中以增加提案计数。
     */
    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal virtual override returns (uint256) {
        uint256 proposalHash = hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        uint256 storedProposalId = _proposalIds[proposalHash];
        // 设置提案ID（如果还没有设置的话）。
        if (storedProposalId == 0) {
            _proposalIds[proposalHash] = ++_latestProposalId;
        }
        // 调用父合约的 _propose 方法。
        return super._propose(targets, values, calldatas, description, proposer);
    }

    /**
     * @dev 用于设置 {latestProposalId} 的内部函数。当从另一个治理系统迁移时，此函数很有用。
     * 下一个提案ID将是 `newLatestProposalId` + 1。
     *
     * 仅当 {latestProposalId} 的当前值为0时才能调用此函数。
     */
    function _initializeLatestProposalId(uint256 newLatestProposalId) internal virtual {
        if (_latestProposalId != 0) {
            revert GovernorAlreadyInitializedLatestProposalId();
        }
        _latestProposalId = newLatestProposalId;
    }
}
