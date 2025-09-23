// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/Address.sol)

pragma solidity ^0.8.20;

import {Errors} from "./Errors.sol";

/**
 * @dev 与地址类型相关的函数集合
 */
library Address {
    /**
     * @dev `target` 地址没有代码（它不是一个合约）。
     */
    error AddressEmptyCode(address target);

    /**
     * @dev 替代 Solidity 的 `transfer`：向 `recipient` 发送 `amount` wei，
     * 转发所有可用 gas 并在出错时回滚。
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] 增加了某些操作码的 gas 成本，
     * 可能导致合约超出 `transfer` 强加的 2300 gas 限制，
     * 使它们无法通过 `transfer` 接收资金。{sendValue} 消除了这个限制。
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[了解更多]。
     *
     * 重要提示：因为控制权被转移到 `recipient`，必须注意不要产生重入漏洞。
     * 考虑使用{ReentrancyGuard} 或
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[检查-生效-交互模式]。
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, bytes memory returndata) = recipient.call{value: amount}("");
        if (!success) {
            _revert(returndata);
        }
    }

    /**
     * @dev 使用低级别的 `call` 执行 Solidity 函数调用。
     * 一个普通的 `call` 是函数调用的不安全替代品：请改用此函数。
     *
     * 如果 `target` 因回滚原因或自定义错误而回滚，此函数会将其冒泡
     * （就像常规的 Solidity 函数调用一样）。但是，如果
     * 调用在没有返回原因的情况下回滚，此函数会以
     * {Errors.FailedCall} 错误回滚。
     *
     * 返回原始的返回数据。要转换为预期的返回值，
     * 请使用 https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`]。
     *
     * 要求：
     *
     * - `target` 必须是一个合约。
     * - 使用 `data` 调用 `target` 不得回滚。
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev 与 {xref-Address-functionCall-address-bytes-}[`functionCall`] 相同，
     * 但同时向 `target` 转移 `value` wei。
     *
     * 要求：
     *
     * - 调用合约的 ETH 余额必须至少为 `value`。
     * - 被调用的 Solidity 函数必须是 `payable`。
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev 与 {xref-Address-functionCall-address-bytes-}[`functionCall`] 相同，
     * 但执行的是静态调用。
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev 与 {xref-Address-functionCall-address-bytes-}[`functionCall`] 相同，
     * 但执行的是委托调用。
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev 用于验证对智能合约的低级别调用是否成功的工具，
     * 如果目标不是合约，或者在调用不成功的情况下冒泡回滚原因（回退到 {Errors.FailedCall}），则会回滚。
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // 仅当调用成功且返回数据为空时，才检查目标是否为合约否则我们已经知道它是一个合约
            /*
                在以太坊中，一个低级别的 call 操作成功返回（即 success == true）并且返回数据为空（returndata.length == 0），可能代表两种截然不同的情况：
                    1. 情况 A (预期情况): 你成功调用了一个合约的某个函数，而这个函数本身没有返回值（例如，一个设置状态的 setter 函数）。这是完全正常的。
                    2. 情况 B (危险的意外情况): 你“调用”了一个外部拥有账户 (EOA)，也就是一个由私钥控制的普通钱包地址，而不是一个合约地址。
                            对 EOA 进行 call 操作永远都会成功，并且永远返回空数据。
                            因为 EOA 没有任何代码可以执行，所以 EVM 认为这个操作“成功地什么也没做”。
                Address 库的 functionCall 系列函数，其设计初衷是为了安全地调用合约。如果一个开发者不小心传入了一个 EOA 地址，并且这个调用“成功”了，
                开发者可能会误以为他预期的操作（比如修改某个状态）已经完成了，但实际上什么都没有发生。这会导致非常隐蔽的逻辑错误。                
            */
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev 用于验证低级别调用是否成功的工具，如果调用不成功，则会回滚，
     * 要么冒泡回滚原因，要么使用默认的 {Errors.FailedCall} 错误。
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev 如果存在 returndata，则使用它回滚。否则使用 {Errors.FailedCall} 回滚。
     */
    function _revert(bytes memory returndata) private pure {
        // 查找回滚原因，如果存在则冒泡
        if (returndata.length > 0) {
            // 冒泡回滚原因的最简单方法是使用内存和汇编
            assembly ("memory-safe") {
                /*
                    在 Solidity 中，动态长度的 bytes 数组在内存中的存储方式是特定的：
                        * 变量本身（如此处的 returndata）是一个指针，指向内存中的某个位置。
                        * 这个位置开始的第一个 32 字节的“槽”，存储的是这个 bytes 数组的实际长度 (length)。
                        * 紧接着这个长度槽之后的内存区域，存储的才是 bytes 数组的实际内容。
                    mload(returndata):returndata 指向 bytes 数组的起始位置，而这个位置的第一个 32 字节槽里存的是数组的长度。
                    add(returndata, 0x20): 这句代码计算的是 returndata 的起始内存地址加上 32 字节。
                        根据我们刚才讲的内存布局，这正是 returndata 实际数据内容开始的内存地址。
                */
                revert(add(returndata, 0x20), mload(returndata))
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}
