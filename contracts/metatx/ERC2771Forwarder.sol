// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (metatx/ERC2771Forwarder.sol)

pragma solidity ^0.8.24;

import {ERC2771Context} from "./ERC2771Context.sol";
import {ECDSA} from "../utils/cryptography/ECDSA.sol";
import {EIP712} from "../utils/cryptography/EIP712.sol";
import {Nonces} from "../utils/Nonces.sol";
import {Address} from "../utils/Address.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @dev 与 ERC-2771 合约兼容的转发器。参见 {ERC2771Context}。
 *
 * 此转发器操作的转发请求包括：
 *
 * * `from`: 代表其操作的地址。要求等于请求的签名者。
 * * `to`: 应该被调用的地址。
 * * `value`: 随请求调用附加的原生代币数量。
 * * `gas`: 随请求调用转发的 gas 上限数量。
 * * `nonce`: 唯一的交易排序标识符，以避免重放攻击和请求失效。
 * * `deadline`: 请求不再可执行的时间戳。
 * * `data`: 随请求调用发送的编码后的 `msg.data`。
 *
 * 如果中继者处理大量请求，他们能够提交批量请求。
 * 在高吞吐量下，中继者可能会遇到链的限制，例如内存池中交易数量的限制。在这些情况下，建议将负载分散到多个账户中。
 *
 * 注意：批量请求包括一个可选的未使用 `msg.value` 的退款，这是通过执行一个空 calldata 的调用来实现的。
 * 虽然这在 ERC-2771 合规性范围内，但如果退款接收者恰好将此转发器视为受信任的转发器，它必须正确处理 `msg.data.length == 0` 的情况。
 * OpenZeppelin Contracts 4.9.3 之前的版本中的 `ERC2771Context` 没有正确处理此问题。
 *
 * ==== 安全考量
 *
 * 如果中继者提交转发请求，它应该愿意支付请求中指定的 gas 数量的100%。
 * 此合约没有实现任何对此 gas 的补偿机制，并假定存在带外激励，促使中继者代表签名者支付执行费用。
 * 通常，中继者由一个项目运营，该项目会将其视为用户获取成本。
 *
 * 通过提供支付 gas 的服务，中继者面临着其 gas 被攻击者用于与预期带外激励不符的其他目的的风险。
 * 如果您运营一个中继者，请考虑将目标合约和函数选择器列入白名单。
 * 在专门中继 ERC-721 或 ERC-1155 转移时，请考虑拒绝使用 `data` 字段，因为它可用于执行任意代码。
 */
