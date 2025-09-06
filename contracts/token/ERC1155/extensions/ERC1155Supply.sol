// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC1155/extensions/ERC1155Supply.sol)

pragma solidity ^0.8.20;

import {ERC1155} from "../ERC1155.sol";
import {Arrays} from "../../../utils/Arrays.sol";

/**
 * @dev ERC-1155 的扩展，增加了按 ID 跟踪总供应量的功能。
 *
 * 在需要明确区分可替代代币和不可替代代币的场景中非常有用。
 * 注意：虽然 totalSupply 为 1 可能意味着对应的是一个 NFT，但不能保证不会再铸造具有相同 ID 的其他代币。
 * 因为它所做的唯一一件事就是“追踪和报告供应量”。
 * 它就像一个记账员，忠实地记录每个 ID被铸造了多少、销毁了多少，然后通过 totalSupply(id) 函数告诉你结果。
 * 它本身不包含任何限制铸造的逻辑。
 * 决定一个 ID 能否被再次铸造的权力，完全掌握在最终合约的实现者（也就是项目开发者）手中。
 * 
 * 注意：此合约意味着可以铸造的代币数量有 2**256 - 1 的全局限制。
 *
 * 警告：此扩展不应在升级到已部署的合约时添加。
 * 
 * 1. 可替代代币 (Fungible Token - FT)
 *  “可替代”意味着每一个代币都是完全相同、可以互换的。它更像是我们平时说的“同质化通证”。
 *  在 ERC1155 中如何体现？
 *      它们是供应量大于 1 的代币
 * 
 * 2. 不可替代代币 (Non-Fungible Token - NFT)
 *  “不可替代”意味着每一个代币都是独一无二、与众不同的。这就是我们通常狭义上说的 NFT。
 *  在 ERC1155 中如何体现？
 *     它们是供应量等于 1 的代币
 */
abstract contract ERC1155Supply is ERC1155 {
    using Arrays for uint256[];

    mapping(uint256 id => uint256) private _totalSupply;
    uint256 private _totalSupplyAll;

    /**
     * @dev 具有给定 ID 的代币的总价值。
     */
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev 所有代币的总价值。
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupplyAll;
    }

    /**
     * @dev 指示是否存在具有给定 ID 的任何代币。
     */
    function exists(uint256 id) public view virtual returns (bool) {
        return totalSupply(id) > 0;
    }

    /// @inheritdoc ERC1155
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        super._update(from, to, ids, values);

        if (from == address(0)) {
            uint256 totalMintValue = 0;
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 value = values.unsafeMemoryAccess(i);
                // 需要溢出检查：代码的其余部分假定 totalSupply 永远不会溢出
                // 从 Solidity 0.8.0 版本开始，语言本身引入了一个重大安全更新：所有的算术运算（加、减、乘、除等）默认都会进行溢出和下溢检查。
                _totalSupply[ids.unsafeMemoryAccess(i)] += value;
                totalMintValue += value;
            }
            // 需要溢出检查：代码的其余部分假定 totalSupplyAll 永远不会溢出
            _totalSupplyAll += totalMintValue;
        }

        if (to == address(0)) {
            uint256 totalBurnValue = 0;
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 value = values.unsafeMemoryAccess(i);

                unchecked {
                    // 不可能溢出：values[i] <= balanceOf(from, ids[i]) <= totalSupply(ids[i])
                    _totalSupply[ids.unsafeMemoryAccess(i)] -= value;
                    // 不可能溢出：sum_i(values[i]) <= sum_i(totalSupply(ids[i])) <= totalSupplyAll
                    totalBurnValue += value;
                }
            }
            unchecked {
                // 不可能溢出：totalBurnValue = sum_i(values[i]) <= sum_i(totalSupply(ids[i])) <= totalSupplyAll
                _totalSupplyAll -= totalBurnValue;
            }
        }
    }
}
