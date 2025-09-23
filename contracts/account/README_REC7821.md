ERC-7821 是一个为了解决智能合约账户（例如 ERC-4337 钱包）如何被调用来执行操作这个问题的标准化提案。
简单来说，它的作用是为智能合约账户提供一个统一的、标准的“执行”入口。
ERC-7821 是一个微观的、具体的执行标准。
ERC-7821 解决了什么问题？
    在 ERC-7821 出现之前，不同的智能合约钱包项目可能会用不同的方式来定义“执行交易”这个功能。
        * 钱包 A 可能把这个函数叫做 execute(address to, uint256 value, bytes calldata data)
        * 钱包 B 可能叫做 executeBatch(address[] to, bytes[] data)
        * 钱包 C 可能叫做 run(Transaction[] txs)
    这给 DApp 和其他需要与智能合约钱包交互的工具带来了很大的麻烦。为了支持不同的钱包，
    DApp开发者需要为每一种钱包编写专门的适配代码，非常繁琐且容易出错。
    这就好比在 USB-C 标准出现之前，每种手机都有自己独特的充电接口，你需要为不同手机准备不同的充电器。
ERC-7821 的解决方案
    ERC-7821 提出，所有兼容的智能合约账户都应该实现一个标准、统一的 `execute` 函数：
        1 function execute(bytes32 mode, bytes calldata executionData) external payable;
        * `execute`: 一个标准化的函数名。
        * `mode`: 一个 bytes32 参数，用来指定执行的模式（例如，是单个操作还是批量操作，是否包含额外数据等）。
        * `executionData`: 一个 bytes 参数，它以标准化的方式编码了所有需要执行的调用（目标地址、发送金额、调用数据等）。
        通过这种方式，ERC-7821 就像是为所有智能合约钱包定义了一个“通用USB-C充电口”。
        现在，任何 DApp 或外部系统（比如 ERC-4337 的Bundler）如果想让一个智能钱包执行操作，它不再需要关心这个钱包是哪个团队开发的。
        它只需要知道：“这是一个兼容 ERC-7821的钱包，我只需要按照标准格式准备好 mode 和 executionData，
        然后调用它的 execute 函数就可以了。”
ERC-7821 和 ERC-4337 的关系
    这两个标准是天作之合，经常被一起提及：
        * ERC-4337 (账户抽象): 定义了 UserOperation 如何被验证、打包和支付 Gas 费。它解决了“谁来付钱”和“如何授权”的问题。
        * ERC-7821 (通用执行入口): 定义了 UserOperation 在验证通过后，
            应该如何调用 Account合约来执行真正的操作。它解决了“调用哪个函数”和“参数怎么传”的问题。
    在一个典型的流程中：
        1. EntryPoint 验证一个 UserOperation。
        2. 验证通过后，EntryPoint 需要执行这个 UserOperation 的 callData。
        3. 这个 callData 正是对 `Account` 合约的 `execute` 函数 (ERC-7821) 的调用。
    总结：
    ERC-7821 的核心作用就是提供一个标准的执行接口，以解决智能合约钱包生态的碎片化问题，让不同的钱包和 DApp 之间可以无缝、可预测地交互。
    它是实现真正可互操作的账户抽象生态的重要一环。


我们来创建一个完整且可运行的例子，来演示如何将 ERC7821 作为执行模块，集成到一个我们之前讨论过的 Account 合约中。
这个例子会包含两个合约：
   1. Counter.sol: 一个我们想要去操作的、非常简单的目标合约。
   2. MyAccount.sol: 我们自己的智能账户，它同时继承了 Account 和 ERC7821。
1. 目标合约：Counter.sol
    首先，我们需要一个可以交互的合约。这个 Counter 合约非常简单，只有一个数字 count，一个增加它的方法 increment，
    和一个读取它的方法getCount。
        // Counter.sol
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.20;
      
        contract Counter {
            uint256 public count;
      
            function increment() public {
                count++;
            }
      
            function getCount() public view returns (uint256) {
                return count;
            }
        }
    我们的目标就是通过我们的智能账户 MyAccount 来调用这个 Counter 合约的 increment 函数。
