// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

/**
 * @dev ERC-20标准的接口，如ERC中所定义。
 */
interface IERC20 {
    /**
     * @dev 当`value`个代币从一个账户（`from`）转移到另一个账户（`to`）时发出。
     *
     * 请注意，`value`可能为零。
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev 当通过调用{approve}来设置`owner`的`spender`的津贴时发出。`value`是新的津贴。
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev 返回现有的代币数量。
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev 返回`account`拥有的代币数量。
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 将`value`数量的代币从调用者的账户转移到`to`。
     *
     * 返回一个布尔值，指示操作是否成功。
     *
     * 发出{Transfer}事件。
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev 返回`spender`将通过{transferFrom}代表`owner`花费的剩余代币数量。默认为零。
     *
     * 当调用{approve}或{transferFrom}时，此值会更改。
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev 将`value`数量的代币设置为`spender`对调用者代币的津贴。
     *
     * 返回一个布尔值，指示操作是否成功。
     *
     * 重要提示：请注意，使用此方法更改津贴会带来风险，即有人可能会因不幸的交易排序而同时使用旧津贴和新津贴。
     * 缓解此竞争条件的一种可能解决方案是首先将支出者的津贴减少到0，然后再设置所需的值：
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * 发出{Approval}事件。
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev 使用津贴机制将`value`数量的代币从`from`转移到`to`。然后从调用者的津贴中扣除`value`。
     *
     * 返回一个布尔值，指示操作是否成功。
     *
     * 发出{Transfer}事件。
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
