// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/IGovernor.sol)

pragma solidity >=0.8.4;

import {IERC165} from "../interfaces/IERC165.sol";
import {IERC6372} from "../interfaces/IERC6372.sol";

/**
 * @dev {Governor} 核心的接口。
 *
 * 注意：为了与 GovernorBravo 事件兼容，事件参数缺少 `indexed` 关键字。
 * 将事件参数设为 `indexed` 会影响事件的解码方式，可能会破坏现有的索引器。
 */
interface IGovernor is IERC165, IERC6372 {
    enum ProposalState {
        Pending,     // 待定
        Active,      // 活跃
        Canceled,    // 已取消
        Defeated,    // 已失败
        Succeeded,   // 已成功
        Queued,      // 已排队
        Expired,     // 已过期
        Executed     // 已执行
    }

    /**
     * @dev 空提案或提案调用的参数长度不匹配。
     */
    error GovernorInvalidProposalLength(uint256 targets, uint256 calldatas, uint256 values);

    /**
     * @dev 已经投过票了。
     */
    error GovernorAlreadyCastVote(address voter);

    /**
     * @dev 此合约禁用了代币存款。
     */
    error GovernorDisabledDeposit();

    /**
     * @dev 该账户不是治理执行者。
     */
    error GovernorOnlyExecutor(address account);

    /**
     * @dev 提案 ID 不存在。
     */
    error GovernorNonexistentProposal(uint256 proposalId);

    /**
     * @dev 提案的当前状态不符合执行操作的要求。
     * `expectedStates` 是一个位图，其中启用的位对应于 ProposalState 枚举中从右到左计数的位置。
     *
     * 注意：如果 `expectedState` 是 `bytes32(0)`，则表示提案不应处于任何状态（即不存在）。
     * 当一个预期为未设置的提案已经被启动时（即提案重复），就会出现这种情况。
     *
     * 参见 {Governor-_encodeStateBitmap}。
     */
    error GovernorUnexpectedProposalState(uint256 proposalId, ProposalState current, bytes32 expectedStates);

    /**
     * @dev 设置的投票期无效。
     */
    error GovernorInvalidVotingPeriod(uint256 votingPeriod);

    /**
     * @dev 提案者没有创建提案所需的足够票数。
     */
    error GovernorInsufficientProposerVotes(address proposer, uint256 votes, uint256 threshold);

    /**
     * @dev 提案者不被允许创建提案。
     */
    error GovernorRestrictedProposer(address proposer);

    /**
     * @dev 使用的投票类型对相应的计票模块无效。
     */
    error GovernorInvalidVoteType();

    /**
     * @dev 计票模块不支持所提供的参数缓冲区。
     */
    error GovernorInvalidVoteParams();

    /**
     * @dev 此治理合约未实现排队操作。应直接调用执行。
     */
    error GovernorQueueNotImplemented();

    /**
     * @dev 提案尚未进入队列。
     */
    error GovernorNotQueuedProposal(uint256 proposalId);

    /**
     * @dev 提案已在队列中。
     */
    error GovernorAlreadyQueuedProposal(uint256 proposalId);

    /**
     * @dev 所提供的签名对预期的 `voter` 无效。
     * 如果 `voter` 是一个合约，则该签名在使用 {IERC1271-isValidSignature} 时无效。
     */
    error GovernorInvalidSignature(address voter);

    /**
     * @dev 给定的 `account` 无法取消指定的 `proposalId`。
     */
    error GovernorUnableToCancel(uint256 proposalId, address account);

    /**
     * @dev 当提案被创建时触发。
     */
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

    /**
     * @dev 当提案进入队列时触发。
     */
    event ProposalQueued(uint256 proposalId, uint256 etaSeconds);

    /**
     * @dev 当提案被执行时触发。
     */
    event ProposalExecuted(uint256 proposalId);

    /**
     * @dev 当提案被取消时触发。
     */
    event ProposalCanceled(uint256 proposalId);

    /**
     * @dev 当一个不带参数的投票被投出时触发。
     *
     * 注意：`support` 值应被视为不同的类别。它们的解释取决于所使用的投票模块。
     */
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    /**
     * @dev 当一个带参数的投票被投出时触发。
     *
     * 注意：`support` 值应被视为不同的类别。它们的解释取决于所使用的投票模块。
     * `params` 是额外的编码参数。它们的解释也取决于所使用的投票模块。
     */
    event VoteCastWithParams(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason,
        bytes params
    );

