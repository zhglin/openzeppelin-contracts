// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/ERC4626.sol)

pragma solidity ^0.8.20;

import {IERC20, IERC20Metadata, ERC20} from "../ERC20.sol";
import {SafeERC20} from "../utils/SafeERC20.sol";
import {IERC4626} from "../../../interfaces/IERC4626.sol";
import {Math} from "../../../utils/math/Math.sol";

/**
 * @dev ERC-4626 "代币化金库标准" 的实现，定义于
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626]。
 *
 * 此扩展允许通过标准化的 {deposit}、{mint}、{redeem} 和 {burn} 工作流，
 * 铸造和销毁“份额”（使用 ERC-20 继承表示）以换取基础“资产”。
 * 此合约扩展了 ERC-20 标准。任何随之包含的附加扩展都将影响此合约代表的“份额”代币，
 * 而不是作为独立合约的“资产”代币。
 *
 * [注意]
 * ====
 * 在空的（或接近空的）ERC-4626 金库中，存款极有可能通过“捐赠”抢跑交易被盗，
 * 这种捐赠会抬高份额的价格。这通常被称为捐赠攻击或通胀攻击，本质上是一个滑点问题。
 * 金库部署者可以通过初始存入一笔不可忽略数量的资产来防范此攻击，从而使价格操纵变得不可行。
 * 提款同样可能受到滑点的影响。用户可以通过验证收到的金额是否符合预期来防范此攻击以及一般的意外滑点，
 * 可以使用一个执行这些检查的包装器，例如
 * https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router]。
 *
 * 从 v4.9 开始，此实现引入了可配置的虚拟资产和份额，以帮助开发者降低该风险。
 * `_decimalsOffset()` 对应于基础资产小数位数和金库小数位数之间的十进制表示偏移量。
 * 此偏移量还决定了金库中虚拟份额与虚拟资产的比率，这本身就决定了初始汇率。
 * 虽然不能完全阻止攻击，但分析表明，默认偏移量（0）使其无利可图，
 * 即使攻击者能够从多个用户存款中捕获价值，
 * 因为虚拟份额捕获的价值（来自攻击者的捐赠）与攻击者的预期收益相匹配。
 * 使用更大的偏移量，攻击的成本将比其利润高出几个数量级。
 * 有关基础数学的更多详细信息，请参见 xref:ROOT:erc4626.adoc#inflation-attack[此处]。
 *
 * 这种方法的缺点是，虚拟份额确实会捕获（非常小）一部分金库应计的价值。
 * 此外，如果金库出现亏损，用户试图退出金库，虚拟份额和资产将导致第一个退出的用户
 * 遭受较小的损失，而损害了最后退出的用户，他们将遭受更大的损失。
 * 希望恢复到 v4.9 之前行为的开发者只需重写 `_convertToShares` 和 `_convertToAssets` 函数。
 *
 * 要了解更多信息，请查看我们的 xref:ROOT:erc4626.adoc[ERC-4626 指南]。
 * ====
 */
