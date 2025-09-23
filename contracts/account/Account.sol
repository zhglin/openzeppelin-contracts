// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (account/Account.sol)

pragma solidity ^0.8.20;

import {PackedUserOperation, IAccount, IEntryPoint} from "../interfaces/draft-IERC4337.sol";
import {ERC4337Utils} from "./utils/draft-ERC4337Utils.sol";
import {AbstractSigner} from "../utils/cryptography/signers/AbstractSigner.sol";

/**
 * @dev 一个简单的 ERC4337 账户实现。此基础实现仅包含处理用户操作的最基本逻辑。
 *
 * 开发人员必须实现 {AbstractSigner-_rawSignatureValidation} 函数来定义账户的验证逻辑。
 *
 * 注意：此核心账户不包含任何用于执行任意外部调用的机制。这是所有账户都应具备的基本功能。
 * 我们将其留给开发人员来实现他们选择的机制。
 * 常见的选择包括 ERC-6900、ERC-7579 和 ERC-7821（等等）。
 *
 * 重要提示：实现验证签名的机制是一项对安全敏感的操作，因为它可能允许攻击者绕过账户的安全措施。
 * 请查看 {SignerECDSA}、{SignerP256} 或 {SignerRSA}以获取数字签名验证的实现。
 *
 * @custom:stateless
 */
/**
 * 1. 它为什么是一个“ERC4337账户实现”？
 *  这部分意味着 Account.sol 严格遵守了 ERC-4337 标准中对一个智能合约钱包所规定的所有基本规则和接口。
 *  它能被 EntryPoint合约正确地识别和调用，可以“说” ERC-4337 的官方语言。
 *  具体体现在：
 *  实现了 `validateUserOp` 函数: 这是最重要的规则。EntryPoint 需要通过调用这个函数来验证用户操作的合法性。
 *      Account.sol完整地实现了这个函数的结构。
 *  知道如何与 `EntryPoint` 交互: 它知道 EntryPoint 的地址，并且通过调用 entryPoint().getNonce(...) 来正确地获取防重放攻击的 Nonce 值。
 *  实现了预付款逻辑: 它包含了 _payPrefund 逻辑，懂得在 EntryPoint 要求时，向其支付执行操作所需的预付 Gas 费用。
 * 2. 它为什么是“简单的”？
 *  “简单”是这句话的精髓。它意味着 Account.sol 仅仅实现了上述的“最基本要求”，而省略了所有让一个钱包变得真正有用的高级功能。
 *  具体“简单”在以下几点：
 *  【最重要】缺少执行逻辑: 这个 Account.sol 合约没有提供任何方法来实际执行 `UserOperation` 中的指令。
 *      它能验证一个操作是合法的，但验证通过后，UserOperation 中包含的 callData（例如，调用 Uniswap 进行交易的数据）没有地方去执行。
 *      一个真正可用的钱包必须有一个 execute 或类似的功能，允许它调用其他合约。
 *  缺少具体的签名方案: 它定义了需要一个 _rawSignatureValidation 函数来验签，但它本身是 abstract（抽象）的，
 *      并没有提供任何具体的实现。它没有告诉你应该用标准的 EOA 签名，还是多重签名，还是其他方案。这个最核心的安全模块需要开发者自己来“安装”。
 *  缺少所有权/密钥管理: 合约里没有设置或更改所有者的功能。一个真实的钱包需要有方法来转移所有权，或者管理多个密钥。
 *  缺少所有高级功能: 诸如社交恢复、每日消费限额、交易白名单、批量交易等所有能提升用户体验和安全性的功能，这个“简单”的实现里全都没有。 
 */

