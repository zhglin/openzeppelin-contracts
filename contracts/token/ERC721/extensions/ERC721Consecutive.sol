// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.3.0) (token/ERC721/extensions/ERC721Consecutive.sol)

pragma solidity ^0.8.24;

import {ERC721} from "../ERC721.sol";
import {IERC2309} from "../../../interfaces/IERC2309.sol";
import {BitMaps} from "../../../utils/structs/BitMaps.sol";
import {Checkpoints} from "../../../utils/structs/Checkpoints.sol";

/**
 * @dev ERC-2309 "连续转移扩展" 的实现，定义于
 * https://eips.ethereum.org/EIPS/eip-2309[ERC-2309]。
 *
 * 此扩展允许仅在合约构建期间铸造大批量的代币。对于可升级合约，这意味着批量铸造仅在代理部署期间可用，而在后续升级中不可用。
 * 默认情况下，这些批量操作一次限制为 5000 个代币，以适应链下索引器。
 * 使用此扩展会移除在合约构建期间铸造单个代币的能力。此能力在构建后恢复。在构建期间，只允许批量铸造。
 *
 * 重要提示：此扩展不会为批量铸造的代币调用 {_update} 函数。任何通过重写添加到此函数的逻辑在批量铸造代币时不会被触发。
 * 您可能还想重写 {_increaseBalance} 或 {_mintConsecutive} 来核算这些铸造。
 *
 * 重要提示：在重写 {_mintConsecutive} 时，请注意调用顺序。
 * 如果在执行{_mintConsecutive} 期间未首先调用 super 调用，{ownerOf} 可能会返回无效值。为安全起见，请在您的自定义逻辑之前执行 super 调用。
 * 
 * 高昂的 Gas 费：标准的 ERC-721 每铸造一个 NFT，就需要修改一次状态（在 _owners 映射中增加一条记录），这非常消耗 Gas。
 * 如果你要发行 10000 个NFT，就需要执行 10000 次状态修改，成本极高。
 * 效率低下：一次交易只能铸造少量 NFT，发行一个大型 PFP 项目可能需要上百次交易。
 * 
 * contract MyAwesomeNFT is ERC721, ERC721Consecutive {
 *     constructor(
 *          address projectOwner,
 *          address partner
 *     ) ERC721("My Awesome NFT", "MANFT") {
 *         // 铸造第一批：ID 0 到 4999，共 5000 个，给项目方
 *         _mintConsecutive(projectOwner, 5000);
 * 
 *         // 铸造第二批：ID 5000 到 5999，共 1000 个，给合作伙伴
 *         _mintConsecutive(partner, 1000);
 *     }
 * }
 * 这样，当你部署这个合约时，仅用了一笔非常低的 Gas 费，就完成了 6000 个 NFT 的铸造和分配。
 * 部署完成后，_mintConsecutive 将无法再被调用，，ERC721Consecutive 仅在合约构建期间启用。
 */
