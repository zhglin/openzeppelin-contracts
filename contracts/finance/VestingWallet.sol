// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (finance/VestingWallet.sol)
pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {SafeERC20} from "../token/ERC20/utils/SafeERC20.sol";
import {Address} from "../utils/Address.sol";
import {Context} from "../utils/Context.sol";
import {Ownable} from "../access/Ownable.sol";

/**
 * @dev 归属钱包是一个可拥有合约，可以接收原生货币和 ERC-20 代币，并根据归属时间表将这些资产释放给钱包所有者（也称为“受益人”）。
 *
 * 任何转移到此合约的资产都将遵循归属时间表，就像它们从一开始就被锁定一样。
 * 因此，如果归属已经开始，发送到此合约的任何数量的代币都将（至少部分）立即可释放。
 *
 * 通过将持续时间设置为 0，可以将此合约配置为像资产时间锁一样，为受益人持有代币直到指定时间。
 *
 * 注意：由于钱包是 {Ownable} 的，并且所有权可以转移，因此可以出售未归属的代币。
 * 在智能合约中防止这种情况很困难，考虑到：1）受益人地址可能是一个反事实部署的合约，2）EOA 在不久的将来很可能会有成为合约的迁移路径。
 *
 * 注意：当将此合约与任何余额自动调整的代币（即变基代币）一起使用时，请确保在归属时间表中考虑供应/余额调整，以确保归属金额符合预期。
 *
 * 注意：支持原生 ERC20 的链可能允许归属钱包以 ERC20 和原生货币两种形式提取基础资产。例如，如果链 C 支持代币 A，并且向钱包存入 100 A，那么在归属期的 50% 时，受益人可以提取 50 A 作为 ERC20 和 25 A 作为原生货币（总计 75 A）。
 * 考虑禁用其中一种提款方法。
 */

/*
    注意：由于钱包是 {Ownable} 的，并且所有权可以转移，因此可以出售未归属的代币。
        详细解读：
            * 核心问题：VestingWallet 合约本身是“可拥有”的，其所有者就是代币的最终受益人。因为所有权 (ownership)
                可以像其他资产一样被转移，所以受益人可以通过将整个 VestingWallet合约的所有权转让给买家，来间接“出售”他们未来才能解锁的代币。
                买家会成为新的受益人，并在归属期结束后获得代币。
            * 为何难以阻止：注释中解释了为什么在智能合约层面很难禁止这种行为：
                1. 受益人可能是合约：受益人地址不一定是一个普通用户钱包（EOA），它可能是一个尚未部署但地址已知的“反事实合约”。
                    这种合约的行为逻辑是未知的，使得限制转让变得非常困难。
                2. 账户抽象的未来：以太坊等区块链正在朝着“账户抽象”的方向发展，未来普通用户钱包（EOA）可能会升级成智能合约钱包。
                    这意味着，即使现在试图通过“只允许转让给非合约地址”的规则来限制，这种方法在未来也可能会失效。

    结论：您需要意识到，使用这个合约不等于完全锁定了代币的流动性。
    它锁定了代币的释放时间，但无法阻止受益人通过转让合约所有权的方式来提前交易这份未来的权益。
*/

/*
    原文摘要：注意：当将此合约与任何余额自动调整的代币（即变基代币）一起使用时，请确保在归属时间表中考虑供应/余额调整，以确保归属金额符合预期。
        详细解读：
            * 核心问题：变基代币是一种特殊的 ERC-20 代币，其供应量会动态调整，导致您钱包里的代币数量自动增加或减少。
                例如，Ampleforth (AMPL)就是一种著名的变基代币。
            * 对归属的影响：VestingWallet计算可释放金额时，是基于合约当前持有的代币余额。
                如果这是一个变基代币，合约的余额会因为变基机制而改变，这会直接影响归属计算的结果。
                    * 如果代币数量因正向变基而增加，那么根据归属百分比计算出的可释放数量也会超出预期。
                    * 反之，如果因负向变基而减少，受益人最终能拿到的代币数量就会少于预期。
        * 如何应对：如果您必须使用变基代币进行归属，您不能简单地按照“总共锁定1000个币”来思考。
            您需要深入理解该代币的变基机制，并在设计归属方案时将余额的动态变化考虑进去，以确保最终释放给受益人的价值是符合预期的，而不是数量。
    结论：VestingWallet与变基代币的兼容性不佳。除非您完全清楚如何处理其余额变化，否则最好避免将它们一起使用，以免造成归属金额与预期严重不符。    
*/