abstract contract ERC4626 is ERC20, IERC4626 {
    using Math for uint256;

    // 底层代币
    IERC20 private immutable _asset;
    // 底层代币的小数位数,获取不到就设置默认值18
    uint8 private immutable _underlyingDecimals;

    /**
     * @dev 尝试为 `receiver` 存入超过最大允许数量的资产。
     */
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);

    /**
     * @dev 尝试为 `receiver` 铸造超过最大允许数量的份额。
     */
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /**
     * @dev 尝试为 `owner` 提取超过最大允许数量的资产。
     */
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);

    /**
     * @dev 尝试为 `owner` 赎回超过最大允许数量的份额。
     */
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    /**
     * @dev 设置基础资产合约。这必须是一个与 ERC20 兼容的合约（ERC-20 或 ERC-777）。
     */
    constructor(IERC20 asset_) {
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _underlyingDecimals = success ? assetDecimals : 18;
        _asset = asset_;
    }

    /**
     * @dev 尝试获取资产的小数位数。返回值为 false 表示尝试因某种原因失败。
     * 为什么使用staticcall而不是asset.decimals()?
     *      合约部署的原子性：constructor 是在部署合约时仅执行一次的函数。如果 constructor 中的任何一步执行失败（比如一个外部调用 revert
     *          了），整个合约的部署就会失败，无法创建合约实例。
     *      外部合约的不可预测性：在部署 ERC4626 金库合约时，传入的 asset 地址指向的代币合约有多种不确定性：
     *          可能没有 `decimals` 函数：一些早期的或不标准的 ERC20 代币可能没有这个函数。
     *          `decimals` 函数可能 revert：该函数内部可能因为某些原因（如bug）而执行失败。
     *          可能不是一个合约地址：传入的地址可能是一个普通的外部账户（EOA），没有代码。
     *          返回值不规范：decimals 函数可能返回一个超过 uint8 范围的数值，导致类型转换失败。 
     *      `staticcall` 的优势：
     *          避免主调用 Revert：使用低级别的 staticcall 进行外部调用，即使目标函数 revert 了，staticcall 本身也不会 revert，而是会返回一个 bool
     *          类型的 success 标志（此时为 false）。这给了我们的合约一个处理错误的机会。
     *          提供后备方案：代码可以通过检查 success 标志来判断调用是否成功。如果失败了（success == false），就可以优雅地切换到一个默认值（在这里是
     *          18），从而保证金库合约本身能够成功部署。  
     * 
     *  出错也要能部署合约的原因：
     *      decimals（小数位数）这个值，对于金库的核心逻辑来说，并非致命的。
     */
    function _tryGetAssetDecimals(IERC20 asset_) private view returns (bool ok, uint8 assetDecimals) {
        (bool success, bytes memory encodedDecimals) = address(asset_).staticcall(
            abi.encodeCall(IERC20Metadata.decimals, ())
        );
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }

    /**
     * @dev 小数位数是通过在基础资产小数位数之上添加小数偏移量来计算的。
     * 这个“原始”值在金库合约构建期间被缓存。如果此读取操作失败（例如，资产尚未创建），
     * 则使用默认值 18 来表示基础资产的小数位数。
     *
     * 参见 {IERC20Metadata-decimals}。
     */
    function decimals() public view virtual override(IERC20Metadata, ERC20) returns (uint8) {
        return _underlyingDecimals + _decimalsOffset();
    }

    /// @inheritdoc IERC4626
    function asset() public view virtual returns (address) {
        return address(_asset);
    }

    /// @inheritdoc IERC4626
    // 底层代币总数量
    function totalAssets() public view virtual returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @inheritdoc IERC4626
    // 资产到份额
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    // 份额到资产
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    // 返回可以为接收者存入金库的基础资产的最大数量。
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    // 返回可以为接收者铸造的金库份额的最大数量。
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    // 返回可以从金库中所有者余额中提取的基础资产的最大数量。
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    // 返回可以从金库中所有者余额中赎回的金库份额的最大数量
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf(owner);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    // 通过存入确切数量的基础代币，为接收者铸造金库份额。
    // `deposit` (存款): 你指定想要存入多少`资产` (asset)，金库会根据当前价格计算并给你相应数量的 份额 (share)。
    //   * 用户说：“我有 1,000 USDC，帮我存进金库。”
    function deposit(uint256 assets, address receiver) public virtual returns (uint256) {
        // 检查存款是否超过最大允许数量
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    // `mint` (铸造): 你指定想要铸造多少`份额` (share)，金库会计算并要求你存入相应数量的 资产 (asset)。
    //   * 用户说：“我想要正好 500 个金库份额，告诉我需要存多少 USDC。”
    //这种方式更适合需要精确控制份额数量的场景，例如：
    //* DeFi 协议集成：某个协议可能要求用户必须抵押（或提供）整数数量的金库份额。
    //* 策略性持仓：投资者可能希望持有金库总量的特定百分比，需要精确计算并铸造份额。
    //* 避免“灰尘”份额：一些用户不希望自己的钱包里出现 995.12345 这样带有许多小数的份额数量，他们希望得到一个整数。
    function mint(uint256 shares, address receiver) public virtual returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    /// @inheritdoc IERC4626
    // 从所有者处销毁份额，并将确切数量的基础代币发送给接收者。
    // `withdraw` (取款): 你指定想要取出多少`资产` (asset)，金库会计算并销毁（burn）你相应数量的 份额 (share)。
    //   * 用户说：“我需要正好 500 USDC，帮我从金库里取出来。”
    // 适用场景:
    // * 你需要一笔精确数额的钱去支付或购买别的东西。
    // * 你想从金库里取出一笔整数的资产，保持账户整洁。
    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    // `redeem` (赎回): 你指定想要赎回多少`份额` (share)，金库会计算并给你相应数量的 资产 (asset)。
    //   * 用户说：“我想卖掉我的 10 份金库份额，告诉我能拿回多少 USDC。”
    // 适用场景:
    // * 你想卖掉你持有的全部或一部分份额。
    // * 你想赎回一个整数的份额。
    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @dev 内部转换函数（从资产到份额），支持舍入方向。
     * 
     * 获得的份额数 = 存入的资产数 × 每单位资产能兑换的份额数
     * 而“每单位资产能兑换的份额数”就是 总份额 / 总资产。所以公式是：
     * shares = assets * (totalSupply() / totalAssets())
     * 
     * 这两个加法是关键，有两个目的：
     *  防止除以零：当 totalAssets() 为 0 时，避免交易失败。
     *  缓解通胀攻击
     * 
     * 为什么必须向下取整？
     *  如果向上取整，用户会得到 101 份。这意味着金库“凭空”多发了 0.1份份额的凭证，
     *  稀释了所有其他老用户的份额价值。这相当于让老用户为新用户的入场“买单”，是不可接受的。
     *  如果向下取整，用户会得到 100 份。
     *  那 0.9份对应的微量资产会留在金库里，作为利润（或弥补损耗）平均分配给所有份额持有者（包括这位刚进来的新用户）。这是公平且安全的。
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    /**
     * @dev 内部转换函数（从份额到资产），支持舍入方向。
     * x ** y 就表示 x 的 y 次方
     * 
     * 而“每份份额的价值”就是 总资产 / 总份额。所以公式是：
     * assets = shares * (totalAssets() / totalSupply())
     * 
     * 这两个加法是关键，有两个目的：
     *  防止除以零：如果金库是空的，totalSupply() 会是 0。如果没有 + 10 ** _decimalsOffset()，就会导致除以零的错误，使交易 revert。
     *  缓解通胀攻击
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    /**
     * @dev 存款/铸造的通用工作流。
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual {
        // 如果 asset() 是 ERC-777，`transferFrom` 可以在转账发生前通过 `tokensToSend` 钩子触发重入。
        // 另一方面，在转账后触发的 `tokenReceived` 钩子会调用金库，我们假设它不是恶意的。
        //
        // 结论：我们需要在铸造之前进行转账，这样任何重入都会在资产转移和份额铸造之前发生，这是一个有效的状态。
        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev 提款/赎回的通用工作流。
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // 如果 asset() 是 ERC-777，`transfer` 可以在转账发生后通过 `tokensReceived` 钩子触发重入。
        // 另一方面，在转账前触发的 `tokensToSend` 钩子会调用金库，我们假设它不是恶意的。
        //
        // 结论：我们需要在销毁之后进行转账，这样任何重入都会在份额销毁和资产转移之后发生，这是一个有效的状态。
        _burn(owner, shares);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /**
     * 通胀攻击:
     *  第 1 步: 攻击者存入微量资产
     *      攻击者抢先存入 1 wei 的 WETH。假设初始兑换率为 1:1，他获得了 1 wei 的份额。
     *      金库状态: totalAssets = 1 wei, totalSupply = 1 wei。
     *  第 2 步: 攻击者“捐赠”
     *      击者直接向金库合约地址转账（捐赠）1,000 WETH。
     *      金库状态: totalAssets = 1,000 WETH + 1 wei, totalSupply = 1 wei (份额没有变化)
     *  第 3 步: 受害者的交易执行
     *      受害者存入 1,000 WETH。金库需要计算应给他多少份额。
     *      计算: shares = (1,000 WETH * 1 wei) / (1,000 WETH + 1 wei)
     *      这个计算结果无限接近 1 wei，但由于 Solidity 的整数除法会向下取整，最终结果是 0。
     *      结果: 受害者存入了 1,000 WETH，但只得到了 0 份额。他的钱被合法地“吞”了。
     *  第 4 步: 攻击者获利
     *      现在金库里有大约 2,000 WETH，而攻击者拥有唯一的 1 wei 份额。他可以调用 redeem 函数，凭借这 1 wei 的份额取走金库里所有的 ~2,000 WETH。
     *      攻击者利润: ~1,000 WETH。
     */
    /**
     * 加入虚拟资产,虚拟份额的概念，以帮助减轻通胀攻击的影响。
     *  第 1 步: 攻击者存入微量资产
     *      攻击者存入 1 wei 的 WETH。计算: shares = 1 * mulDiv(0 + 1, 0 + 1) = 1,获得了 1 wei 的份额。
     *      金库状态: totalAssets = 1 wei, totalSupply = 1 wei。
     *  第 2 步: 攻击者“捐赠”
     *      攻击者直接捐赠 1,000 WETH。
     *      金库状态:totalAssets = 1,000 WETH + 1 wei,totalSupply = 1 wei (份额没有变化)。
     *  第 3 步 (关键): 价值如何被捕获？在受害者入场之前，我们先分析一下金库的价值。
     *      总价值: ~1,000 WETH 的资产。
     *      总份额 (真实+虚拟): totalSupply (1 wei) + 虚拟份额 (1 wei) = 2 wei。
     *      每份份额的价值: ~1,000 WETH / 2 = ~500 WETH。
     *      这意味着，攻击者捐赠的 1,000 WETH 的价值，被他自己的 1 wei 真实份额和协议的 1 wei 虚拟份额平分了。他自己的那份只值 ~500 WETH。他投入了
     *      1,000 WETH，但手里凭证的价值瞬间缩水一半，立即亏损了 500 WETH。这部分价值被“虚拟份额”捕获了，并会留在金库里，让所有未来的储户受益。
     *  第 4 步: 受害者的交易执行    
     *      受害者存入 1,000 WETH。
     *      计算: shares = 1,000 WETH * mulDiv(totalSupply + 1, totalAssets + 1)
     *           shares = 1,000 WETH * mulDiv(1 + 1, (1,000 WETH + 1) + 1)
     *           shares ≈ 1,000 WETH * (2 / 1,000 WETH) ≈ 2 份份额。
     *      结果: 受害者存入 1,000 WETH，大约能得到 2 份份额（具体数值取决于精度和取整）。他没有像之前那样得到 0。
     */
    // 攻击者花费了 ~1,000 WETH，但其份额的价值远低于此，他无法通过受害者的存款来弥补自己的损失或窃取受害者的资金。因此，攻击变得无利可图。
    // 这个机制虽然不能完全防止“滑点”（受害者依然可能因价格波动承受损失），但它成功地移除了攻击者的经济激励，从而从根本上化解了这种通胀攻击。

    /**
     * 每个投资者理论上都会因为虚拟份额/虚拟资产的存在而“损失”掉极其微小的一部分价值。
     * 您可以把这部分“损失”理解为一种为安全支付的、极其廉价的“保险费”。
     * 我们来分析一下这个“损失”到底有多大，以及为什么它是值得的。
     * 1. “损失”的量级：微乎其微
     *      在默认设置下，虚拟部分只有 1 wei 的资产和 1 wei 的份额。
     *      我们设想一个正常运作的金库，里面有 1,000,000 个 WETH（即 10^6 * 10^18 wei）和相应的大量份额。
     *      在计算价值时：总资产: 1,000,000 WETH + 1 wei, 总份额: 实际总份额 + 1 wei
     *      虚拟份额占总份额的比例是 1 / (实际总份额 + 1)。当金库规模变大时，这个比例会迅速变得无限小，完全可以忽略不计，甚至小于计算中的舍入误差。
     *      这个效应只在金库总资产极低（接近于0）时才稍微明显，而这恰恰是通胀攻击唯一能奏效的场景。
     * 2. 权衡：微小的成本 vs. 巨大的安全收益
     *      这里的核心是一个权衡：
     *      不使用虚拟份额: 投资者不需要支付任何“保险费”。但是，第一个（或前几个）储户面临着他们的全部资金（100%）可能被通胀攻击盗走的巨大风险。
     *      用虚拟份额:每个投资者贡献出价值极其微小的一部分（比如十亿分之一）给虚拟份额。作为回报，整个金库从一开始就对通胀攻击免疫，所有人的资金都得到了保护。
     *      这笔“保险费”是一次性的（在你存入时计算兑换率的瞬间产生影响），并且成本极低，但它防范的是一种可能导致100%本金损失的灾难性攻击。
     *      因此，这笔交易是极其划算的。
     * 3. 亏损时的影响
     *      当金库本身投资失利产生亏损时，虚拟份额的存在确实会轻微影响亏损的分配。
     *      由于虚拟份额/资产起到了一个微小的“缓冲”作用，第一个退出的用户可能会比理论上承担更少的亏损。
     *      这个效应会逐级传递，导致最后几个退出的用户承担的亏损会比理论上略微多一点点。
     *      同样，这个影响在金库有一定规模时也是微乎其"wei"，可以忽略不计的。
     */
    // 虚拟份额/资产看作是金库内置的、自动运行的、成本极低的保险机制，就很容易理解它的价值了。
    // 它通过让所有用户贡献出几乎可以忽略不计的价值，为整个协议提供了一个强大的、针对特定灾难性风险的安全保障。
    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }
}