/**
 * payPrefund 函数的存在是为了解决 ERC-4337 模型中的一个核心经济问题：
 *  谁来为交易支付初始的 Gas 费，以及如何确保支付 Gas 费的人（Bundler）不会亏钱？
 * 简单来说，_payPrefund 函数是你的 Account 合约向 EntryPoint 合约预付或补足 Gas 费押金的机制。
 * 我们来梳理一下这个流程，您就能明白它为什么是必不可少的了：
 *  1. Gas 费的支付流程
 *      1. Bundler 先垫付: 是 Bundler 将你的 UserOperation 打包成一笔真实的以太坊交易并提交上链。因此，是 Bundler 最先用自己的 ETH
            为这整笔大交易向以太坊网络支付了 Gas 费。
        2. Bundler 需要报销: Bundler 不是慈善家，它需要一个可靠的机制来拿回自己垫付的 Gas 费，并赚取一点利润。
        3. EntryPoint 负责结算: `EntryPoint` 合约扮演了“会计和出纳”的角色。它负责在交易结束时，
            从你的 Account 合约里扣除应付的 Gas 费，然后转给Bundler。
    2. EntryPoint 面临的风险
        这里出现了一个问题：EntryPoint 在处理一个 UserOperation 时，它本身的操作（特别是 validateUserOp 这一步）也是消耗 Gas 的。
        如果一个恶意的用户提交了一个 UserOperation，但他的 Account 合约里其实一分钱都没有，会发生什么？
            * EntryPoint 开始执行，调用 Account.validateUserOp(...)。
            * 这个调用消耗了 Gas。
            * validateUserOp 执行到最后，发现账户里没钱，或者签名是伪造的，于是验证失败。
            * 交易结束，但因为验证消耗了 Gas，Bundler 垫付的钱就收不回来了，造成了亏损。
            为了防止这种“白白消耗Gas却收不回钱”的攻击，EntryPoint 引入了押金（Stake）和预付（Prefund）机制。
    3. _payPrefund 的作用
        EntryPoint 要求，任何 Account 合约在执行操作之前，都必须在 EntryPoint 合约里存有足够的押金来覆盖可能产生的最大 Gas 成本。
    现在，我们再来看 validateUserOp 函数的调用过程：
        1. EntryPoint 在调用你的 Account.validateUserOp 之前，会先检查你的账户在 EntryPoint 里的押金是否足够。
        2. 如果押金不足，EntryPoint 会计算出差额，并将这个差额作为 missingAccountFunds 参数传递给 validateUserOp 函数。
        3. validateUserOp 函数在验证完签名等逻辑后，就会调用 _payPrefund(missingAccountFunds)。

    总结：
        _payPrefund 函数是一个安全保障机制。它确保了在 EntryPoint 继续执行一个可能很耗 Gas 的操作之前，
        用户的 Account合约已经证明了自己有能力支付费用，并已将足够的押金存放在了 EntryPoint 这个受信任的第三方那里。
        这保护了 EntryPoint 和 Bundler 不会因为处理无效或恶意的 UserOperation 而蒙受经济损失，是整个 ERC-4337 经济模型能够健康运转的基石。  
 */

