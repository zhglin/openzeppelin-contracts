// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorStorage.sol)

pragma solidity ^0.8.24;

import {Governor} from "../Governor.sol";

/**
 * @dev {Governor} 的扩展，实现了提案详情的存储。此模块还为提案的可枚举性提供了基础功能。
 *
 * 此模块的用例包括：
 * - 无需依赖事件索引即可探索提案状态的用户界面。
 * - 在存储比调用数据（calldata）便宜的L2链上，仅使用 proposalId 作为 {Governor-queue} 和 {Governor-execute} 函数的参数。
 */
abstract contract GovernorStorage is Governor {
    // 提案内容的结构体
    struct ProposalDetails {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        bytes32 descriptionHash;
    }

    // 提案id
    uint256[] private _proposalIds;
    
    // 提案id => 提案内容
    mapping(uint256 proposalId => ProposalDetails) private _proposalDetails;

    /**
     * @dev 挂接到提议机制中
     */
    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal virtual override returns (uint256) {
        uint256 proposalId = super._propose(targets, values, calldatas, description, proposer);

        // 存储
        _proposalIds.push(proposalId);
        _proposalDetails[proposalId] = ProposalDetails({
            targets: targets,
            values: values,
            calldatas: calldatas,
            descriptionHash: keccak256(bytes(description))
        });

        return proposalId;
    }

    /**
     * @dev {IGovernor-queue} 的版本，仅以 `proposalId` 作为参数。
     */
     // super 关键字是当你重写（override）一个与父合约签名完全相同的函数时，用来调用父合约的那个原始版本的。
     // 子合约重新实现一个与父合约签名完全相同的函数。在这种情况下，如果你想在子合约的实现中调用父合约的原始逻辑，就需要使用 super。
    function queue(uint256 proposalId) public virtual {
        // 在这里，使用 storage 比 memory 更高效
        ProposalDetails storage details = _proposalDetails[proposalId];
        queue(details.targets, details.values, details.calldatas, details.descriptionHash);
    }

    /**
     * @dev {IGovernor-execute} 的版本，仅以 `proposalId` 作为参数。
     */
    function execute(uint256 proposalId) public payable virtual {
        // 在这里，使用 storage 比 memory 更高效
        ProposalDetails storage details = _proposalDetails[proposalId];
        execute(details.targets, details.values, details.calldatas, details.descriptionHash);
    }

    /**
     * @dev {IGovernor-cancel} 的 `proposalId` 版本。
     */
    function cancel(uint256 proposalId) public virtual {
        // 在这里，使用 storage 比 memory 更高效
        ProposalDetails storage details = _proposalDetails[proposalId];
        cancel(details.targets, details.values, details.calldatas, details.descriptionHash);
    }

    /**
     * @dev 返回已存储提案的数量。
     */
    function proposalCount() public view virtual returns (uint256) {
        return _proposalIds.length;
    }

    /**
     * @dev 返回一个 proposalId 的详情。如果 `proposalId` 不是一个已知的提案，则会回退。
     */
    function proposalDetails(
        uint256 proposalId
    )
        public
        view
        virtual
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    {
        // 在这里，使用 memory 比 storage 更高效
        ProposalDetails memory details = _proposalDetails[proposalId];
        if (details.descriptionHash == 0) {
            revert GovernorNonexistentProposal(proposalId);
        }
        return (details.targets, details.values, details.calldatas, details.descriptionHash);
    }

    /**
     * @dev 根据提案的顺序索引返回其详情（包括 proposalId）。
     */
    function proposalDetailsAt(
        uint256 index
    )
        public
        view
        virtual
        returns (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        )
    {
        proposalId = _proposalIds[index];
        (targets, values, calldatas, descriptionHash) = proposalDetails(proposalId);
    }
}