abstract contract ERC721Consecutive is IERC2309, ERC721 {
    using BitMaps for BitMaps.BitMap;
    using Checkpoints for Checkpoints.Trace160;

    Checkpoints.Trace160 private _sequentialOwnership;
    BitMaps.BitMap private _sequentialBurn;

    /**
     * @dev 批量铸造仅限于构造函数。
     * 任何在构造函数之外未发出 {IERC721-Transfer} 事件的批量铸造
     * 都不符合 ERC-721 标准。
     */
    error ERC721ForbiddenBatchMint();

    /**
     * @dev 超出每批次的最大铸造量。
     */
    error ERC721ExceededMaxBatchMint(uint256 batchSize, uint256 maxBatch);

    /**
     * @dev 不允许单独铸造。
     */
    error ERC721ForbiddenMint();

    /**
     * @dev 不支持批量销毁。
     */
    error ERC721ForbiddenBatchBurn();

    /**
     * @dev 一批连续代币的最大数量。这旨在限制必须为每个代币记录一个条目的链下索引 服务的压力，
     * 这些服务具有针对“不合理的大”批量代币的保护措施。
     *
     * 注意：重写默认值 5000 不会导致链上问题，
     * 但可能导致资产不被链下索引服务（包括市场）正确支持。
     */
    function _maxBatchSize() internal view virtual returns (uint96) {
        return 5000;
    }

    /**
     * @dev 参见 {ERC721-_ownerOf}。重写版本，检查作为批处理一部分铸造且尚未转移的代币的顺序所有权结构。
     */
    function _ownerOf(uint256 tokenId) internal view virtual override returns (address) {
        // 调用父合约（ERC721）的 _ownerOf，尝试从 _owners 映射中获取所有者
        address owner = super._ownerOf(tokenId);

        // 如果代币由核心拥有，或超出连续范围，则返回基础值
        // 高效地区分一个代币是“普通代币”还是“尚未转移过的批量铸造代币”。
        // owner != address(0): 如果一个 tokenId 在 _owners 映射表里有记录，说明这个代币要么是部署后被单个铸造的，要么是批量铸造后至少被转移过一次的。
        //      在这两种情况下,它的所有权已经被明确地、单独地记录下来了，我们应该相信这个记录。
        // tokenId > type(uint96).max: 为了极致地节省 Gas，内部用来记录批量所有权的数据结构 _sequentialOwnership 使用了 uint96 来存储tokenId。
        //      这意味着，批量铸造系统本身就无法处理超过 `uint96` 最大值的 `tokenId`。
        // tokenId < _firstConsecutiveId(): 这是第2个条件的补充。如果一个 tokenId 比批量铸造的第一个 ID 还要小，那它显然也不可能是在批量铸造的范围之内。    
        if (owner != address(0) || tokenId > type(uint96).max || tokenId < _firstConsecutiveId()) {
            return owner;
        }

        // 否则，检查代币未被销毁，并从锚点获取所有权
        // 注意：无需安全转换，我们知道 tokenId <= type(uint96).max
        // 在 _owners 表里查不到主人 (owner == address(0))。ID 在 uint96 的范围内。ID 大于等于批量铸造的起始 ID。
        // 有可能是批量铸造出来的，且从未被转移过的代币。
        // 从_sequentialBurn先检查这个代币有没有被销毁（burned）。如果被销毁了，就直接返回 address(0)。
        // 否则，就从 _sequentialOwnership 里查找这个代币的主人。
        // lowerLookup(uint96(tokenId))“从头开始查找检查点列表，返回第一个 `key` 大于或等于（`>=`）你所查询的 `tokenId` 的那个检查点的值。”
        return _sequentialBurn.get(tokenId) ? address(0) : address(_sequentialOwnership.lowerLookup(uint96(tokenId)));
    }

    /**
     * @dev 为 `to` 铸造一批长度为 `batchSize` 的代币。
     * 返回批处理中铸造的第一个代币的 ID；如果 `batchSize` 为 0，则返回到目前为止已铸造的连续 ID 的数量。
     *
     * 要求：
     * - `batchSize` 不得大于 {_maxBatchSize}。
     * - 该函数在合约的构造函数中调用（直接或间接）。
     * 警告：不发出 `Transfer` 事件。只要在构造函数内部完成，这就是符合 ERC-721 的，这是此函数强制执行的。
     * 警告：不在接收者上调用 `onERC721Received`。
     * 发出 {IERC2309-ConsecutiveTransfer} 事件。
     * 
     * address(this).code.length,检查当前合约的字节码（bytecode）大小是否大于 0
     * 它的实际作用是判断当前代码是否正在合约的构造函数 (`constructor`) 中执行。
     * 具体来说，一个合约的生命周期有两个关键阶段：
     *  1. 构造（Construction）阶段：当合约正在被部署，
     *      constructor函数正在执行时，合约的完整代码还没有被正式存储到区块链上它自己的地址里。在这个阶段，address(this).code.length 的返回值是 `0`。
     *  2. 已部署（Deployed）阶段：
     *      一旦 constructor 执行完毕，合约就成功部署了。它的代码被完整地存储在了链上。
     *      从这时起，在合约内部调用address(this).code.length，返回值将是合约字节码的长度，一定大于 `0`。
     */
    function _mintConsecutive(address to, uint96 batchSize) internal virtual returns (uint96) {
        uint96 next = _nextConsecutiveId();

        // 铸造大小为 0 的批次是无操作的
        if (batchSize > 0) {
            // 仅在构造期间允许批量铸造
            if (address(this).code.length > 0) {
                revert ERC721ForbiddenBatchMint();
            }
            if (to == address(0)) {
                revert ERC721InvalidReceiver(address(0));
            }

            uint256 maxBatchSize = _maxBatchSize();
            if (batchSize > maxBatchSize) {
                revert ERC721ExceededMaxBatchMint(batchSize, maxBatchSize);
            }

            // 推送所有权检查点并发出事件
            uint96 last = next + batchSize - 1;
            // 从上一个检查点结束的位置开始，直到 `tokenId` 500 为止（包含500），都属于 `owner_A`。
            _sequentialOwnership.push(last, uint160(to));

            // 此函数所需的不变性得以保留，因为新的 sequentialOwnership 检查点将 `batchSize` 个新代币的所有权归于账户 `to`。
            _increaseBalance(to, batchSize);

            emit ConsecutiveTransfer(next, last, address(0), to);
        }

        return next;
    }

    /**
     * @dev 参见 {ERC721-_update}。重写版本，将正常铸造限制在构造之后。
     *
     * 警告：使用 {ERC721Consecutive} 会阻止在构造期间进行铸造，而支持 {_mintConsecutive}。
     * 构造后，{_mintConsecutive} 不再可用，通过 {_update} 进行的铸造变为可用。
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);

        // 仅在构造函数执行后铸造
        if (previousOwner == address(0) && address(this).code.length == 0) {
            revert ERC721ForbiddenMint();
        }

        // 记录销毁
        if (
            to == address(0) && // 如果我们销毁
            tokenId < _nextConsecutiveId() && // 并且 tokenId 是在批处理中铸造的
            !_sequentialBurn.get(tokenId) // 并且代币从未被标记为已销毁
        ) {
            // 标记销毁
            _sequentialBurn.set(tokenId);
        }

        return previousOwner;
    }

    /**
     * @dev 用于偏移 `_nextConsecutiveId` 中的第一个代币 ID
     */
    function _firstConsecutiveId() internal view virtual returns (uint96) {
        return 0;
    }

    /**
     * @dev 返回使用 {_mintConsecutive} 铸造的下一个 tokenId。如果之前没有铸造过连续的 tokenId，
     * 它将返回 {_firstConsecutiveId}。
     */
    function _nextConsecutiveId() private view returns (uint96) {
        (bool exists, uint96 latestId, ) = _sequentialOwnership.latestCheckpoint();
        return exists ? latestId + 1 : _firstConsecutiveId();
    }
}
