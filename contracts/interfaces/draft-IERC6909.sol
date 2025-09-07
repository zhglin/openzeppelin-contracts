// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (interfaces/draft-IERC6909.sol)

pragma solidity >=0.6.2;

import {IERC165} from "../utils/introspection/IERC165.sol";

/**
 * @dev 符合 ERC-6909 标准的合约所需接口，定义于
 * https://eips.ethereum.org/EIPS/eip-6909[ERC]。
 */
interface IERC6909 is IERC165 {
    /**
     * @dev 当 `spender` 对 `owner` 的 `id` 类型代币的授权额度被设置为 `amount` 时发出。
     * 新的授权额度是 `amount`。
     */
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);

    /**
     * @dev 当 `owner` 授予或撤销 `spender` 的操作员状态时发出。
     */
    event OperatorSet(address indexed owner, address indexed spender, bool approved);

    /**
     * @dev 当 `caller` 发起将 `amount` 数量的 `id` 类型代币从 `sender` 移动到 `receiver` 时发出。
     */
    event Transfer(
        address caller,
        address indexed sender,
        address indexed receiver,
        uint256 indexed id,
        uint256 amount
    );

    /**
     * @dev 返回 `owner` 拥有的 `id` 类型代币的数量。
     */
    function balanceOf(address owner, uint256 id) external view returns (uint256);

    /**
     * @dev 返回 `spender` 被允许代表 `owner` 使用的 `id` 类型代币的数量。
     *
     * 注意：不包括操作员的授权额度。
     */
    function allowance(address owner, address spender, uint256 id) external view returns (uint256);

    /**
     * @dev 如果 `spender` 被设置为 `owner` 的操作员，则返回 true。
     */
    function isOperator(address owner, address spender) external view returns (bool);

    /**
     * @dev 为调用者的 `id` 类型代币向 `spender` 设置 `amount` 的批准额度。
     * `type(uint256).max` 的 `amount` 表示无限批准。
     *
     * 必须返回 true。
     */
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);

    /**
     * @dev 为调用者的代币向 `spender` 授予或撤销任何代币 ID 的无限转移权限。
     *
     * 必须返回 true。
     */
    function setOperator(address spender, bool approved) external returns (bool);

    /**
     * @dev 将 `amount` 数量的 `id` 类型代币从调用者的账户转移到 `receiver`。
     * 必须返回 true。
     */
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);

    /**
     * @dev 将 `amount` 数量的 `id` 类型代币从 `sender` 转移到 `receiver`。
     * 必须返回 true。
     */
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);
}

/**
 * @dev {IERC6909} 的可选扩展，增加了元数据函数。
 */
interface IERC6909Metadata is IERC6909 {
    /**
     * @dev 返回 `id` 类型代币的名称。
     */
    function name(uint256 id) external view returns (string memory);

    /**
     * @dev 返回 `id` 类型代币的股票代码符号。
     */
    function symbol(uint256 id) external view returns (string memory);

    /**
     * @dev 返回 `id` 类型代币的小数位数。
     */
    function decimals(uint256 id) external view returns (uint8);
}

/**
 * @dev {IERC6909} 的可选扩展，增加了内容 URI 函数。
 */
interface IERC6909ContentURI is IERC6909 {
    /**
     * @dev 返回合约的 URI。
     */
    function contractURI() external view returns (string memory);

    /**
     * @dev 返回 `id` 类型代币的 URI。
     */
    function tokenURI(uint256 id) external view returns (string memory);
}

/**
 * @dev {IERC6909} 的可选扩展，增加了代币供应量函数。
 */
interface IERC6909TokenSupply is IERC6909 {
    /**
     * @dev 返回 `id` 类型代币的总供应量。
     */
    function totalSupply(uint256 id) external view returns (uint256);
}
