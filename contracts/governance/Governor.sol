// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/Governor.sol)

pragma solidity ^0.8.24;

import {IERC721Receiver} from "../token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "../token/ERC1155/IERC1155Receiver.sol";
import {EIP712} from "../utils/cryptography/EIP712.sol";
import {SignatureChecker} from "../utils/cryptography/SignatureChecker.sol";
import {IERC165, ERC165} from "../utils/introspection/ERC165.sol";
import {SafeCast} from "../utils/math/SafeCast.sol";
import {DoubleEndedQueue} from "../utils/structs/DoubleEndedQueue.sol";
import {Address} from "../utils/Address.sol";
import {Context} from "../utils/Context.sol";
import {Nonces} from "../utils/Nonces.sol";
import {Strings} from "../utils/Strings.sol";
import {IGovernor, IERC6372} from "./IGovernor.sol";

/**
 * @dev 治理系统的核心，旨在通过各种模块进行扩展。
 *
 * 此合约是抽象的，需要在各种模块中实现以下几个函数：
 *
 * - 计数模块必须实现 {_quorumReached}、{_voteSucceeded} 和 {_countVote}
 * - 投票模块必须实现 {_getVotes}
 * - 此外，还必须实现 {votingPeriod}、{votingDelay} 和 {quorum}
 */