/*
    关于支持原生 ERC-20 的链
    详细解读：
        * 核心问题：在某些区块链上（例如某些 Layer 2 解决方案），其原生代币（类似于以太坊上的 ETH）本身就符合 ERC-20 标准，
            或者与一个 ERC-20版本的代币（如 WETH）紧密耦合。
        * 双重提款风险：在这种情况下，VestingWallet 合约可能会产生一个漏洞。假设您向合约存入了 100 个这种“原生 ERC-20”代币 "A"。
            * 合约的 address(this).balance (原生代币余额) 可能会显示有 100 A。
            * 同时，合约调用代币 "A" 的 balanceOf(address(this)) (ERC-20 余额) 也可能显示有 100 A。
        * 例子中的漏洞：当归属期达到 50% 时：
            1. 受益人可以调用 release(tokenAddress) 来释放 50 个 A (作为 ERC-20)。
            2. 然后，受益人还可以调用 release() (无参数版本) 来释放原生代币。
                此时，合约的原生代币余额可能仍然被认为是 100 A(或者在某些实现中是剩余的 50 A)，导致他可以再提取一部分原生代币。
                注释中的例子是总共提取了 75 A，远超 50% 的归属额度。
        * 如何应对：为了防止这种“双重提款”漏洞，注释建议您在继承和使用 VestingWallet时，考虑重写（override）并禁用其中一个提款函数。
            例如，您可以重写 release() 函数，使其直接报错，从而只允许通过 release(tokenAddress)来提取 ERC-20 代币。
    结论：在部署到具有原生 ERC-20 特性的链上时，这是一个严重的安全隐患。
        您必须修改合约，禁用其中一种提款方式，以防止受益人提取超出其归属额度的资金。
*/

/*
    它的主要作用是管理代币的归属（vesting）。
    简单来说，您可以把代币（包括以太币和 ERC-20 代币）发送到这个合约里，合约会根据预先设定的时间表，逐步地将这些代币释放给指定的受益人。
    这在很多场景下都很有用，例如：
        * 团队激励：项目方可以将一部分代币锁在 VestingWallet 中，分发给团队成员，
            并设定一个归属计划（比如 4年内逐步解锁）。这可以激励团队成员长期为项目服务。
        * 投资者份额：同样地，可以用来管理分配给投资者的代币，确保他们不会在项目初期就抛售大量代币，从而稳定币价。
    这个合约是“可拥有”的（Ownable），意味着受益人地址可以被更改，这提供了一定的灵活性，比如受益人可以出售自己尚未完全解锁的代币份额。
    总而言之，VestingWallet 是一个用于锁定和逐步释放资产的工具，以实现长期的价值绑定和激励。
*/
contract VestingWallet is Context, Ownable {
    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);

    // 已释放的以太币数量
    uint256 private _released;
    // 每种代币已释放的数量
    mapping(address token => uint256) private _erc20Released;
    // 归属开始时间戳
    uint64 private immutable _start;
    // 归属持续时间（以秒为单位）
    uint64 private immutable _duration;

    /**
     * @dev 设置归属钱包的受益人（所有者）、开始时间戳和归属持续时间（以秒为单位）。
     */
    constructor(address beneficiary, uint64 startTimestamp, uint64 durationSeconds) payable Ownable(beneficiary) {
        _start = startTimestamp;
        _duration = durationSeconds;
    }

    /**
     * @dev 合约应该能够接收以太币。
     */
    receive() external payable virtual {}

    /**
     * @dev 获取开始时间戳。
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev 获取归属持续时间。
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev 获取结束时间戳。
     */
    function end() public view virtual returns (uint256) {
        return start() + duration();
    }

    /**
     * @dev 已释放的以太币数量。
     */
    function released() public view virtual returns (uint256) {
        return _released;
    }

    /**
     * @dev 已释放的代币数量。
     */
    function released(address token) public view virtual returns (uint256) {
        return _erc20Released[token];
    }

    /**
     * @dev 获取可释放的以太币数量。
     */
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev 获取可释放的 `token` 代币数量。`token` 应该是 {IERC20} 合约的地址。
     */
    function releasable(address token) public view virtual returns (uint256) {
        return vestedAmount(token, uint64(block.timestamp)) - released(token);
    }

    /**
     * @dev 释放已经归属的原生代币（以太币）。
     *
     * 触发 {EtherReleased} 事件。
     */
    function release() public virtual {
        uint256 amount = releasable();
        _released += amount;
        emit EtherReleased(amount);
        Address.sendValue(payable(owner()), amount);
    }

    /**
     * @dev 释放已经归属的代币。
     *
     * 触发 {ERC20Released} 事件。
     */
    function release(address token) public virtual {
        uint256 amount = releasable(token);
        _erc20Released[token] += amount;
        emit ERC20Released(token, amount);
        SafeERC20.safeTransfer(IERC20(token), owner(), amount);
    }

    /**
     * @dev 计算已经归属的以太币数量。默认实现是线性归属曲线。
     */
    function vestedAmount(uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(address(this).balance + released(), timestamp);
    }

    /**
     * @dev 计算已经归属的代币数量。默认实现是线性归属曲线。
     */
    function vestedAmount(address token, uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(IERC20(token).balanceOf(address(this)) + released(token), timestamp);
    }

    /**
     * @dev 归属公式的虚拟实现。对于给定的总历史分配，此函数返回归属金额作为时间的函数。
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= end()) {
            return totalAllocation;
        } else {
            // 线性归属
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }
}
