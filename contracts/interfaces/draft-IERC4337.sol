// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC4337.sol)

pragma solidity >=0.8.4;

/**
 * @dev https://github.com/ethereum/ercs/blob/master/ERCS/erc-4337.md#useroperation[用户操作] 由以下元素组成：
 * - `sender` (`address`): 执行操作的账户
 * - `nonce` (`uint256`): 抗重放参数 (参见 “半抽象 Nonce 支持”)
 * - `factory` (`address`): 账户工厂，仅用于新账户
 * - `factoryData` (`bytes`): 账户工厂的数据 (仅当账户工厂存在时)
 * - `callData` (`bytes`): 在主执行调用期间传递给发送者的数据
 * - `callGasLimit` (`uint256`): 分配给主执行调用的 gas 数量
 * - `verificationGasLimit` (`uint256`): 分配给验证步骤的 gas 数量
 * - `preVerificationGas` (`uint256`): 支付给捆绑器的额外 gas
 * - `maxFeePerGas` (`uint256`): 每 gas 最高费用 (类似于 EIP-1559 的 max_fee_per_gas)
 * - `maxPriorityFeePerGas` (`uint256`): 每 gas 最高优先费用 (类似于 EIP-1559 的 max_priority_fee_per_gas)
 * - `paymaster` (`address`): paymaster 合约的地址 (如果账户自己支付，则为空)
 * - `paymasterVerificationGasLimit` (`uint256`): 分配给 paymaster 验证代码的 gas 数量
 * - `paymasterPostOpGasLimit` (`uint256`): 分配给 paymaster 操作后代码的 gas 数量
 * - `paymasterData` (`bytes`): paymaster 的数据 (仅当 paymaster 存在时)
 * - `signature` (`bytes`): 传入账户以验证授权的数据
 *
 * 当传递给链上合约时，使用以下打包版本。
 * - `sender` (`address`)
 * - `nonce` (`uint256`)
 * - `initCode` (`bytes`): factory 地址和 factoryData 的串联 (或为空)
 * - `callData` (`bytes`)
 * - `accountGasLimits` (`bytes32`): verificationGas (16 字节) 和 callGas (16 字节) 的串联
 * - `preVerificationGas` (`uint256`)
 * - `gasFees` (`bytes32`): maxPriorityFeePerGas (16 字节) 和 maxFeePerGas (16 字节) 的串联
 * - `paymasterAndData` (`bytes`): paymaster 字段的串联 (或为空)
 * - `signature` (`bytes`)
 */
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode; // `abi.encodePacked(factory, factoryData)`
    bytes callData;
    bytes32 accountGasLimits; // `abi.encodePacked(verificationGasLimit, callGasLimit)` 每个 16 字节
    uint256 preVerificationGas;
    bytes32 gasFees; // `abi.encodePacked(maxPriorityFeePerGas, maxFeePerGas)` 每个 16 字节
    bytes paymasterAndData; // `abi.encodePacked(paymaster, paymasterVerificationGasLimit, paymasterPostOpGasLimit, paymasterData)` (20 字节, 16 字节, 16 字节, 动态)
    bytes signature;
}

/**
 * @dev 为一批用户操作聚合和验证多个签名。
 *
 * 合约可以实现此接口，并使用允许签名聚合的自定义验证方案，
 * 从而为执行和交易数据成本带来显著的优化和 gas 节省。
 *
 * 捆绑器和客户端将支持的聚合器列入白名单。
 *
 * 参见 https://eips.ethereum.org/EIPS/eip-7766[ERC-7766]
 */
interface IAggregator {
    /**
     * @dev 验证用户操作的签名。
     * 返回一个在捆绑期间应使用的替代签名。
     */
    function validateUserOpSignature(
        PackedUserOperation calldata userOp
    ) external view returns (bytes memory sigForUserOp);

    /**
     * @dev 返回一批用户操作签名的聚合签名。
     */
    function aggregateSignatures(
        PackedUserOperation[] calldata userOps
    ) external view returns (bytes memory aggregatesSignature);

    /**
     * @dev 验证聚合签名对于用户操作是否有效。
     *
     * 要求：
     *
     * - 聚合签名必须与给定的操作列表匹配。
     */
    function validateSignatures(PackedUserOperation[] calldata userOps, bytes calldata signature) external view;
}

/**
 * @dev 处理账户的 nonce 管理。
 *
 * Nonce 在账户中用作重放保护机制，并确保用户操作的顺序。
 * 为了避免限制账户可以执行的操作数量，该接口允许通过使用 `key` 参数来使用并行 nonce。
 *
 * 参见 https://eips.ethereum.org/EIPS/eip-4337#semi-abstracted-nonce-support[ERC-4337 半抽象 nonce 支持]。
 */