2. 智能账户实现：MyAccount.sol
    这是例子的核心。这个合约将把我们之前讨论的所有部分都组装起来。
        // MyAccount.sol
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.20;
        // 导入基础的 ERC-4337 账户
        import {Account} from "@openzeppelin/contracts/account/Account.sol";
        // 导入 ERC-7821 执行器扩展
        import {ERC7821} from "@openzeppelin/contracts/account/extensions/draft-ERC7821.sol";
        // 导入 ECDSA 库用于签名验证
        import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
        /**
        * @title 一个功能完整的智能账户
        * @dev 这个合约同时是:
        * - 一个 ERC-4337 账户 (通过继承 Account)
        * - 一个 ERC-7821 执行器 (通过继承 ERC7821)
        */
        contract MyAccount is Account, ERC7821 {
            // EOA 所有者的地址
            address private immutable _owner;
            // 构造函数，在部署时设置所有者
            constructor(address owner) {
                _owner = owner;
            }
            /**
            * @dev 实现 Account 合约要求的签名验证逻辑。
            * 这里我们实现最简单的 ECDSA 签名验证。
            */
            function _rawSignatureValidation(bytes32 hash, bytes calldata signature) internal view override returns (bool) {
                return ECDSA.recover(hash, signature) == _owner;
            }
            /**
            * @dev 【关键】重写 ERC7821 的授权逻辑。
            * 默认情况下，ERC7821 的 `execute` 只允许合约自己调用自己。
            * 我们必须重写它，以授权给 ERC-4337 的 EntryPoint，这样 EntryPoint 才能在验证通过后，
            * 调用 `execute` 来执行我们的操作。
            */
            function _erc7821AuthorizedExecutor(
                address caller,
                bytes32 mode,
                bytes calldata executionData
            ) internal view override(ERC7821) returns (bool) {
                // 允许 EntryPoint 合约调用 execute 函数
                if (caller == address(entryPoint())) {
                    return true;
                }
                
                // 同时也保留父合约的逻辑（允许自己调用自己）
                return super._erc7821AuthorizedExecutor(caller, mode, executionData);
            }
        }
3. 它是如何工作的？(一个完整的 UserOperation 流程)
    假设 Counter 合约已经部署，你也已经部署了你的 MyAccount 合约。现在你想让 count 加一。
    1. 在钱包/客户端层面:
       * 定义目标调用: 你想调用 Counter 合约的 increment() 函数。
            // 准备一个 Call 结构体
            Call memory singleCall = Call({
                to: address(counter_contract), // Counter 合约地址
                value: 0,
                data: abi.encodeCall(Counter.increment, ()) // 对 increment() 的调用数据
            });
       * 准备 `executionData`: 将上述调用放进一个数组，并编码。
            Call[] memory calls = new Call[](1);
            calls[0] = singleCall;
            bytes memory executionData = abi.encode(calls);
       * 准备 `mode`: 我们是批量调用，默认执行，且不带 opData。
        bytes32 mode = 0x0100000000000000000000000000000000000000000000000000000000000000;
       * 准备 `UserOperation` 的 `callData`: 这一步是关键，UserOperation 的 callData 并不是直接去调用 Counter，
            而是去调用我们 MyAccount 的execute 函数！
            bytes memory userOpCallData = abi.encodeCall(
                MyAccount.execute, // 目标函数是我们账户的 execute
                (mode, executionData) // execute 函数需要的两个参数
            );
        * 创建并签名 `UserOperation`: 钱包将 userOpCallData 和其他信息（sender, nonce等）组装成一个完整的
            UserOperation，计算其哈希，然后你用你的 EOA 私钥签名这个哈希。
   2. 在链上 (Bundler 和 EntryPoint):
       * Bundler 接收并打包这个 UserOperation，发送给 EntryPoint。
       * EntryPoint 调用 MyAccount.validateUserOp(...)。
       * MyAccount 内部的 _rawSignatureValidation 会验证签名，确认是你本人授权的，验证通过。
       * EntryPoint 接着执行 UserOperation 的 callData，也就是调用 MyAccount.execute(mode, executionData)。
       * MyAccount 的 execute 函数被触发。它首先检查调用者 msg.sender 是谁。
       * _erc7821AuthorizedExecutor 函数被执行，发现 caller 是 EntryPoint 地址，返回 true，授权通过。
       * execute 函数继续执行，它解码 executionData，得到 calls 数组。
       * execute 函数遍历 calls 数组，执行里面的调用，也就是最终调用了 Counter.increment()。
交易完成，Counter 的 count 成功加一。   