    /**
     * @notice 模块:核心
     * @dev 治理实例的名称（用于构建 EIP-712 域分隔符）。
     */
    function name() external view returns (string memory);

    /**
     * @notice 模块:核心
     * @dev 治理实例的版本（用于构建 EIP-712 域分隔符）。默认值: "1"
     */
    function version() external view returns (string memory);

    /**
     * @notice 模块:投票
     * @dev 对可能的 `support` 值以及这些投票如何计数的描述，旨在供 UI 使用以显示正确的投票选项并解释结果。
     * 该字符串是一个 URL 编码的键值对序列，每个键值对描述一个方面，例如 `support=bravo&quorum=for,abstain`。
     *
     * 有两个标准键：`support` 和 `quorum`。
     *
     * - `support=bravo` 指的是投票选项 0 = 反对, 1 = 赞成, 2 = 弃权，如 `GovernorBravo` 中所示。
     * - `quorum=bravo` 意味着只有赞成票计入法定人数。
     * - `quorum=for,abstain` 意味着赞成票和弃权票都计入法定人数。
     *
     * 如果计票模块使用编码的 `params`，它应将其包含在 `params` 键下，并使用一个描述其行为的唯一名称。例如：
     *
     * - `params=fractional` 可能指一种方案，其中投票在赞成/反对/弃权之间按比例分配。
     * - `params=erc721` 可能指一种方案，其中特定的 NFT 被委托投票。
     *
     * 注意：该字符串可以由标准的
     * https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams[`URLSearchParams`]
     * JavaScript 类解码。
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() external view returns (string memory);

    /**
     * @notice 模块:核心
     * @dev 用于从提案详情中（重新）构建提案 ID 的哈希函数。
     *
     * 注意：对于所有链下和外部调用，请使用 {getProposalId}。
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    /**
     * @notice 模块:核心
     * @dev 用于从提案详情中获取提案 ID 的函数。
     */
    function getProposalId(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external view returns (uint256);

    /**
     * @notice 模块:核心
     * @dev 提案的当前状态，遵循 Compound 的约定。
     */
    function state(uint256 proposalId) external view returns (ProposalState);

    /**
     * @notice 模块:核心
     * @dev 选民成为提案者所需的票数。
     */
    function proposalThreshold() external view returns (uint256);

    /**
     * @notice 模块:核心
     * @dev 用于检索用户投票和法定人数的时间点。如果使用区块号（如 Compound 的 Comp），
     * 快照将在此区块结束时执行。因此，对此提案的投票在下一个区块开始时开始。
     */
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    /**
     * @notice 模块:核心
     * @dev 投票结束的时间点。如果使用区块号，投票将在此区块结束时结束，
     * 因此可以在此区块期间投票。
     */
    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    /**
     * @notice 模块:核心
     * @dev 创建提案的账户。
     */
    function proposalProposer(uint256 proposalId) external view returns (address);

    /**
     * @notice 模块:核心
     * @dev 一个已排队的提案变得可执行的时间（“ETA”）。与 {proposalSnapshot} 和
     * {proposalDeadline} 不同，这不使用治理合约的时钟，而是依赖于执行者（executor）的时钟，两者可能不同。
     * 在大多数情况下，这将是一个时间戳。
     */
    function proposalEta(uint256 proposalId) external view returns (uint256);

    /**
     * @notice 模块:核心
     * @dev 提案在执行前是否需要排队。
     */
    function proposalNeedsQueuing(uint256 proposalId) external view returns (bool);

    /**
     * @notice 模块:用户配置
     * @dev 从提案创建到投票开始之间的延迟。此持续时间的单位取决于此合约使用的时钟（参见 ERC-6372）。
     *
     * 可以增加此延迟，以便在提案投票开始前，用户有时间购买投票权或进行委托。
     *
     * 注意：虽然此接口返回 uint256，但时间点是按照 ERC-6372 时钟类型存储为 uint48。
     * 因此，此值必须能容纳在 uint48 中（当添加到当前时钟时）。参见 {IERC6372-clock}。
     */
    function votingDelay() external view returns (uint256);

    /**
     * @notice 模块:用户配置
     * @dev 从投票开始到投票结束之间的延迟。此持续时间的单位取决于此合约使用的时钟（参见 ERC-6372）。
     *
     * 注意：{votingDelay} 可以延迟投票的开始。在设置投票持续时间时，必须与投票延迟进行比较考虑。
     *
     * 注意：此值在提案提交时存储，因此对该值的可能更改不会影响已提交的提案。
     * 用于保存它的类型是 uint32。因此，虽然此接口返回 uint256，但它返回的值应能容纳在 uint32 中。
     */
    function votingPeriod() external view returns (uint256);

    /**
     * @notice 模块:用户配置
     * @dev 提案成功所需的最少投票数。法定人数
     *
     * 注意：`timepoint` 参数对应于用于计票的快照。这允许根据诸如
     * 此时间点代币的总供应量等值来调整法定人数（参见 {ERC20Votes}）。
     */
    function quorum(uint256 timepoint) external view returns (uint256);

    /**
     * @notice 模块:声誉
     * @dev 一个 `account` 在特定 `timepoint` 的投票权。
     *
     * 注意：这可以通过多种方式实现，例如从一个（或多个）{ERC20Votes} 代币中读取委托余额。
     */
    function getVotes(address account, uint256 timepoint) external view returns (uint256);

    /**
     * @notice 模块:声誉
     * @dev 在给定额外编码参数的情况下，一个 `account` 在特定 `timepoint` 的投票权。
     */
    function getVotesWithParams(
        address account,
        uint256 timepoint,
        bytes memory params
    ) external view returns (uint256);

    /**
     * @notice 模块:投票
     * @dev 返回 `account` 是否已对 `proposalId` 投票。
     */
    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    /**
     * @dev 创建一个新提案。投票在 {IGovernor-votingDelay} 指定的延迟后开始，并持续 {IGovernor-votingPeriod} 指定的时间。
     *
     * 触发一个 {ProposalCreated} 事件。
     *
     * 注意：Governor 和 `targets` 的状态在提案创建和执行之间可能会发生变化。
     * 这可能是由于第三方对目标合约的操作，或其他治理提案的结果。
     * 例如，此合约的余额可能会更新，或者其访问控制权限可能会被修改，
     * 这可能会影响提案成功执行的能力（例如，governor 没有足够的值来支付具有多个转账的提案）。
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    /**
     * @dev 将一个提案排入队列。一些治理合约要求在执行之前执行此步骤。如果不需要排队，
     * 此函数可能会 revert。将提案排入队列要求达到法定人数，投票成功，并且截止日期已到。
     *
     * 触发一个 {ProposalQueued} 事件。
     */
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256 proposalId);