interface IEntryPointNonces {
    /**
     * @dev 返回 `sender` 账户和 `key` 的 nonce。
     *
     * 某个 `key` 的 Nonce 总是递增的。
     */
    function getNonce(address sender, uint192 key) external view returns (uint256 nonce);
}

/**
 * @dev 处理实体（即账户、paymaster、工厂）的质押管理。
 *
 * EntryPoint 必须实现以下 API，以允许像 paymaster 这样的实体进行质押，
 * 从而在存储访问方面具有更大的灵活性
 * (参见 https://eips.ethereum.org/EIPS/eip-4337#reputation-scoring-and-throttlingbanning-for-global-entities[信誉、限制和禁止])
 */
interface IEntryPointStake {
    /**
     * @dev 返回账户的余额。
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 将 `msg.value` 存入账户。
     */
    function depositTo(address account) external payable;

    /**
     * @dev 从账户中提取 `withdrawAmount` 到 `withdrawAddress`。
     */
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external;

    /**
     * @dev 向账户添加质押，解锁延迟为 `unstakeDelaySec`。
     */
    function addStake(uint32 unstakeDelaySec) external payable;

    /**
     * @dev 解锁账户的质押。
     */
    function unlockStake() external;

    /**
     * @dev 将账户的质押提取到 `withdrawAddress`。
     */
    function withdrawStake(address payable withdrawAddress) external;
}

/**
 * @dev 用户操作的入口点。
 *
 * 用户操作由此合约验证和执行。
 */
interface IEntryPoint is IEntryPointNonces, IEntryPointStake {
    /**
     * @dev `opIndex` 处的用户操作因 `reason` 而失败。
     */
    error FailedOp(uint256 opIndex, string reason);

    /**
     * @dev `opIndex` 处的用户操作因 `reason` 和 `inner` 返回的数据而失败。
     */
    error FailedOpWithRevert(uint256 opIndex, string reason, bytes inner);

    /**
     * @dev 每个聚合器的聚合用户操作批次。
     */
    struct UserOpsPerAggregator {
        PackedUserOperation[] userOps;
        IAggregator aggregator;
        bytes signature;
    }

    /**
     * @dev 执行一批用户操作。
     * @param beneficiary 完成执行后退还 gas 的地址。
     */
    function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external;

    /**
     * @dev 每个聚合器执行一批聚合的用户操作。
     * @param beneficiary 完成执行后退还 gas 的地址。
     */
    function handleAggregatedOps(
        UserOpsPerAggregator[] calldata opsPerAggregator,
        address payable beneficiary
    ) external;
}

/**
 * @dev ERC-4337 账户的基础接口。
 */
interface IAccount {
    /**
     * @dev 验证用户操作。
     *
     * * 必须验证调用者是受信任的 EntryPoint
     * * 必须验证签名是 userOpHash 的有效签名，并且在签名不匹配时应该
     *   返回 SIG_VALIDATION_FAILED (而不是 revert)。任何其他错误都必须 revert。
     * * 必须向 entryPoint (调用者) 支付至少 “missingAccountFunds” (如果当前账户的存款足够高，则可能为零)
     *
     * 返回由以下元素组成的编码打包验证数据：
     *
     * - `authorizer` (`address`): 0 表示成功，1 表示失败，否则为授权者合约的地址
     * - `validUntil` (`uint48`): UserOp 仅在此时间之前有效。零表示“无限”。
     * - `validAfter` (`uint48`): UserOp 仅在此时间之后有效。
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

/**
 * @dev 通过将 {executeUserOp} 函数选择器前置到 UserOperation 的 `callData` 来支持执行用户操作。
 */
interface IAccountExecute {
    /**
     * @dev 执行用户操作。
     */
    function executeUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external;
}

/**
 * @dev 同意为用户操作的 gas 成本付费的 paymaster 合约的接口。
 *
 * 注意：paymaster 必须持有质押以支付所需的入口点质押以及交易的 gas。
 */
interface IPaymaster {
    enum PostOpMode {
        opSucceeded,
        opReverted,
        postOpReverted
    }

    /**
     * @dev 验证 paymaster 是否愿意为用户操作付费。有关返回值的其他信息，请参见
     * {IAccount-validateUserOp}。
     *
     * 注意：如果此方法修改状态，除非它被列入白名单，否则捆绑器将拒绝此方法。
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);

    /**
     * @dev 验证发送者是入口点。
     * @param actualGasCost 此 UserOperation 的实际支付金额（由账户或 paymaster 支付）
     * @param actualUserOpFeePerGas 此 UserOperation 使用的总 gas（包括 preVerification、creation、validation 和 execution）
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external;
}
