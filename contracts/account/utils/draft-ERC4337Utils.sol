// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (account/utils/draft-ERC4337Utils.sol)

pragma solidity ^0.8.20;

import {IEntryPoint, PackedUserOperation} from "../../interfaces/draft-IERC4337.sol";
import {Math} from "../../utils/math/Math.sol";
import {Calldata} from "../../utils/Calldata.sol";
import {Packing} from "../../utils/Packing.sol";

/// @dev 自 v0.4.0 起，所有入口点都提供此功能，但它并非 ERC 的正式组成部分。
interface IEntryPointExtra {
    function getUserOpHash(PackedUserOperation calldata userOp) external view returns (bytes32);
}

/**
 * @dev 包含通用 ERC-4337 实用函数的库。
 *
 * 参见 https://eips.ethereum.org/EIPS/eip-4337[ERC-4337]。
 */
library ERC4337Utils {
    using Packing for *;

    /// @dev EntryPoint v0.7.0 的地址
    IEntryPoint internal constant ENTRYPOINT_V07 = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

    /// @dev EntryPoint v0.8.0 的地址
    IEntryPoint internal constant ENTRYPOINT_V08 = IEntryPoint(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);

    /// @dev 出于模拟目的，validateUserOp（和 validatePaymasterUserOp）在成功时返回此值。
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;

    /// @dev 出于模拟目的，validateUserOp（和 validatePaymasterUserOp）在签名失败时必须返回此值，而不是 revert。
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    /// @dev 将验证数据解析为其组成部分。参见 {packValidationData}。
    function parseValidationData(
        uint256 validationData
    ) internal pure returns (address aggregator, uint48 validAfter, uint48 validUntil) {
        validAfter = uint48(bytes32(validationData).extract_32_6(0));
        validUntil = uint48(bytes32(validationData).extract_32_6(6));
        aggregator = address(bytes32(validationData).extract_32_20(12));
        if (validUntil == 0) validUntil = type(uint48).max;
    }

    /// @dev 将验证数据打包成单个 uint256。参见 {parseValidationData}。
    function packValidationData(
        address aggregator,
        uint48 validAfter,
        uint48 validUntil
    ) internal pure returns (uint256) {
        return uint256(bytes6(validAfter).pack_6_6(bytes6(validUntil)).pack_12_20(bytes20(aggregator)));
    }

    /// @dev 与 {packValidationData} 相同，但带有一个布尔类型的签名成功标志。
    function packValidationData(bool sigSuccess, uint48 validAfter, uint48 validUntil) internal pure returns (uint256) {
        return
            packValidationData(
                address(uint160(Math.ternary(sigSuccess, SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED))),
                validAfter,
                validUntil
            );
    }

    /**
     * @dev 将两个验证数据合并为一个。
     *
     * 如果两者都成功，`aggregator` 会被设置为 {SIG_VALIDATION_SUCCESS}，
     * 而 `validAfter` 是两者中的最大值，`validUntil` 是两者中的最小值。
     */
    function combineValidationData(uint256 validationData1, uint256 validationData2) internal pure returns (uint256) {
        (address aggregator1, uint48 validAfter1, uint48 validUntil1) = parseValidationData(validationData1);
        (address aggregator2, uint48 validAfter2, uint48 validUntil2) = parseValidationData(validationData2);

        bool success = aggregator1 == address(uint160(SIG_VALIDATION_SUCCESS)) &&
            aggregator2 == address(uint160(SIG_VALIDATION_SUCCESS));
        uint48 validAfter = uint48(Math.max(validAfter1, validAfter2));
        uint48 validUntil = uint48(Math.min(validUntil1, validUntil2));
        return packValidationData(success, validAfter, validUntil);
    }

    /// @dev 返回 `validationData` 的聚合器以及它是否超出时间范围。
    function getValidationData(uint256 validationData) internal view returns (address aggregator, bool outOfTimeRange) {
        (address aggregator_, uint48 validAfter, uint48 validUntil) = parseValidationData(validationData);
        return (aggregator_, block.timestamp < validAfter || validUntil < block.timestamp);
    }

    /// @dev 获取给定入口点的用户操作哈希
    function hash(PackedUserOperation calldata self, address entrypoint) internal view returns (bytes32) {
        // 注意：getUserOpHash 自 v0.4.0 起可用
        //
        // 在 v0.8.0 之前，对于任何入口点和链 ID，这都很容易复制。自 v0.8.0 起，
        // 这取决于入口点的域分隔符，该分隔符不能硬编码且重新计算起来很复杂。
        // 域分隔符可以使用 `getDomainSeparatorV4` getter 获取，或从
        // ERC-5267 getter 重新计算，但这两种操作都需要对入口点进行视图调用。总的来说，
        // 直接从入口点获取该功能感觉更简单且不易出错。
        return IEntryPointExtra(entrypoint).getUserOpHash(self);
    }

    /// @dev 从 {PackedUserOperation} 返回 `factory`，如果 initCode 为空或格式不正确，则返回 address(0)。
    function factory(PackedUserOperation calldata self) internal pure returns (address) {
        return self.initCode.length < 20 ? address(0) : address(bytes20(self.initCode[0:20]));
    }

    /// @dev 从 {PackedUserOperation} 返回 `factoryData`，如果 initCode 为空或格式不正确，则返回空字节。
    function factoryData(PackedUserOperation calldata self) internal pure returns (bytes calldata) {
        return self.initCode.length < 20 ? Calldata.emptyBytes() : self.initCode[20:];
    }

    /// @dev 从 {PackedUserOperation} 返回 `verificationGasLimit`。
    function verificationGasLimit(PackedUserOperation calldata self) internal pure returns (uint256) {
        return uint128(self.accountGasLimits.extract_32_16(0));
    }

    /// @dev 从 {PackedUserOperation} 返回 `callGasLimit`。
    function callGasLimit(PackedUserOperation calldata self) internal pure returns (uint256) {
        return uint128(self.accountGasLimits.extract_32_16(16));
    }

    /// @dev 从 {PackedUserOperation} 返回 `gasFees` 的第一部分。
    function maxPriorityFeePerGas(PackedUserOperation calldata self) internal pure returns (uint256) {
        return uint128(self.gasFees.extract_32_16(0));
    }

    /// @dev 从 {PackedUserOperation} 返回 `gasFees` 的第二部分。
    function maxFeePerGas(PackedUserOperation calldata self) internal pure returns (uint256) {
        return uint128(self.gasFees.extract_32_16(16));
    }

    /// @dev 返回 {PackedUserOperation} 的总 gas 价格（即 `maxFeePerGas` 或 `maxPriorityFeePerGas + basefee`）。
    function gasPrice(PackedUserOperation calldata self) internal view returns (uint256) {
        unchecked {
            // 以下值是“每 gas”
            uint256 maxPriorityFee = maxPriorityFeePerGas(self);
            uint256 maxFee = maxFeePerGas(self);
            return Math.min(maxFee, maxPriorityFee + block.basefee);
        }
    }

    /// @dev 从 {PackedUserOperation} 返回 `paymasterAndData` 的第一部分。
    function paymaster(PackedUserOperation calldata self) internal pure returns (address) {
        return self.paymasterAndData.length < 52 ? address(0) : address(bytes20(self.paymasterAndData[0:20]));
    }

    /// @dev 从 {PackedUserOperation} 返回 `paymasterAndData` 的第二部分。
    function paymasterVerificationGasLimit(PackedUserOperation calldata self) internal pure returns (uint256) {
        return self.paymasterAndData.length < 52 ? 0 : uint128(bytes16(self.paymasterAndData[20:36]));
    }

    /// @dev 从 {PackedUserOperation} 返回 `paymasterAndData` 的第三部分。
    function paymasterPostOpGasLimit(PackedUserOperation calldata self) internal pure returns (uint256) {
        return self.paymasterAndData.length < 52 ? 0 : uint128(bytes16(self.paymasterAndData[36:52]));
    }

    /// @dev 从 {PackedUserOperation} 返回 `paymasterAndData` 的第四部分。
    function paymasterData(PackedUserOperation calldata self) internal pure returns (bytes calldata) {
        return self.paymasterAndData.length < 52 ? Calldata.emptyBytes() : self.paymasterAndData[52:];
    }
}