/*
    execute 函数执行的“提案”，具体来说是一组预先定义好的、将在区块链上执行的智能合约调用。
    你可以把它理解为 DAO（去中心化自治组织）想要执行的一个或多个链上操作的“脚本”。
    当这个提案被投票通过并最终执行时，就相当于 DAO 授权并运行了这个脚本。

  一个提案的核心由三个部分组成，它们是三个并行的数组：
   1. `targets` (目标地址数组):
       * 是什么: 一个地址列表。
       * 作用: 定义了这笔提案将要与哪些智能合约或地址进行交互。列表中的每一个地址都是一个操作的目标。
   2. `values` (以太币数量数组):
       * 是什么: 一个数值列表。
       * 作用: 与 targets 数组一一对应，定义了在调用每个目标地址时，要附带发送多少以太币（ETH）。如果只是调用函数而不需要发送 
         ETH，那么对应的值就是 0。
   3. `calldatas` (调用数据数组):
       * 是什么: 一个字节码列表，这是最关键的部分。
       * 作用: 与 targets 数组一一对应，它包含了要对目标合约执行的具体操作。通常这是由函数签名和参数编码而成的。例如，abi.encodeWithSignature
         ("transfer(address,uint256)", 0x..., 100) 就是一个典型的 calldata。
*/
abstract contract Governor is Context, ERC165, EIP712, Nonces, IGovernor, IERC721Receiver, IERC1155Receiver {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,uint8 support,address voter,uint256 nonce)");
    bytes32 public constant EXTENDED_BALLOT_TYPEHASH =
        keccak256(
            "ExtendedBallot(uint256 proposalId,uint8 support,address voter,uint256 nonce,string reason,bytes params)"
        );

    // 提案的核心数据
    struct ProposalCore {
        address proposer;       // 提案者
        uint48 voteStart;       // 投票开始时间点
        uint32 voteDuration;    // 投票持续时间（以秒为单位）
        bool executed;          // 是否已执行
        bool canceled;          // 是否已取消
        uint48 etaSeconds;      // 提案排队的预期执行时间（如果适用） queue函数设置
    }

    // 所有可能的提案状态的位图表示
    bytes32 private constant ALL_PROPOSAL_STATES_BITMAP = bytes32((2 ** (uint8(type(ProposalState).max) + 1)) - 1);
    string private _name;

    // 提案 ID 到提案数据的映射
    mapping(uint256 proposalId => ProposalCore) private _proposals;

    // 此队列跟踪治理者自身的操作。受 {onlyGovernance} 修饰器保护的函数调用
    // 需要在此队列中列入白名单。白名单在 {execute} 中设置，由 {onlyGovernance}
    // 修饰器使用，并最终在 {_executeOperations} 完成后重置。这确保了
    // {onlyGovernance} 保护的调用只能通过成功的提案来实现。
    DoubleEndedQueue.Bytes32Deque private _governanceCall;

    /**
     * @dev 限制一个函数，使其只能通过治理提案执行。
     * 例如，{GovernorSettings} 中的治理参数设置器使用此修饰器进行保护。
     *
     * 治理执行地址可能与 Governor 自己的地址不同，例如它可能是一个时间锁。
     * 模块可以通过覆盖 {_executor} 来自定义此行为。执行者只能在 Governor 的 {execute} 函数执行期间调用这些函数，
     * 而不能在任何其他情况下调用。
     * 因此，例如，额外的时间锁提议者无法在不通过治理协议的情况下更改治理参数（自 v4.6 起）。
     */
    /*
        `_governanceCall` 是为所有被 `onlyGovernance` 修饰器保护的函数服务的，而 `relay` 只是其中最典型的一个。
        _governanceCall 是一个内部安全机制，你可以把它理解成一个临时的、一次性的“通行证”队列。
        
        它的核心目的是为了解决一个棘手的安全问题：当治理权和执行权分离时（即 Governor 的执行者 _executor() 是一个外部合约，
            如 TimelockController），如何确保 Governor 合约上那些强大的、只应由治理发起的函数（如 relay 或参数设置函数）不会被滥用？

        这个机制分为两步：
            1. 登记“通行证”（发生在 execute 函数中）
                当一个提案成功并通过 execute 函数执行时：
                    * execute 函数会检查这个提案里的所有操作。
                    * 如果其中某个操作的目标(target)是 Governor 合约自身 (address(this))，这意味着这个提案想要让 Governor 自己调用自己的某个函数。
                    * 这时，execute 函数会把这个操作的调用数据 (calldata) 进行哈希，并将这个哈希值存入 `_governanceCall` 队列。
                这个过程相当于 execute 函数在说：“我（作为提案的执行者）现在授权 Governor 合约在本次交易中，可以接收一个内容哈希为 X 的内部调用。”
            2. 检验并注销“通行证”（发生在 onlyGovernance 修饰器中）
                当那个被 onlyGovernance 保护的函数（比如 relay）真的被调用时：
                    * onlyGovernance 修饰器被触发，它会调用内部的 _checkGovernance 函数。
                    * _checkGovernance 会计算当前这个调用（即对 relay 的调用）的 calldata 哈希。
                    * 然后，它会去 _governanceCall 队列里查找并移除这个哈希值。
                    * 如果找到了：说明这次调用是经过 execute 授权的，是合法的。检查通过，函数继续执行。
                    * 如果没找到（队列是空的，或者里面没有匹配的哈希）：
                        说明这次调用并非源于一个合法的、正在执行的提案，而是有人想直接调用这个危险函数。检查失败，交易回退。
        执行完毕后，execute 函数还会清空 _governanceCall 队列，确保这些“通行证”不会被重用。

        结论
            _governanceCall 是 onlyGovernance 机制的底层支柱。它创建了一个安全的闭环：
                提案通过 `execute` 授权 -> `_governanceCall` 登记授权 -> `onlyGovernance` 检验授权
        relay 因为被 onlyGovernance 保护，所以依赖于这个机制。
        但任何其他同样被 onlyGovernance 保护的函数（例如，在 GovernorSettings 模块中修改投票周期的 setVotingPeriod 函数）也同样依赖于 _governanceCall 来确保它们只能通过合法的治理流程被调用。
    */
    modifier onlyGovernance() {
        _checkGovernance();
        _;
    }

    /**
     * @dev 设置 {name} 和 {version} 的值
     */
    constructor(string memory name_) EIP712(name_, version()) {
        _name = name_;
    }

    /**
     * @dev 用于接收将由治理者处理的 ETH 的函数（如果执行者是第三方合约，则禁用）
     */
    receive() external payable virtual {
        //  _executor() 函数被声明为 virtual，可能被另一只函数重载
        // 确保只有当 Governor 合约自身是执行者时，它才能直接接收 ETH。
        if (_executor() != address(this)) {
            revert GovernorDisabledDeposit();
        }
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(IGovernor).interfaceId ||
            // 这行代码的目的是让 Governor 合约能够同时声明它支持新旧两个版本的 IGovernor 接口。
            // 如果一个外部合约是基于新版 IGovernor 来检查接口支持，它会使用完整的 interfaceId，
            //      第一个条件 interfaceId == type(IGovernor).interfaceId 会满足。
            // 如果一个外部合约是基于旧版 IGovernor 来检查，它会使用不包含 getProposalId 的 interfaceId，
            //      这时第二个条件 interfaceId == type(IGovernor).interfaceId ^ IGovernor.getProposalId.selector 就会满足。
            interfaceId == type(IGovernor).interfaceId ^ IGovernor.getProposalId.selector ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IGovernor
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /// @inheritdoc IGovernor
    function version() public view virtual returns (string memory) {
        return "1";
    }

    /**
     * @dev 参见 {IGovernor-hashProposal}。
     *
     * 提案 ID 是通过对 ABI 编码的 `targets` 数组、`values` 数组、`calldatas` 数组
     * 和 descriptionHash（bytes32，其本身是描述字符串的 keccak256 哈希值）进行哈希运算得出的。此提案 ID
     * 可以从作为 {ProposalCreated} 事件一部分的提案数据中生成。它甚至可以在
     * 提案提交之前提前计算。
     *
     * 请注意，chainId 和治理者地址不参与提案 ID 的计算。因此，
     * 如果在多个网络上的多个治理者中提交相同的提案（具有相同的操作和相同的描述），
     * 则该提案将具有相同的 ID。这也意味着，为了在同一治理者上两次执行相同的操作，
     * 提议者将必须更改描述以避免提案 ID 冲突。
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }

    /// @inheritdoc IGovernor
    function getProposalId(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public view virtual returns (uint256) {
        return hashProposal(targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc IGovernor
    // 获取提案的当前状态
    function state(uint256 proposalId) public view virtual returns (ProposalState) {
        // 我们一次性将结构体字段读入堆栈，因此 Solidity 会发出单个 SLOAD, 为了节省 Gas
        ProposalCore storage proposal = _proposals[proposalId];
        bool proposalExecuted = proposal.executed;
        bool proposalCanceled = proposal.canceled;

        if (proposalExecuted) {
            return ProposalState.Executed;
        }

        if (proposalCanceled) {
            return ProposalState.Canceled;
        }

        // proposalSnapshot 函数没有使用那种优化方式，主要是因为它只访问了结构体中的一个字段，所以没有必要。
        // 获取开始时间
        uint256 snapshot = proposalSnapshot(proposalId);

        // 没有开始时间意味着提案不存在
        if (snapshot == 0) {
            revert GovernorNonexistentProposal(proposalId);
        }

        // 当前时间
        uint256 currentTimepoint = clock();

        // 投票尚未开始
        if (snapshot >= currentTimepoint) {
            return ProposalState.Pending;
        }

        // 获取截止时间
        uint256 deadline = proposalDeadline(proposalId);

        if (deadline >= currentTimepoint) { // 投票仍在进行中
            return ProposalState.Active;
        } else if (!_quorumReached(proposalId) || !_voteSucceeded(proposalId)) { // 投票已结束且未达成法定人数或未成功
            return ProposalState.Defeated;
        } else if (proposalEta(proposalId) == 0) { // 投票已结束且成功，但未排队
            return ProposalState.Succeeded;
        } else {                                    // 投票已结束且成功且已排队
            return ProposalState.Queued;
        }
    }

    /// @inheritdoc IGovernor
    /*
        它规定了一个账户必须拥有最低多少票数（Voting Power），才有资格提交一个新的治理提案。
        工作原理：
            1. 当你调用 propose 函数想要创建一个新的提案时，该函数会首先调用 proposalThreshold() 来获取这个门槛值。
            2. 然后，它会检查你（即提案者 proposer）当前的票数（通过 getVotes(proposer, ...) 获取）。
            3. 如果你的票数低于这个门槛值，那么交易就会失败，并提示 GovernorInsufficientProposerVotes 错误，你的提案也就无法被创建。
        它的主要目的是防止垃圾提案和恶意攻击。
    */
    function proposalThreshold() public view virtual returns (uint256) {
        return 0;
    }

    /// @inheritdoc IGovernor
    // 获取投票开始时间
    function proposalSnapshot(uint256 proposalId) public view virtual returns (uint256) {
        return _proposals[proposalId].voteStart;
    }

    /// @inheritdoc IGovernor
    // 获取投票截止时间
    function proposalDeadline(uint256 proposalId) public view virtual returns (uint256) {
        return _proposals[proposalId].voteStart + _proposals[proposalId].voteDuration;
    }

    /// @inheritdoc IGovernor
    // 获取提案的提议者
    function proposalProposer(uint256 proposalId) public view virtual returns (address) {
        return _proposals[proposalId].proposer;
    }

    /// @inheritdoc IGovernor
    // 获取提案的预期执行时间
    function proposalEta(uint256 proposalId) public view virtual returns (uint256) {
        return _proposals[proposalId].etaSeconds;
    }

    /// @inheritdoc IGovernor
    /*
        用来告诉外部（例如，用户界面或脚本）一个提案在投票成功后，是否需要经过一个“排队”步骤才能被执行。
        1. 治理流程: 
            在许多复杂的治理系统中，特别是那些与时间锁（Timelock）合约结合使用的系统中，一个提案并不会在投票通过后立即生效。
                它遵循一个更安全的流程：
                * 投票成功 (Succeeded): 提案获得足够的支持票。
                * 排队 (Queued): 调用 queue 函数，将提案放入时间锁的等待队列中，并开始一个预设的延迟倒计时。
                * 执行 (Executed): 在延迟时间结束后，调用 execute 函数，提案的最终代码才会被执行。
        2. 为什么需要排队？: 
                这个“排队+延迟”的机制是一个重要的安全措施。它给了社区成员一个最后的机会来反应。
                如果一个恶意提案意外通过，社区成员可以在延迟期间采取措施（例如，撤出资金）来避免损失。
        3. 函数的作用: proposalNeedsQueuing 函数就是用来表明当前治理合约是否采用了上述的“排队”机制。
            * 如果它返回 true：意味着这是一个带有时间锁的复杂治理流程，提案成功后必须先调用 queue。
            * 如果它返回 false：意味着这是一个简单的治理流程，提案成功后可以直接调用 execute，无需排队。
    */
    function proposalNeedsQueuing(uint256) public view virtual returns (bool) {
        return false;
    }

    /**
     * @dev 如果 `msg.sender` 不是执行者，则回退。
     * 如果执行者不是此合约本身，并且 `msg.data` 未作为 {execute} 操作的结果列入白名单，则函数回退。
     * 参见 {onlyGovernance}。
     */
    /*
        构建了一个分层的安全模型，既能处理简单的治理模式，也能应对更复杂的、与 Timelock 结合的安全模式。
        if (_executor() != _msgSender())
        * 它在检查什么？
            * _executor(): 返回治理系统指定的“执行者”地址。默认是 Governor 合约自己，但在高级用法中通常是 Timelock 合约的地址。
            * _msgSender(): 返回当前函数的直接调用者。
            * 所以，这行代码在检查：“调用我（被 `onlyGovernance` 保护的函数）的地址，是不是我们官方指定的那个执行者？”
        * 目的：基本的角色准入控制。
            这是第一道防线。它确保了只有被治理系统正式承认的“执行者”才有资格尝试调用这些敏感函数。任何无关的外部账户或合约调用都会在这里被直接拒绝。
            * 类比：这就像一个高级别会议室的门口保安。他只检查你的胸牌（_msgSender()）是否是“授权参会者”（_executor()）。如果不是，你连门都进不去。
    
        if (_executor() != address(this))
        * 它在检查什么？
            * 这行代码在检查：“我们的执行者是不是一个外部合约（而不是 `Governor` 合约自己）？”
            * 这个条件只在治理模式为 Governor + Timelock (或其他外部执行者) 时才为 true。如果 Governor 是自我执行的，这个 if 块会被跳过。
        * 目的：防止外部执行者滥用权力，增加一层额外的安全保障。
        这是第二道、也是更精妙的一道防线。仅仅验证了调用者是 Timelock 还不够，因为 Timelock 可能被其他拥有 PROPOSER_ROLE 的地址用来发起恶意操作。
        我们必须确保 Timelock 调用 Governor 的这个行为，是源自于一个刚刚被 Governor.execute() 执行的、合法的提案。
    */
    // 既保证了调用者的身份正确，又在必要时保证了调用行为的来源合法。
    function _checkGovernance() internal virtual {
        // 
        if (_executor() != _msgSender()) {
            revert GovernorOnlyExecutor(_msgSender());
        }
        if (_executor() != address(this)) {
            bytes32 msgDataHash = keccak256(_msgData());
            // 循环直到弹出预期的操作 - 如果双端队列为空（操作未授权），则抛出异常,popFront()函数会抛出异常
            while (_governanceCall.popFront() != msgDataHash) {}
        }
    }

    /**
     * @dev 已投的票数是否超过阈值限制。投票数是否达到法定人数。
     */
    function _quorumReached(uint256 proposalId) internal view virtual returns (bool);

    /**
     * @dev 提案是否成功。赞成票是否大于反对票。
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual returns (bool);

    /**
     * @dev 获取 `account` 在特定 `timepoint` 的投票权重，用于 `params` 所描述的投票。
     */
    function _getVotes(address account, uint256 timepoint, bytes memory params) internal view virtual returns (uint256);

    /**
     * @dev 为 `proposalId` 注册一票，投票人为 `account`，具有给定的 `support`、投票 `weight` 和投票 `params`。
     *
     * 注意：`support` 是通用的，可以根据所使用的投票系统代表各种事物。
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 totalWeight,
        bytes memory params
    ) internal virtual returns (uint256);

    /**
     * @dev 每当提案的计票更新时应调用的钩子。
     *
     * 注意：此函数必须成功运行。回退将导致治理功能瘫痪。
     */
    function _tallyUpdated(uint256 proposalId) internal virtual {}

    /**
     * @dev `castVote` 方法使用的默认附加编码参数（不包括它们）
     *
     * 注意：应由具体实现重写以使用适当的值，附加参数的含义在该实现的上下文中定义。
     */
    /*
        函数的作用是为投票函数提供一个默认的、空的“附加参数”。这主要是为了保持系统的可扩展性。
        详细解释：
            1. 为高级功能预留空间: OpenZeppelin 的 Governor 被设计成一个高度模块化的框架。
                开发者可以替换其中的投票模块以实现各种复杂的投票逻辑。
                某些高级的投票机制在计算票数（_getVotes）或记录投票（_countVote）时，可能需要一些额外的参数。
                * 例如：想象一个复杂的投票系统，允许用户在投票时选择不同的“权重模式”或“锁定时间”来增加票数。
                    这些额外的信息就可以被编码到 bytes memory params 这个参数中，并传递给底层的投票模块。
            2. 提供简化的函数接口:
                * Governor 合约同时提供了带附加参数的复杂函数，如 castVoteWithReasonAndParams。
                * 也提供了不带附加参数的简化函数，如 castVote。
            3. `_defaultParams()` 的角色:
                当你调用一个简化版的投票函数时（比如 castVote），它在内部需要调用一个更底层的、需要 params 参数的函数。
                    这时，_defaultParams() 就派上用场了，它会返回一个空的 bytes 数组 ("") 作为这个 params 参数的默认值。
        _defaultParams() 函数是一个“占位符”。它使得 Governor 合约可以在支持复杂、可扩展投票机制的同时，
            也为最常见的、不需要任何附加参数的简单投票场景提供一个简洁的接口。在基础的 Governor 合约中，
            它只是返回一个空值，但在需要它的子模块中，它可以被重写以提供有意义的默认参数。
    */
    function _defaultParams() internal view virtual returns (bytes memory) {
        return "";
    }

    /**
     * @dev 参见 {IGovernor-propose}。此函数具有选择性加入的前置运行保护，在 {_isValidDescriptionForProposer} 中描述。
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (uint256) {
        address proposer = _msgSender();

        // 检查描述限制 是否是合法的提案者
        if (!_isValidDescriptionForProposer(proposer, description)) {
            revert GovernorRestrictedProposer(proposer);
        }

        // 检查提案阈值 
        // 一个账户必须拥有最低多少票数（Voting Power），才有资格提交一个新的治理提案。
        uint256 votesThreshold = proposalThreshold();
        if (votesThreshold > 0) {
            // 获取提案者的票数
            // `-1` 的关键作用:
            //      * 如果在 propose 函数中直接使用 getVotes(proposer, clock())，即 getVotes(proposer, N)，这将查询在区块 N 结束时的票数。
            //          这会带来一个巨大的安全漏洞：攻击者可以在同一个区块 N 内，先用闪电贷借来大量治理代币，然后调用 propose 发起提案，
            //          最后再把代币还掉。这样他就能零成本地满足 proposalThreshold（提案门槛）。
            //      * 通过使用 clock() - 1，代码查询的是 getVotes(proposer, N - 1)，即提案者在上一个区块结束时所拥有的票数。
            uint256 proposerVotes = getVotes(proposer, clock() - 1);
            // 票数不够不能发起提案
            if (proposerVotes < votesThreshold) {
                revert GovernorInsufficientProposerVotes(proposer, proposerVotes, votesThreshold);
            }
        }

        return _propose(targets, values, calldatas, description, proposer);
    }

    /**
     * @dev 内部提案机制。可以被重写以在提案创建时添加更多逻辑。
     *
     * 触发一个 {IGovernor-ProposalCreated} 事件。
     */
    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal virtual returns (uint256 proposalId) {
        // 生成提案id
        proposalId = getProposalId(targets, values, calldatas, keccak256(bytes(description)));

        if (targets.length != values.length || targets.length != calldatas.length || targets.length == 0) {
            revert GovernorInvalidProposalLength(targets.length, calldatas.length, values.length);
        }
        // 提案已存在
        if (_proposals[proposalId].voteStart != 0) {
            revert GovernorUnexpectedProposalState(proposalId, state(proposalId), bytes32(0));
        }

        // 投票的开始时间
        uint256 snapshot = clock() + votingDelay();
        // 投票的持续时间
        uint256 duration = votingPeriod();

        ProposalCore storage proposal = _proposals[proposalId];
        proposal.proposer = proposer;
        proposal.voteStart = SafeCast.toUint48(snapshot);
        proposal.voteDuration = SafeCast.toUint32(duration);

        emit ProposalCreated(
            proposalId,
            proposer,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            snapshot,
            snapshot + duration,
            description
        );

        // 使用命名返回变量以避免堆栈过深错误
    }

    /// @inheritdoc IGovernor
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256) {
        // 获取提案id
        uint256 proposalId = getProposalId(targets, values, calldatas, descriptionHash);

        // 验证提案是否已成功
        _validateStateBitmap(proposalId, _encodeStateBitmap(ProposalState.Succeeded));

        // 获取etaSeconds时间
        uint48 etaSeconds = _queueOperations(proposalId, targets, values, calldatas, descriptionHash);

        if (etaSeconds != 0) {
            _proposals[proposalId].etaSeconds = etaSeconds;
            emit ProposalQueued(proposalId, etaSeconds);
        } else {
            revert GovernorQueueNotImplemented(); // 排队失败
        }

        return proposalId;
    }

    /**
     * @dev 内部排队机制。可以被重写（无需调用 super）以修改排队 的执行方式（例如添加保险库/时间锁）。
     *
     * 默认情况下为空，必须被重写以实现排队。
     *
     * 此函数返回一个时间戳，描述预期的执行 ETA。如果返回值为 0（默认值），则核心将认为排队未成功，公共 {queue} 函数将回退。
     *
     * 注意：直接调用此函数不会检查提案的当前状态，或触发`ProposalQueued` 事件。应使用 {queue} 对提案进行排队。
     */
    function _queueOperations(
        uint256 /*proposalId*/,
        address[] memory /*targets*/,
        uint256[] memory /*values*/,
        bytes[] memory /*calldatas*/,
        bytes32 /*descriptionHash*/
    ) internal virtual returns (uint48) {
        return 0;
    }

    /// @inheritdoc IGovernor
    /*
        execute 是一个治理提案生命周期的最后一步。
            * 场景: 当一个提案（例如，“将 100 DAI 转给项目方”）经过投票并成功后，任何人都可以调用 execute 函数来触发这个提案的最终执行。
            * 工作方式:
                1. 它接收提案的完整描述（targets, values, calldatas, descriptionHash）。
                2. 它验证提案的状态是否为 Succeeded (成功) 或 Queued (已排队)。
                3. 它将提案标记为 executed，防止重入攻击。
                4. 它调用内部的 _executeOperations 函数，该函数会遍历 targets 数组，并依次执行每个目标合约的调用。
    */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual returns (uint256) {
        uint256 proposalId = getProposalId(targets, values, calldatas, descriptionHash);

        // 验证提案是否已成功或已排队, 非Succeeded,Queued会revert
        _validateStateBitmap(
            proposalId,
            _encodeStateBitmap(ProposalState.Succeeded) | _encodeStateBitmap(ProposalState.Queued)
        );

        // 在调用前标记为已执行以避免重入
        _proposals[proposalId].executed = true;

        // 执行前：在队列中注册治理调用。 执行者不是此合约本身时才需要这样做。
        if (_executor() != address(this)) {
            for (uint256 i = 0; i < targets.length; ++i) {
                // 仅当目标是治理合约本身时才注册调用
                if (targets[i] == address(this)) {
                    _governanceCall.pushBack(keccak256(calldatas[i]));
                }
            }
        }

        // 执行提案操作
        _executeOperations(proposalId, targets, values, calldatas, descriptionHash);

        // 执行后：清理治理调用队列。
        if (_executor() != address(this) && !_governanceCall.empty()) {
            _governanceCall.clear();
        }

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    /**
     * @dev 内部执行机制。可以被重写（无需调用 super）以修改执行
     * 的方式（例如添加保险库/时间锁）。
     *
     * 注意：直接调用此函数不会检查提案的当前状态，将执行标志设置
     * 为 true 或触发 `ProposalExecuted` 事件。执行提案应使用 {execute}。
     */
    function _executeOperations(
        uint256 /* proposalId */,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal virtual {
        for (uint256 i = 0; i < targets.length; ++i) {
            (bool success, bytes memory returndata) = targets[i].call{value: values[i]}(calldatas[i]);
            Address.verifyCallResult(success, returndata);
        }
    }

    /// @inheritdoc IGovernor
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256) {
        // 提案 ID 将在下面的 `_cancel` 调用中重新计算。但是，我们需要在
        // 进行内部调用之前获取该值，因为我们需要在内部 `_cancel` 调用
        // 更改提案状态之前检查它。`getProposalId` 的重复计算成本有限，我们可以接受。
        uint256 proposalId = getProposalId(targets, values, calldatas, descriptionHash);

        // 条件校验, 只能是pedding状态才能取消
        address caller = _msgSender();
        if (!_validateCancel(proposalId, caller)) revert GovernorUnableToCancel(proposalId, caller);

        return _cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev 具有最少限制的内部取消机制。提案可以在除
     * Canceled、Expired 或 Executed 之外的任何状态下被取消。一旦取消，提案就不能重新提交。
     *
     * 触发一个 {IGovernor-ProposalCanceled} 事件。
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual returns (uint256) {
        uint256 proposalId = getProposalId(targets, values, calldatas, descriptionHash);

        // 只能在非 Canceled、Expired 或 Executed 状态下才能取消
        _validateStateBitmap(
            proposalId,
            ALL_PROPOSAL_STATES_BITMAP ^
                _encodeStateBitmap(ProposalState.Canceled) ^
                _encodeStateBitmap(ProposalState.Expired) ^
                _encodeStateBitmap(ProposalState.Executed)
        );

        _proposals[proposalId].canceled = true;
        emit ProposalCanceled(proposalId);

        return proposalId;
    }

    /// @inheritdoc IGovernor
    // 获取 `account` 在特定 `timepoint` 的投票权重，用于默认的投票参数。
    function getVotes(address account, uint256 timepoint) public view virtual returns (uint256) {
        return _getVotes(account, timepoint, _defaultParams());
    }

    /// @inheritdoc IGovernor
    // 获取 `account` 在特定 `timepoint` 的投票权重，用于 `params` 所描述的投票。
    function getVotesWithParams(
        address account,
        uint256 timepoint,
        bytes memory params
    ) public view virtual returns (uint256) {
        return _getVotes(account, timepoint, params);
    }

    /// @inheritdoc IGovernor
    function castVote(uint256 proposalId, uint8 support) public virtual returns (uint256) {
        address voter = _msgSender();
        return _castVote(proposalId, voter, support, "");
    }

    /// @inheritdoc IGovernor
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public virtual returns (uint256) {
        address voter = _msgSender();
        return _castVote(proposalId, voter, support, reason);
    }

    /// @inheritdoc IGovernor
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) public virtual returns (uint256) {
        address voter = _msgSender();
        return _castVote(proposalId, voter, support, reason, params);
    }

    /// @inheritdoc IGovernor
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        bytes memory signature
    ) public virtual returns (uint256) {
        if (!_validateVoteSig(proposalId, support, voter, signature)) {
            revert GovernorInvalidSignature(voter);
        }
        return _castVote(proposalId, voter, support, "");
    }

    /// @inheritdoc IGovernor
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        string calldata reason,
        bytes memory params,
        bytes memory signature
    ) public virtual returns (uint256) {
        if (!_validateExtendedVoteSig(proposalId, support, voter, reason, params, signature)) {
            revert GovernorInvalidSignature(voter);
        }
        return _castVote(proposalId, voter, support, reason, params);
    }

    /// @dev 验证 {castVoteBySig} 函数中使用的 `signature`。
    function _validateVoteSig(
        uint256 proposalId,
        uint8 support,
        address voter,
        bytes memory signature
    ) internal virtual returns (bool) {
        return
            SignatureChecker.isValidSignatureNow(
                voter,
                _hashTypedDataV4(keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support, voter, _useNonce(voter)))),
                signature
            );
    }

    /// @dev 验证 {castVoteWithReasonAndParamsBySig} 函数中使用的 `signature`。
    function _validateExtendedVoteSig(
        uint256 proposalId,
        uint8 support,
        address voter,
        string memory reason,
        bytes memory params,
        bytes memory signature
    ) internal virtual returns (bool) {
        return
            SignatureChecker.isValidSignatureNow(
                voter,
                _hashTypedDataV4(
                    keccak256(
                        abi.encode(
                            EXTENDED_BALLOT_TYPEHASH,
                            proposalId,
                            support,
                            voter,
                            _useNonce(voter),
                            keccak256(bytes(reason)),
                            keccak256(params)
                        )
                    )
                ),
                signature
            );
    }

    /**
     * @dev 内部投票机制：检查投票是否处于待定状态，是否尚未投票，
     * 使用 {IGovernor-getVotes} 检索投票权重并调用 {_countVote} 内部函数。使用 _defaultParams()。
     *
     * 触发一个 {IGovernor-VoteCast} 事件。
     */
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason
    ) internal virtual returns (uint256) {
        return _castVote(proposalId, account, support, reason, _defaultParams());
    }

    /**
     * @dev 内部投票机制：检查投票是否处于待定状态，是否尚未投票，
     * 使用 {IGovernor-getVotes} 检索投票权重并调用 {_countVote} 内部函数。
     *
     * 触发一个 {IGovernor-VoteCast} 事件。
     */
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual returns (uint256) {
        // 验证提案是否处于活动状态
        _validateStateBitmap(proposalId, _encodeStateBitmap(ProposalState.Active));

        uint256 totalWeight = _getVotes(account, proposalSnapshot(proposalId), params);
        uint256 votedWeight = _countVote(proposalId, account, support, totalWeight, params);

        if (params.length == 0) {
            emit VoteCast(account, proposalId, support, votedWeight, reason);
        } else {
            emit VoteCastWithParams(account, proposalId, support, votedWeight, reason, params);
        }

        // 投票
        _tallyUpdated(proposalId);

        return votedWeight;
    }

    /**
     * @dev 将交易或函数调用中继到任意目标。在治理执行者是除治理者本身之外的某个合约（例如使用时间锁）的情况下，
     * 可以在治理提案中调用此函数以恢复错误发送到治理者合约的代币或以太币。
     * 请注意，如果执行者只是治理者本身，则使用 `relay` 是多余的。
     */
    /*
        `execute`: 是执行提案内容的入口。它负责运行一个已经投票通过的提案中定义的一系列操作（targets, values, calldatas）。这是治理流程的终点。
        `relay`: 是一个通用目的的转发工具。它本身不代表任何特定的提案，而是让 Governor 合约拥有以自身名义执行任意单个调用的能力。
            它通常不直接用于执行常规提案，而是作为一个特殊的工具函数。

        relay 是一个更底层的、受严格保护的工具，它的设计初衷是为了解决一些特殊问题，特别是当治理权和执行权分离时。
            场景: 想象一下治理结构是 Governor (投票) + TimelockController (执行)。
                在这种结构下，_executor() 会被重写为 Timelock 的地址。这意味着 Governor 合约本身放弃了直接执行提案的权力。
                但如果有人误将资产（如 ETH 或 ERC20 代币）发送到了 Governor 合约地址而不是 Timelock 地址，
                这些资产就会被卡住，因为 Governor 没有内置的 transfer 函数来移出这些资产。
            relay 就是为了解决这类问题而生的。社区可以发起一个提案，这个提案的目标(`target`)是 `Governor` 合约自己，
                调用数据(`calldata`)是 `relay` 函数的调用，relay 的参数则指定了如何将卡住的资产转出。
        简单来说，`relay` 是“让 Governor 合约自己给自己下命令，去执行一个指定操作”的后门，但这个后门钥匙由治理本身掌管。
        
        为什么 relay 会限制 onlyGovernance？
            这是最关键的安全设计。
            1. `onlyGovernance` 的含义:
                通过阅读源码，我们可以看到 onlyGovernance 修饰器最终会检查 msg.sender 是否等于 _executor()。
                    在默认情况下，_executor() 返回 address(this)，也就是 Governor 合约自身的地址。
                所以，onlyGovernance 意味着只有 `Governor` 合约自己才能调用这个函数。
            2. 限制的必要性:
                relay 函数非常强大，它可以让 Governor 合约执行任意调用。
                    如果任何人都可以调用 relay，那就意味着任何人都可以命令 Governor 合约做任何事（比如把合约里所有的钱转走），
                    完全绕过了投票和治理过程。这会造成灾难性的安全漏洞。
            3. 正确的使用流程:
                onlyGovernance 确保了 relay 只能作为一个成功的治理提案的结果被调用。流程如下：
                    a. 创建一个提案，其 targets 数组中包含 Governor 合约的地址，calldatas 数组中包含对 relay(...) 函数的编码调用。
                    b. 该提案经过社区投票并成功。
                    c. 任何人调用 execute 来执行这个提案。
                    d. Governor 的 execute 函数开始执行提案内容，它发现目标是自己，数据是调用 relay。于是 Governor 合约调用了自身的 `relay` 函数。
                    e. 此时，在 relay 函数的执行上下文中，msg.sender 正是 Governor 合约的地址，因此 onlyGovernance 检查通过，relay 得以安全执行。
        通过这种方式，relay 的强大能力被锁定在治理框架之内，确保了它只能在社区达成共识后才能被使用。        
    */
    function relay(address target, uint256 value, bytes calldata data) external payable virtual onlyGovernance {
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        Address.verifyCallResult(success, returndata);
    }

    /**
     * @dev 治理者执行操作的地址。
     * 将被执行操作的模块通过另一个合约（例如时间锁）重载。
     * 它的主要作用是定义“谁”拥有最终执行一个已通过提案的权力。
     *      这个函数回答了这样一个问题：“当一个提案投票通过后，应该由哪个地址来执行它的具体操作？”
     * 为什么需要这个函数？——实现权力的分离
     *      它的存在是为了实现治理中一个重要的安全原则：投票权与执行权的分离。
     * 默认情况下，Governor 合约自己就是执行者。
     *      一个提案投票通过后，由 Governor 合约自己来执行提案中的操作（例如，转账、调用其他合约函数等）。这是最简单直接的模式。
     * 这个函数最重要的特性是 virtual，意味着它可以在子合约中被重写（override）。
     * 在实际应用中，最常见、最安全的做法是将执行权委托给一个时间锁（Timelock）合约。这会形成一个更安全的治理结构：
     *      投票合约 (`Governor`): 只负责投票记票的逻辑。
     *      执行合约 (`Timelock`): 负责在一段强制的延迟后，执行提案的具体操作。
     *   在这种模式下，开发者会创建一个继承自 Governor 和 GovernorTimelockControl 的新合约。
     *      GovernorTimelockControl 模块会重写 _executor() 函数，使其返回 Timelock 合约的地址。
     * 
     * 引入 Timelock 后的工作流程
     *      当 _executor() 返回的是 Timelock 地址时，整个治理流程变得更加安全：
     *          1. 投票通过: Governor 合约中的一个提案投票通过。
     *          2. 排队: Governor 并不会自己去执行提案，它唯一能做的就是调用 Timelock 合约的 schedule 函数，将提案的操作指令“排队”到时间锁中。
     *          3. 强制延迟: Timelock 合约会强制执行一个时间延迟（例如，2天）。在这段时间里，提案的操作是可见但不可执行的。
     *              这个延迟期至关重要，它给了社区成员一个“反悔期”或“逃生窗口”，如果他们不同意某个即将发生的更改，可以在此期间采取行动（比如撤出资金）。
     *          4. 最终执行: 延迟期过后，任何人都可以调用 Timelock 合约的 execute 函数，来最终触发提案中定义的操作。
     * 
     *  _executor() 函数就像一个权力开关。它通过定义谁是执行者，
     *      让 Governor 框架可以灵活地在“简单模式”（自己执行）和“安全模式”（委托给 Timelock 执行）之间切换。
     *          它的存在，是实现投票和执行相分离这一高级安全模式的基石，是 OpenZeppelin 治理方案设计的精髓所在。
     */
    function _executor() internal view virtual returns (address) {
        return address(this);
    }

    /**
     * @dev 参见 {IERC721Receiver-onERC721Received}。
     * 如果治理执行者不是治理者本身（例如与时间锁一起使用时），则禁用接收代币。
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        if (_executor() != address(this)) {
            revert GovernorDisabledDeposit();
        }
        return this.onERC721Received.selector;
    }

    /**
     * @dev 参见 {IERC1155Receiver-onERC1155Received}。
     * 如果治理执行者不是治理者本身（例如与时间锁一起使用时），则禁用接收代币。
     */
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        if (_executor() != address(this)) {
            revert GovernorDisabledDeposit();
        }
        return this.onERC1155Received.selector;
    }

    /**
     * @dev 参见 {IERC1155Receiver-onERC1155BatchReceived}。
     * 如果治理执行者不是治理者本身（例如与时间锁一起使用时），则禁用接收代币。
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        if (_executor() != address(this)) {
            revert GovernorDisabledDeposit();
        }
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev 将 `ProposalState` 编码为 `bytes32` 表示，其中每个启用的位对应于
     * `ProposalState` 枚举中的基础位置。例如：
     *
     * 0x000...10000
     *   ^^^^^^------ ...
     *         ^----- Succeeded
     *          ^---- Defeated
     *           ^--- Canceled
     *            ^-- Active
     *             ^- Pending
     */
    function _encodeStateBitmap(ProposalState proposalState) internal pure returns (bytes32) {
        return bytes32(1 << uint8(proposalState));
    }

    /**
     * @dev 检查提案的当前状态是否符合 `allowedStates` 位图描述的要求。
     * 此位图应使用 `_encodeStateBitmap` 构建。
     *
     * 如果不满足要求，则会因 {GovernorUnexpectedProposalState} 错误而回退。
     */
    function _validateStateBitmap(uint256 proposalId, bytes32 allowedStates) internal view returns (ProposalState) {
        // 获取提案状态
        ProposalState currentState = state(proposalId);
        if (_encodeStateBitmap(currentState) & allowedStates == bytes32(0)) {
            revert GovernorUnexpectedProposalState(proposalId, currentState, allowedStates);
        }
        return currentState;
    }

    /*
     * @dev 检查提议者是否有权提交具有给定描述的提案。
     *
     * 如果提案描述以 `#proposer=0x???` 结尾，其中 `0x???` 是以十六进制字符串
     * （不区分大小写）写入的地址，则此提案的提交将仅授权给该地址。
     *
     * 这用于抢先交易保护。通过在提案末尾添加此模式，可以确保
     * 没有其他地址可以提交相同的提案。攻击者将不得不删除或更改该部分，
     * 这将导致不同的提案 ID。
     *
     * 如果描述与此模式不匹配，则不受限制，任何人都可以提交。这包括：
     * - 如果 `0x???` 部分不是有效的十六进制字符串。
     * - 如果 `0x???` 部分是有效的十六进制字符串，但不完全包含 40 个十六进制数字。
     * - 如果它以预期的后缀结尾，后跟换行符或其他空格。
     * - 如果它以其他一些类似的后缀结尾，例如 `#other=abc`。
     * - 如果它不以任何此类后缀结尾。
     */
    /*
        这个函数特殊处理 #proposer= 是为了实现一种防抢跑（Front-running）攻击的保护机制。
        问题背景：什么是提案抢跑？
            1. 交易可见性: 在以太坊这样的公共区块链上，所有待处理的交易都会在“内存池（Mempool）”中公开，等待矿工打包。
            2. 攻击场景:
                * 假设一个社区成员 Alice 精心准备了一个重要的治理提案，并提交了创建该提案的交易。
                * 一个恶意攻击者 Bob 在内存池中看到了 Alice 的这笔交易。
                * Bob 可以完全复制 Alice 提案的所有内容（包括提案描述），然后用自己的地址，以更高的 Gas 费用提交一个一模一样的交易。
                * 由于 Gas 费更高，Bob 的交易很可能会被矿工优先打包，从而成功“窃取”了这个提案的发起人身份。Alice 的原始交易则会因为提案已存在而失败。
        解决方案：#proposer= 后缀
            为了解决这个问题，OpenZeppelin 引入了一个巧妙的约定：允许提案的发起者在提案描述的末尾附加一个特殊的后缀，将提案与自己的地址绑定。
            _isValidDescriptionForProposer 函数就是用来检查和执行这个约定的。
            函数工作原理:
                1. 检查后缀: 函数会检查提案描述 description 是否以 #proposer=<一个地址> 的格式结尾。
                2. 无后缀: 如果描述没有这个后缀，函数直接返回 true，意味着这是一个公开提案，任何人都可以提交。
                3. 有后缀: 如果描述有这个后缀，函数会：
                    * 解析出后缀中的地址（例如，0xALICE_ADDRESS）。
                    * 将这个解析出的地址与当前提交交易的地址（proposer，即 msg.sender）进行比较。
                    * 只有当两者完全相同时，函数才返回 true，允许提案被创建。
        如何防止抢跑？
            * Alice 在提交提案时，她的提案描述是："一个伟大的提案 #proposer=0xALICE_ADDRESS"。
            * 攻击者 Bob 在内存池看到了这个交易，并试图抢跑。
            * 如果 Bob 提交完全相同的提案：描述中依然是 Alice 的地址。当 Bob 的交易执行时，_isValidDescriptionForProposer 
                函数会发现提案描述要求发起者是 Alice，但实际发起者是 Bob，于是检查失败，Bob 的交易被回退（revert）。
            * 如果 Bob 修改提案描述：Bob 必须修改描述（例如，改成自己的地址或删除后缀）才能通过检查。但提案的 ID 
                是根据其所有内容（包括描述）哈希计算得出的。一旦 Bob 修改了描述，他创建的就不再是 Alice 的那个提案了，而是一个拥有全新 ID 
                的、不同的提案。他也就无法“窃取”Alice 的提案了。
    */
    function _isValidDescriptionForProposer(
        address proposer,
        string memory description
    ) internal view virtual returns (bool) {
        unchecked {
            uint256 length = bytes(description).length;

            // 长度太短，无法包含有效的提议者后缀
            if (length < 52) {
                return true;
            }

            // 提取将作为后缀开头的 `#proposer=` 标记
            bytes10 marker = bytes10(_unsafeReadBytesOffset(bytes(description), length - 52));

            // 如果未找到标记，则没有要检查的提议者后缀
            if (marker != bytes10("#proposer=")) {
                return true;
            }

            // 检查最后 42 个字符（在标记之后）是否是格式正确的地址。 42个字符是因为地址格式为 0x + 40个十六进制字符
            (bool success, address recovered) = Strings.tryParseAddress(description, length - 42, length);
            return !success || recovered == proposer;
        }
    }

    /**
     * @dev 检查 `caller` 是否可以取消具有给定 `proposalId` 的提案。
     *
     * 默认实现允许提案提议者在待定状态期间取消提案。
     */
    function _validateCancel(uint256 proposalId, address caller) internal view virtual returns (bool) {
        return (state(proposalId) == ProposalState.Pending) && caller == proposalProposer(proposalId);
    }

    /// @inheritdoc IERC6372
    function clock() public view virtual returns (uint48);

    /// @inheritdoc IERC6372
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory);

    /// @inheritdoc IGovernor
    function votingDelay() public view virtual returns (uint256);

    /// @inheritdoc IGovernor
    function votingPeriod() public view virtual returns (uint256);

    /// @inheritdoc IGovernor
    function quorum(uint256 timepoint) public view virtual returns (uint256);

    /**
     * @dev 从字节数组中读取一个 bytes32，不进行边界检查。
     *
     * 注意：将此函数设为 internal 意味着它可以与内存不安全的偏移量一起使用，并且将
     * 程序集块标记为此类将阻止某些优化。
     */
    function _unsafeReadBytesOffset(bytes memory buffer, uint256 offset) private pure returns (bytes32 value) {
        // 在一般情况下，这不是内存安全的，但对此私有函数的所有调用都在边界内。
        assembly ("memory-safe") {
            /*
                在 Solidity 中，一个动态的内存数组（如 bytes 或 string）在内存中有特定的结构：
                    * 变量本身（这里是 buffer）是一个指向内存地址的指针。
                    * 这个指针指向的位置，存储的是数组的长度（一个 32 字节的值）。
                    * 数组的实际内容存储在长度之后的内存区域，也就是从 指针地址 + 0x20 (32字节) 的位置开始。
                add(buffer, 0x20) 计算出数组内容的起始位置。
                add(add(buffer, 0x20), offset) 计算出我们想要读取的具体位置。
                mload(...) 加载（读取）一个完整的 32 字节（256位）的数据。
            */
            value := mload(add(add(buffer, 0x20), offset))
        }
    }
}