/*
Bundler怎么知道Account里有没有足够的钱付gas费?
    这是一个非常关键的问题，直接关系到 Bundler 的生死存亡（或者说，盈利与否）。
    Bundler 不会盲目地相信 UserOperation，它有一套严格的“岗前检查”流程，这个流程主要通过链下模拟 (Off-chain Simulation) 来完成。
    简单来说，在把你的 UserOperation 打包进一笔真实的、会花掉它自己真金白银的以太坊交易之前，
        Bundler会先在自己的节点上“排练”一遍，看看如果这个操作上链了会发生什么。
    这个“排练”过程如下：
        1. 接收 UserOperation
            首先，Bundler 通过 eth_sendUserOperation RPC 方法从你的钱包接收到 UserOperation 对象。
        2. 模拟验证 (simulateValidation)
            这是最核心的一步。Bundler 会调用 EntryPoint 合约的一个只读的、用于模拟的函数，通常是 simulateValidation()。
            * 这个调用是免费的，因为它是一个 eth_call (只读操作)，并不会真正在链上创建交易。
            * simulateValidation() 函数会完整地模拟 EntryPoint 的验证流程，包括调用你的 `Account` 合約的 `validateUserOp()` 函数。
        在这次模拟中，Account 合约的 validateUserOp() 函数会执行其内部逻辑，包括：
            * 检查签名是否正确。
            * 检查 `Account` 合约自身的 ETH 余额是否足以支付 `_payPrefund` 中可能需要的 `missingAccountFunds`。
    3. 分析模拟结果
        Bundler 会根据 simulateValidation 的返回结果来做决定：
        * 模拟成功: 如果模拟顺利完成，没有报错，Bundler 就得到了一个强烈的信号：
            在当前区块高度下，这个 Account合约有足够的资金，并且签名也是有效的。
            那么它就基本可以放心地将这个 UserOperation 放入待打包的队列中。
        * 模拟失败: 如果模拟过程中出现任何 revert (回滚)，例如：
            * Account 合约在 _payPrefund 时因为余额不足而转账失败。
            * 签名验证失败。
            * Nonce 不正确。
            Bundler 就会立即拒绝这个 UserOperation，直接将其丢弃，根本不会为它支付任何 Gas 费。
    4. 风险与防范
        即便模拟成功了，Bundler 仍然面临一个风险：状态变化。
        有可能在 Bundler 模拟交易（时间点 T1）和它的捆绑交易被矿工打包进区块（时间点 T2）之间，
        你的 Account合约状态发生了变化（例如，你通过另一笔交易把钱转走了）。
        为了应对这种风险，Bundler 会采取一些策略：
            * 押金机制: EntryPoint 要求 Account 存入押金，这本身就大大降低了 Bundler 的风险。
                即使 Account 余额在最后一刻归零，只要它在 EntryPoint的押金还够，Bundler 仍然能得到补偿。
            * 智能排序: 经验丰富的 Bundler 会有复杂的算法来安排 UserOperation 的顺序，并尽快将交易发送上链，以减少时间差带来的风险。
    总结：
        Bundler 就像一个精明的商人，在做一笔生意前，它会先做一个详细的“尽职调查”（模拟执行），
        确保这笔生意能赚钱（账户有足够资金）且合法合规（签名有效）。只有调查通过了，它才会真正投入成本（支付Gas费上链）。
        这个模拟过程是保护 Bundler 免受攻击和亏损的最重要防线。
*/
/**
Account怎么向EntryPoint存入押金
    Account 合约向 EntryPoint 存入押金的过程，是通过调用 EntryPoint 合约上一个特定的、公开的函数来完成的。
    这个函数就是 depositTo(address account) payable。
    我们来看一下这个流程是如何运作的：
        1. EntryPoint 提供的接口
            EntryPoint 合约为了管理押金，必须实现 IEntryPointStake 接口，这个接口中包含了几个关键函数：
            * depositTo(address account) external payable;
                * 作用: 为指定的 account 地址存入押金。
                * payable: 这个关键字意味着调用此函数时可以附带 ETH。附带的 ETH 数量就是你想要存入的押金金额。
            * balanceOf(address account) external view returns (uint256);
                * 作用: 查询指定 account 在 EntryPoint 中的押金余额。
            * withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external;
                * 作用: 从 EntryPoint 中取出指定数量的押金到指定的地址。

        2. Account 合约如何调用？
            Account.sol 本身是一个抽象合约，它没有提供一个直接的函数来调用 depositTo。
                但是，一个完整的、可用的 Account实现必须提供某种方式来执行这个操作。
            这通常是通过在 Account 合约上实现一个自定义的函数来完成的。例如：
                这是一个假想的、完整的 Account 实现
                contract MyFullAccount is Account 
                    
                     // @notice 允许账户所有者向 EntryPoint 存入押金
                     // @param amount 要存入的 ETH 数量
                     //
                    //function depositToEntryPoint(uint256 amount) external {
                    // 首先，获取 EntryPoint 合约的地址
                    // IEntryPoint _entryPoint = entryPoint();
                     // 然后，调用 EntryPoint 的 depositTo 函数，
                     // 并通过 {value: amount} 将 ETH 发送过去。
                     // 参数 address(this) 表示这笔押金是为我自己（MyFullAccount合约）存的。
                     //_entryPoint.depositTo{value: amount}(address(this));
                    //}
        3. 用户的操作流程
            所以，当一个用户想为他的智能账户存入押金时，他会：
                1. 确保他的 Account 合约地址上有足够的 ETH 余额。
                2. 创建一个 UserOperation,其 callData 指向他自己的 Account 合约，调用 depositToEntryPoint(存入的金额) 这个函数。
                3. 这个 UserOperation 被 Bundler 打包并由 EntryPoint 执行。
                4. 在执行阶段,EntryPoint 会调用 Account 合约,Account 合约再回头调用 EntryPoint 的 depositTo 函数，从而完成押金的存入。
**/
/*
如果一个全新的、余额为 0 的 `Account` 合约，它确实无法通过 `UserOperation` 来为自己存入第一笔押金，
因为任何理性的 Bundler 在模拟时都会发现它付不起 Gas 而拒绝该操作。
那么，第一笔资金是如何注入的呢？主要有两种方式：
    方案一：直接转账 (最简单直接的方式)
        这是最基础、最常见的方式。
            1. 获取“反事实地址”: 正如我们之前讨论的，钱包应用可以在 Account 合约部署之前，就通过 CREATE2 算法计算出它未来的确定性地址。
            2. 直接向该地址转账: 你，作为用户，可以从任何一个普通的 EOA 钱包（比如你的 MetaMask）或者一个中心化交易所（比如币安、欧易）提取
                ETH，像给任何普通地址转账一样，直接将 ETH 发送到这个计算出来的 `Account` 地址。
            3. `Account` 合约获得初始资金: 这笔转账成功后，你的 Account 地址上就有了 ETH 余额。
                （即使此时它上面还没有部署代码，ETH也可以安全地发送到这个地址上）。
            4. 发起第一笔 `UserOperation`: 现在，你的 Account 合约已经有钱了。
                当你再发起一笔 UserOperation 时（无论是调用 depositToEntryPoint还是执行其他操作），Bundler 在模拟时会发现：
                    * 你的 Account 合约有足够的 ETH 余额。
                    * 因此，在模拟 validateUserOp 时，_payPrefund 步骤可以成功执行（Account 可以成功向 EntryPoint 转账）。
                    * 于是，模拟通过，Bundler 接受并打包这笔 UserOperation。
    方案二：由第三方赞助 (最酷的用户体验)
        这是账户抽象真正强大的地方，它允许“无 Gas 启动”。
            1. 使用 Paymaster (支付大师): 用户想执行一个操作（比如，在一个 DApp 里领取一个免费的欢迎 NFT），但他钱包里一分钱都没有。
            2. 创建 `UserOperation`: 钱包创建一个 UserOperation，但这次，它在 paymasterAndData 字段里填上了一个 Paymaster 合约的地址。
                这个 Paymaster是由 DApp 项目方提供的，它愿意为新用户支付 Gas 费。
            3. Bundler 模拟: Bundler 拿到这个 UserOperation 后，在模拟时发现：
                * Account 余额为 0，无法支付 Gas。
                * 但是，这个操作指定了一个 Paymaster。
                * 于是 Bundler 会额外模拟 Paymaster 的 validatePaymasterUserOp 函数。
                * Paymaster 在模拟中同意支付，并有足够的押金在 EntryPoint。
            4. 模拟通过: 因为有 Paymaster 做担保，整个模拟通过了。Bundler 接受了这个 UserOperation。
            5. 上链执行: EntryPoint 在链上执行时，会向 Paymaster 收取 Gas 费，而不是向用户的 Account 收费。
        项目方赞助 Gas 费，是一笔非常划算的营销和运营开销。与其把钱花在传统广告上，不如直接花在用户身上，为他们扫清进入产品的最大障碍。
        在低成本的Layer 2 上，这种策略的投资回报率（ROI）非常高。    
 */