    /**
     * @dev 执行一个成功的提案。这要求达到法定人数，投票成功，并且截止日期已到。
     * 根据治理合约的不同，可能还要求提案已排队并且经过了一定的延迟。
     *
     * 触发一个 {ProposalExecuted} 事件。
     *
     * 注意：某些模块可以修改执行要求，例如通过添加额外的时间锁。
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256 proposalId);

    /**
     * @dev 取消一个提案。提案可以由提案者取消，但只能在其处于 Pending 状态时，即投票开始之前。
     *
     * 触发一个 {ProposalCanceled} 事件。
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256 proposalId);

    /**
     * @dev 投出一票
     *
     * 触发一个 {VoteCast} 事件。
     */
    function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance);

    /**
     * @dev 带理由投出一票
     *
     * 触发一个 {VoteCast} 事件。
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256 balance);

    /**
     * @dev 带理由和额外编码参数投出一票
     *
     * 根据 params 的长度，触发一个 {VoteCast} 或 {VoteCastWithParams} 事件。
     */
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) external returns (uint256 balance);

    /**
     * @dev 使用投票者的签名来投票，包括对 ERC-1271 签名的支持。
     *
     * 触发一个 {VoteCast} 事件。
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        bytes memory signature
    ) external returns (uint256 balance);

    /**
     * @dev 使用投票者的签名，带理由和额外编码参数来投票，包括对 ERC-1271 签名的支持。
     *
     * 根据 params 的长度，触发一个 {VoteCast} 或 {VoteCastWithParams} 事件。
     */
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        string calldata reason,
        bytes memory params,
        bytes memory signature
    ) external returns (uint256 balance);
}
