// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC4626.sol)

pragma solidity >=0.6.2;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {IERC20Metadata} from "../token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev ERC-4626 "代币化金库标准" 的接口，定义于
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626]。
 */
interface IERC4626 is IERC20, IERC20Metadata {
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev 返回金库用于记账、存款和取款的基础代币的地址。
     *
     * - 必须是 ERC-20 代币合约。
     * - 不得还原。
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev 返回金库“管理”的基础资产的总量。
     *
     * - 应包括收益产生的任何复利。
     * - 必须包括从金库中资产收取的所有费用。
     * - 不得还原。
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev 在所有条件都满足的理想情况下，
     * 返回金库将为所提供的资产数量兑换的份额数量。
     *
     * - 不得包括从金库中资产收取的任何费用。
     * - 不得因调用者而显示任何差异。
     * - 在执行实际兑换时，不得反映滑点或其他链上条件。
     * - 不得还原。
     *
     * 注意：此计算可能不反映“每个用户”的每股价格，而应反映
     * “普通用户”的每股价格，即普通用户在兑换时应期望看到的价格。
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev 在所有条件都满足的理想情况下，
     * 返回金库将为所提供的份额数量兑换的资产数量。
     *
     * - 不得包括从金库中资产收取的任何费用。
     * - 不得因调用者而显示任何差异。
     * - 在执行实际兑换时，不得反映滑点或其他链上条件。
     * - 不得还原。
     *
     * 注意：此计算可能不反映“每个用户”的每股价格，而应反映
     * “普通用户”的每股价格，即普通用户在兑换时应期望看到的价格。
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev 通过存款调用，返回可以为接收者存入金库的基础资产的最大数量。
     *
     * - 如果接收者受到某些存款限制，则必须返回一个有限值。
     * - 如果对可能存入的最大资产数量没有限制，则必须返回 2 ** 256 - 1。
     * - 不得还原。
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @dev 允许链上或链下用户在当前区块，
     * 根据当前的链上条件，模拟其存款的效果。
     *
     * - 必须返回尽可能接近且不超过在同一交易中存款调用中将铸造的
     *   金库份额的确切数量。即，如果在同一交易中调用，
     *   `deposit` 应返回与 `previewDeposit` 相同或更多的份额。
     * - 不得考虑像 `maxDeposit` 返回的存款限制，并应始终假定
     *   存款将被接受，无论用户是否有足够的代币批准等。
     * - 必须包括存款费用。集成商应意识到存款费用的存在。
     * - 不得还原。
     *
     * 注意：`convertToShares` 和 `previewDeposit` 之间的任何不利差异都应被视为
     * 份额价格的滑点或其他类型的条件，意味着存款人将因存款而损失资产。
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev 通过存入确切数量的基础代币，为接收者铸造金库份额。
     *
     * - 必须发出 `Deposit` 事件。
     * - 可以支持一种额外的流程，其中基础代币在存款执行前由金库合约拥有，
     *   并在存款期间进行核算。
     * - 如果所有资产都无法存入（由于达到存款限额、滑点、用户未向金库合约批准足够的
     *   基础代币等），则必须还原。
     *
     * 注意：大多数实现将需要使用金库的基础资产代币对金库进行预先批准。
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev 通过铸币调用，返回可以为接收者铸造的金库份额的最大数量。
     * - 如果接收者受到某些铸币限制，则必须返回一个有限值。
     * - 如果对可能铸造的最大份额数量没有限制，则必须返回 2 ** 256 - 1。
     * - 不得还原。
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @dev 允许链上或链下用户在当前区块，
     * 根据当前的链上条件，模拟其铸币的效果。
     *
     * - 必须返回尽可能接近且不少于在同一交易中铸币调用中将存入的
     *   资产的确切数量。即，如果在同一交易中调用，
     *   `mint` 应返回与 `previewMint` 相同或更少的资产。
     * - 不得考虑像 `maxMint` 返回的铸币限制，并应始终假定
     *   铸币将被接受，无论用户是否有足够的代币批准等。
     * - 必须包括存款费用。集成商应意识到存款费用的存在。
     * - 不得还原。
     *
     * 注意：`convertToAssets` 和 `previewMint` 之间的任何不利差异都应被视为
     * 份额价格的滑点或其他类型的条件，意味着存款人将因铸币而损失资产。
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev 通过存入基础代币，为接收者铸造确切数量的金库份额。
     *
     * - 必须发出 `Deposit` 事件。
     * - 可以支持一种额外的流程，其中基础代币在铸币执行前由金库合约拥有，
     *   并在铸币期间进行核算。
     * - 如果所有份额都无法铸造（由于达到存款限额、滑点、用户未向金库合约批准足够的
     *   基础代币等），则必须还原。
     *
     * 注意：大多数实现将需要使用金库的基础资产代币对金库进行预先批准。
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev 通过取款调用，返回可以从金库中所有者余额中提取的基础资产的最大数量。
     *
     * - 如果所有者受到某些取款限制或时间锁，则必须返回一个有限值。
     * - 不得还原。
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @dev 允许链上或链下用户在当前区块，
     * 根据当前的链上条件，模拟其取款的效果。
     *
     * - 必须返回尽可能接近且不少于在同一交易中取款调用中将销毁的
     *   金库份额的确切数量。即，如果在同一交易中调用，
     *   `withdraw` 应返回与 `previewWithdraw` 相同或更少的份额。
     * - 不得考虑像 `maxWithdraw` 返回的取款限制，并应始终假定
     *   取款将被接受，无论用户是否有足够的份额等。
     * - 必须包括取款费用。集成商应意识到取款费用的存在。
     * - 不得还原。
     *
     * 注意：`convertToShares` 和 `previewWithdraw` 之间的任何不利差异都应被视为
     * 份额价格的滑点或其他类型的条件，意味着存款人将因存款而损失资产。
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev 从所有者处销毁份额，并将确切数量的基础代币发送给接收者。
     *
     * - 必须发出 `Withdraw` 事件。
     * - 可以支持一种额外的流程，其中基础代币在取款执行前由金库合约拥有，
     *   并在取款期间进行核算。
     * - 如果所有资产都无法提取（由于达到取款限额、滑点、所有者没有足够的份额等），
     *   则必须还原。
     *
     * 注意，某些实现将需要在执行取款之前向金库预先请求。
     * 这些方法应单独执行。
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @dev 通过赎回调用，返回可以从金库中所有者余额中赎回的金库份额的最大数量。
     *
     * - 如果所有者受到某些取款限制或时间锁，则必须返回一个有限值。
     * - 如果所有者不受任何取款限制或时间锁的约束，则必须返回 `balanceOf(owner)`。
     * - 不得还原。
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev 允许链上或链下用户在当前区块，
     * 根据当前的链上条件，模拟其赎回的效果。
     *
     * - 必须返回尽可能接近且不超过在同一交易中赎回调用中将提取的
     *   资产的确切数量。即，如果在同一交易中调用，
     *   `redeem` 应返回与 `previewRedeem` 相同或更多的资产。
     * - 不得考虑像 `maxRedeem` 返回的赎回限制，并应始终假定
     *   赎回将被接受，无论用户是否有足够的份额等。
     * - 必须包括取款费用。集成商应意识到取款费用的存在。
     * - 不得还原。
     *
     * 注意：`convertToAssets` 和 `previewRedeem` 之间的任何不利差异都应被视为
     * 份额价格的滑点或其他类型的条件，意味着存款人将因赎回而损失资产。
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev 从所有者处销毁确切数量的份额，并将基础代币的资产发送给接收者。
     *
     * - 必须发出 `Withdraw` 事件。
     * - 可以支持一种额外的流程，其中基础代币在赎回执行前由金库合约拥有，
     *   并在赎回期间进行核算。
     * - 如果所有份额都无法赎回（由于达到取款限额、滑点、所有者没有足够的份额等），
     *   则必须还原。
     *
     * 注意：某些实现将需要在执行取款之前向金库预先请求。
     * 这些方法应单独执行。
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