abstract contract Account is AbstractSigner, IAccount {
    /**
     * @dev 对账户的未经授权的调用。
     */
    error AccountUnauthorized(address sender);

    /**
     * @dev 如果调用者不是入口点或账户本身，则回滚。
     */
    modifier onlyEntryPointOrSelf() {
        _checkEntryPointOrSelf();
        _;
    }

    /**
     * @dev 如果调用者不是entryPoint，则回滚。
     */
    modifier onlyEntryPoint() {
        _checkEntryPoint();
        _;
    }

    /**
     * @dev 转发和验证用户操作的账户的规范入口点。
     * 获取EntryPoint合约地址
     */
    function entryPoint() public view virtual returns (IEntryPoint) {
        return ERC4337Utils.ENTRYPOINT_V08;
    }

    /**
     * @dev 返回规范序列的账户 nonce。
     */
    function getNonce() public view virtual returns (uint256) {
        return getNonce(0);
    }

    /**
     * @dev 返回给定序列（密钥）的账户 nonce。
     * 通过entryPoint获取
     */
    function getNonce(uint192 key) public view virtual returns (uint256) {
        return entryPoint().getNonce(address(this), key);
    }

    /**
     * @inheritdoc IAccount
     * entryPoint 会调用这个函数来验证用户操作的合法性。
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) public virtual onlyEntryPoint returns (uint256) {
        uint256 validationData = _validateUserOp(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
        return validationData;
    }

    /**
     * @dev 返回给定用户操作的 validationData。默认情况下，这会使用抽象签名者 ({AbstractSigner-_rawSignatureValidation})
     * 检查可签名哈希（由 {_signableUserOpHash} 生成）的签名。
     *
     * 注意：假定 userOpHash 是正确的。使用与 userOp 不匹配的 userOpHash 调用此函数
     * 将导致未定义的行为。
     */
    function _validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual returns (uint256) {
        return
            _rawSignatureValidation(_signableUserOpHash(userOp, userOpHash), userOp.signature)
                ? ERC4337Utils.SIG_VALIDATION_SUCCESS
                : ERC4337Utils.SIG_VALIDATION_FAILED;
    }

    /**
     * @dev 返回用户操作的可签名哈希的虚拟函数。从入口点的 v0.8.0 开始，
     * `userOpHash` 是一个可以直接签名的 EIP-712 哈希。
     */
    function _signableUserOpHash(
        PackedUserOperation calldata /*userOp*/,
        bytes32 userOpHash
    ) internal view virtual returns (bytes32) {
        return userOpHash;
    }

    /**
     * @dev 将执行用户操作所需的缺失资金发送到 {entrypoint}。
     * `missingAccountFunds` 必须由入口点在调用 {validateUserOp} 时定义。
     */
    function _payPrefund(uint256 missingAccountFunds) internal virtual {
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
            success; // 消除警告。入口点应验证结果。
        }
    }

    /**
     * @dev 确保调用者是 {entrypoint}。
     */
    function _checkEntryPoint() internal view virtual {
        address sender = msg.sender;
        if (sender != address(entryPoint())) {
            revert AccountUnauthorized(sender);
        }
    }

    /**
     * @dev 确保调用者是 {entrypoint} 或账户本身。
     */
    function _checkEntryPointOrSelf() internal view virtual {
        address sender = msg.sender;
        if (sender != address(this) && sender != address(entryPoint())) {
            revert AccountUnauthorized(sender);
        }
    }

    /**
     * @dev 接收以太币。
     */
    receive() external payable virtual {}
}
