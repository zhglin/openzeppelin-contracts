// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.24;

import {Governor} from "../Governor.sol";
import {IVotes} from "../utils/IVotes.sol";
import {IERC5805} from "../../interfaces/IERC5805.sol";
import {Time} from "../../utils/types/Time.sol";

/**
 * @dev {Governor} 的扩展，用于从 {ERC20Votes} 代币（或自 v4.5 版本起的 {ERC721Votes} 代币）中提取投票权重。
 */
abstract contract GovernorVotes is Governor {
    IERC5805 private immutable _token;

    constructor(IVotes tokenAddress) {
        _token = IERC5805(address(tokenAddress));
    }

    /**
     * @dev 投票权的来源代币。
     */
    function token() public view virtual returns (IERC5805) {
        return _token;
    }

    /**
     * @dev 时钟（如 ERC-6372 中所规定）被设置为与代币的时钟匹配。
     * 如果代币未实现 ERC-6372，则回退到使用区块号。
     */
    function clock() public view virtual override returns (uint48) {
        try token().clock() returns (uint48 timepoint) {
            return timepoint;
        } catch {
            return Time.blockNumber();
        }
    }

    /**
     * @dev ERC-6372 中规定的时钟的机器可读描述。
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual override returns (string memory) {
        try token().CLOCK_MODE() returns (string memory clockmode) {
            return clockmode;
        } catch {
            return "mode=blocknumber&from=default";
        }
    }

    /**
     * @dev 从代币内置的快照机制中读取投票权重（参见 {Governor-_getVotes}）。
     */
    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory /*params*/
    ) internal view virtual override returns (uint256) {
        return token().getPastVotes(account, timepoint);
    }
}
