// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity >=0.6.2;

import {IERC20} from "../IERC20.sol";

/**
 * @dev ERC20 标准中可选的元数据函数接口。
 * _自 v4.1 版本可用。_
 * 把 IERC20 和 IERC20Metadata 分开，是为了精确地遵守官方标准，将强制功能和可选功能解耦。
 * 
 *  保留 IERC20Metadata is IERC20 的继承关系，是为了建立一个逻辑上正确且对外部使用者极其友好的类型系统。它向整个生态系统声明：任何一个提供了元
 *  数据的ERC20代币，本身首先就是一个完整的ERC20代币。这种设计思想，使得其他合约在与它交互时，可以依赖这个更丰富的 IERC20Metadata 类型，从而写出更简洁、更安全、可读性更强的代码。
 
 *  IERC20Metadata is IERC20 这行代码的含义是：一个“带元数据的ERC20接口”首先它是一个“ERC20接口”。
 *  这建立了一个清晰的“is-a”（是一个）关系。它创造了一个比 IERC20更具体、更丰富的类型，这个类型代表了“一个功能完整的、且包含名称和符号的ERC20代币”。
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev 返回代币的名称。
     */
    function name() external view returns (string memory);

    /**
     * @dev 返回代币的符号。
     */
    function symbol() external view returns (string memory);

    /**
     * @dev 返回代币的小数位数。
     */
    function decimals() external view returns (uint8);
}