contract ERC2771Forwarder is EIP712, Nonces {
    using ECDSA for bytes32;

    struct ForwardRequestData {
        address from;   // 代表其操作的地址。要求等于请求的签名者。
        address to;     // 应该被调用的地址。
        uint256 value;  // 随请求调用附加的原生代币数量。
        uint256 gas;    // 随请求调用转发的 gas 上限数量。
        uint48 deadline;    // 请求不再可执行的时间戳。
        bytes data; //  随请求调用发送的编码后的 `msg.data`。
        bytes signature;    // 请求的签名，见 {_recoverForwardRequestSigner}。
    }

    bytes32 internal constant _FORWARD_REQUEST_TYPEHASH =
        keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
        );

    /**
     * @dev 当一个 `ForwardRequest` 被执行时发出。
     *
     * 注意：一个不成功的转发请求可能是由于无效的签名、过期的截止日期，或者仅仅是请求的调用中发生了回退。合约保证中继者无法强制使请求的调用耗尽 gas。
     */
    event ExecutedForwardRequest(address indexed signer, uint256 nonce, bool success);

    /**
     * @dev 请求的 `from` 与恢复的 `signer` 不匹配。
     */
    error ERC2771ForwarderInvalidSigner(address signer, address from);

    /**
     * @dev 请求的 `requestedValue` 与可用的 `msgValue` 不匹配。
     */
    error ERC2771ForwarderMismatchedValue(uint256 requestedValue, uint256 msgValue);

    /**
     * @dev 请求的 `deadline` 已过期。
     */
    error ERC2771ForwarderExpiredRequest(uint48 deadline);

    /**
     * @dev 请求的目标不信任此 `forwarder`。
     */
    error ERC2771UntrustfulTarget(address target, address forwarder);

    /**
     * @dev 参见 {EIP712-constructor}。
     */
    constructor(string memory name) EIP712(name, "1") {}

    /**
     * @dev 如果一个请求在当前区块时间戳下对于提供的 `signature` 是有效的，则返回 `true`。
     *
     * 当目标信任此转发器、请求未过期（未达到截止日期）且签名者与签名请求的 `from` 参数匹配时，交易被认为是有效的。
     *
     * 注意：如果提供了退款接收者，一个请求在这里可能返回 false，但这不会导致 {executeBatch} 回退。
     */
    function verify(ForwardRequestData calldata request) public view virtual returns (bool) {
        (bool isTrustedForwarder, bool active, bool signerMatch, ) = _validate(request);
        return isTrustedForwarder && active && signerMatch;
    }

    /**
     * @dev 使用 ERC-2771 协议代表 `signature` 的签名者执行一个 `request`。提供给请求调用的 gas 可能不完全是请求的数量，但调用不会耗尽 gas。如果请求无效或调用回退，将会回退，在这种情况下 nonce 不会被消耗。
     *
     * 要求：
     *
     * - 请求的 value 应等于提供的 `msg.value`。
     * - 根据 {verify}，请求应该是有效的。
     */
    function execute(ForwardRequestData calldata request) public payable virtual {
        // 我们确保 msg.value 和 request.value 完全匹配。
        // 如果请求无效或调用回退，整个函数将回退，确保 value 不会被卡住。
        if (msg.value != request.value) {
            revert ERC2771ForwarderMismatchedValue(request.value, msg.value);
        }

        if (!_execute(request, true)) {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev {execute} 的批量版本，带有可选的退款和原子执行功能。
     *
     * 如果一个批次中至少包含一个无效请求（参见 {verify}），该请求将被跳过，并且 `refundReceiver` 参数将在执行结束时收回未使用的请求值。这样做是为了防止在请求无效或已提交时回退整个批次。
     *
     * 如果 `refundReceiver` 是 `address(0)`，当至少有一个请求无效时，此函数将回退而不是跳过它。如果要求一个批次原子地执行（至少在顶层），这可能很有用。例如，如果中继者使用的服务避免包含已回退的交易，则可以选择退出退款（以及原子性）。
     *
     * 要求：
     *
     * - 请求的总 value 应等于提供的 `msg.value`。
     * - 当 `refundReceiver` 是零地址时，所有请求都应是有效的（参见 {verify}）。
     *
     * 注意：设置一个零 `refundReceiver` 仅保证第一级转发调用的“全有或全无”请求执行。
     * 如果一个转发的请求调用到一个带有另一个子调用的合约，第二级调用可能会回退而顶层调用不会回退。
     */
    function executeBatch(
        ForwardRequestData[] calldata requests,
        address payable refundReceiver
    ) public payable virtual {
        bool atomic = refundReceiver == address(0);

        uint256 requestsValue;
        uint256 refundValue;

        for (uint256 i; i < requests.length; ++i) {
            requestsValue += requests[i].value;
            bool success = _execute(requests[i], atomic);
            if (!success) {
                refundValue += requests[i].value;
            }
        }

        // 如果提供了不匹配的 msg.value，批处理应该回退，以避免请求值被篡改
        if (requestsValue != msg.value) {
            revert ERC2771ForwarderMismatchedValue(requestsValue, msg.value);
        }

        // 一些带有 value 的请求是无效的（可能是由于抢跑）。
        // 为了避免将 ETH 留在合约中，此值将被退还。
        if (refundValue != 0) {
            // 我们知道 refundReceiver != address(0) && requestsValue == msg.value
            // 这意味着我们可以确保 refundValue 不是从原始合约的余额中获取的
            // 并且 refundReceiver 是一个已知的账户。
            Address.sendValue(refundReceiver, refundValue);
        }
    }

    /**
     * @dev 验证提供的请求是否可以在当前区块时间戳下，使用给定的 `request.signature` 代表 `request.signer` 执行。
     */
    function _validate(
        ForwardRequestData calldata request
    ) internal view virtual returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        (bool isValid, address recovered) = _recoverForwardRequestSigner(request);

        return (
            _isTrustedByTarget(request.to),
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
        );
    }

    /**
     * @dev 返回一个元组，其中包含从 EIP712 转发请求消息哈希中恢复的签名者，以及一个指示签名是否有效的布尔值。
     *
     * 注意：如果 {ECDSA-tryRecover} 表明签名没有恢复错误，则该签名被认为是有效的。
     */
    function _recoverForwardRequestSigner(
        ForwardRequestData calldata request
    ) internal view virtual returns (bool isValid, address signer) {
        (address recovered, ECDSA.RecoverError err, ) = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _FORWARD_REQUEST_TYPEHASH,
                    request.from,
                    request.to,
                    request.value,
                    request.gas,
                    nonces(request.from),
                    request.deadline,
                    keccak256(request.data)
                )
            )
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    /**
     * @dev 验证并执行一个已签名的请求，返回请求调用的 `success` 值。
     *
     * 无 msg.value 验证的内部函数。
     *
     * 要求：
     *
     * - 调用者必须提供足够的 gas 以随调用一起转发。
     * - 如果 `requireValidRequest` 为 true，则请求必须是有效的（参见 {verify}）。
     *
     * 发出 {ExecutedForwardRequest} 事件。
     *
     * 重要提示：使用此函数不会检查是否发送了所有的 `msg.value`，可能会导致 value 卡在合约中。
     */
    function _execute(
        ForwardRequestData calldata request,
        bool requireValidRequest
    ) internal virtual returns (bool success) {
        (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

        // 需要明确指定是否需要回退，因为对于批处理，不回退是默认行为，而回退是可选的，因为它在某些场景下可能有用
        if (requireValidRequest) {
            if (!isTrustedForwarder) {
                revert ERC2771UntrustfulTarget(request.to, address(this));
            }

            if (!active) {
                revert ERC2771ForwarderExpiredRequest(request.deadline);
            }

            if (!signerMatch) {
                revert ERC2771ForwarderInvalidSigner(signer, request.from);
            }
        }

        // 忽略一个无效的请求，因为 requireValidRequest = false
        if (isTrustedForwarder && signerMatch && active) {
            // 应在调用前使用 Nonce，以防止通过重入重用
            uint256 currentNonce = _useNonce(signer);

            uint256 reqGas = request.gas;
            address to = request.to;
            uint256 value = request.value;
            // 编码后的 msg.data 是请求的 data 后跟请求的 from 地址
            bytes memory data = abi.encodePacked(request.data, request.from);

            uint256 gasLeft;

            assembly ("memory-safe") {
                success := call(reqGas, to, value, add(data, 0x20), mload(data), 0, 0)
                gasLeft := gas()
            }

            _checkForwardedGas(gasLeft, request);

            emit ExecutedForwardRequest(signer, currentNonce, success);
        }
    }

    /**
     * @dev 返回目标是否信任此转发器。
     *
     * 此函数对目标合约执行静态调用，调用 {ERC2771Context-isTrustedForwarder} 函数。
     *
     * 注意：考虑到此转发器的执行是无需许可的。如果没有此检查，任何人都可能转移由此转发器拥有或批准给此转发器的资产。
     */
     /*
        target 地址，简单来说，就是用户真正想要交互的那个目标合约地址。它是整个元交易流程的“最终目的地”。
        例如：
            * 如果用户想调用一个 MyToken 合约的 transfer 函数，那么 target 就是 MyToken 合约的地址。
        这个 target 地址主要被用在两个关键地方：
            1. 用于安全检查 (_isTrustedByTarget 函数中)
                在真正执行用户的请求之前，Forwarder 必须先进行一次安全确认，它会问 target 合约一个问题：
                    “你（`target`）信任我（`Forwarder`）吗？”    
                这个检查就是通过调用 target 合约上的 isTrustedForwarder() 函数来完成的。只有当 target 合约返回 true 时，Forwarder 才会继续下一步。
                这可以防止 Forwarder 被诱骗去调用一个不兼容或恶意的合约。 
            2. 用于最终执行 (_execute 函数中)
                一旦安全检查通过，Forwarder 就会执行用户的原始请求。     
                它会使用底层的 call 操作码，将用户签名的调用数据（request.data）和资金（request.value）发送到这个 target 地址。

        目标合约（`target`）必须继承 `ERC2771Context`，或者至少实现其核心功能，才能与 ERC2771Forwarder 正确协作。    
            1. 为了通过“信任检查” (_isTrustedByTarget)
            2. 为了正确识别“真实用户” (_msgSender)     
     */
    function _isTrustedByTarget(address target) internal view virtual returns (bool) {
        bytes memory encodedParams = abi.encodeCall(ERC2771Context.isTrustedForwarder, (address(this)));

        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            // 执行 staticcall 并将结果保存在暂存空间中。
            // | Location  | Content  | Content (Hex)                                                      |
            // |-----------|----------|--------------------------------------------------------------------|
            // |           |          |                                                           result ↓ |
            // | 0x00:0x1F | selector | 0x0000000000000000000000000000000000000000000000000000000000000001 |
            success := staticcall(gas(), target, add(encodedParams, 0x20), mload(encodedParams), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }

    /**
     * @dev 检查请求的 gas 是否已正确转发给被调用者。
     *
     * 作为 https://eips.ethereum.org/EIPS/eip-150[EIP-150] 的结果：
     * - 最多 `gasleft() - floor(gasleft() / 64)` 被转发给被调用者。
     * - 至少 `floor(gasleft() / 64)` 保留在调用者中。
     *
     * 如果转发的 gas 不是请求的 gas，它会回退并消耗所有可用的 gas。
     *
     * 重要提示：`gasLeft` 参数应在转发调用结束后精确测量。在此期间消耗的任何 gas 都会为绕过此检查提供空间。
     */
    function _checkForwardedGas(uint256 gasLeft, ForwardRequestData calldata request) private pure {
        // 为了避免不足 gas 的恶意攻击，如 https://ronan.eth.limo/blog/ethereum-gas-dangers/ 中所述
        //
        // 恶意的中继者可以尝试减少转发的 gas，以便底层调用因 gas 不足而回退，但转发本身仍然成功。为了确保子调用接收到足够的 gas，我们将在转发后检查 gasleft()。
        //
        // 设 X 为子调用之前的可用 gas，这样子调用最多获得 X * 63 / 64。
        // 我们在 CALL 的动态成本之后无法知道 X，但我们希望 X * 63 / 64 >= req.gas。
        // 设 Y 为子调用中使用的 gas。在子调用后立即测量的 gasleft() 将是 gasleft() = X - Y。
        // 如果子调用耗尽 gas，则 Y = X * 63 / 64，且 gasleft() = X - Y = X / 64。
        // 在此假设下，当且仅当 req.gas / 63 > X / 64，或等效地 req.gas > X * 63 / 64 时，req.gas / 63 > gasleft() 为真。
        // 这意味着如果子调用耗尽 gas，我们能够检测到传递的 gas 不足。
        //
        // 我们现在还将看到 req.gas / 63 > gasleft() 意味着 req.gas >= X * 63 / 64。
        // 合约保证 Y <= req.gas，因此 gasleft() = X - Y >= X - req.gas。
        // -    req.gas / 63 > gasleft()
        // -    req.gas / 63 >= X - req.gas
        // -    req.gas >= X * 63 / 64
        // 换句话说，如果 req.gas < X * 63 / 64，则 req.gas / 63 <= gasleft()，因此如果中继者诚实地行事，转发不会回退。
        if (gasLeft < request.gas / 63) {
            // 我们明确触发无效操作码以消耗所有 gas 并上浮效果，因为自 Solidity 0.8.20 起，revert 和 assert 都不再消耗所有 gas
            // https://docs.soliditylang.org/en/v0.8.20/control-structures.html#panic-via-assert-and-error-via-require
            assembly ("memory-safe") {
                invalid()
            }
        }
    }
}
