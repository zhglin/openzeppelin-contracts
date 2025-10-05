// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorProposalGuardian.sol)

pragma solidity ^0.8.24;

import {Governor} from "../Governor.sol";

/**
 * @dev {Governor} 的扩展，增加了一个提案监护人，可以在提案生命周期的任何阶段取消提案。
 *
 * 注意：如果未配置提案监护人，则提案人将为其提案担任此角色。
 */
abstract contract GovernorProposalGuardian is Governor {
    address private _proposalGuardian;

    event ProposalGuardianSet(address oldProposalGuardian, address newProposalGuardian);

    /**
     * @dev 返回提案监护人地址的 Getter 函数。
     */
    function proposalGuardian() public view virtual returns (address) {
        return _proposalGuardian;
    }

    /**
     * @dev 更新提案监护人的地址。此操作只能通过治理提案执行。
     *
     * 发出 {ProposalGuardianSet} 事件。
     */
    function setProposalGuardian(address newProposalGuardian) public virtual onlyGovernance {
        _setProposalGuardian(newProposalGuardian);
    }

    /**
     * @dev 提案监护人的内部 setter 函数。
     *
     * 发出 {ProposalGuardianSet} 事件。
     */
    function _setProposalGuardian(address newProposalGuardian) internal virtual {
        emit ProposalGuardianSet(_proposalGuardian, newProposalGuardian);
        _proposalGuardian = newProposalGuardian;
    }

    /**
     * @dev 重写 {Governor-_validateCancel} 以实现扩展的取消逻辑。
     *
     * * {proposalGuardian} 可以在任何时间点取消任何提案。
     * * 如果未设置提案监护人，{IGovernor-proposalProposer} 可以在任何时间点取消他们的提案。
     * * 在任何情况下，在 {Governor-_validateCancel}（或其他重写）中定义的权限仍然有效。
     */
    function _validateCancel(uint256 proposalId, address caller) internal view virtual override returns (bool) {
        address guardian = proposalGuardian();

        return
            guardian == caller ||
            (guardian == address(0) && caller == proposalProposer(proposalId)) ||
            super._validateCancel(proposalId, caller);
    }
}