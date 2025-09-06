// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.24;

import {ERC721} from "../ERC721.sol";
import {IERC721Enumerable} from "./IERC721Enumerable.sol";
import {IERC165} from "../../../utils/introspection/ERC165.sol";

/**
 * @dev 这实现了 ERC 中定义的 {ERC721} 的一个可选扩展，增加了合约中所有代币 ID 以及每个账户拥有的所有代币 ID 的可枚举性。
 * 警告：实现自定义 `balanceOf` 逻辑的 {ERC721} 扩展，例如 {ERC721Consecutive}，会干扰可枚举性，不应与 {ERC721Enumerable} 一起使用。
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // 额外记录index是为了实现O(1)的查找,避免循环

    mapping(address owner => mapping(uint256 index => uint256)) private _ownedTokens;
    // 每添加一个tokenId，_ownedTokensIndex[tokenId] = _ownedTokens中的index;
    // 方便根据tokenId对应的index找到_ownedTokens中的位置
    mapping(uint256 tokenId => uint256) private _ownedTokensIndex;

    uint256[] private _allTokens;
    // 每添加一个tokenId，_allTokensIndex[tokenId] = _allTokens.length - 1;
    // 对应的是在_allTokens数组中的位置
    mapping(uint256 tokenId => uint256) private _allTokensIndex;

    /**
     * @dev `owner` 的代币查询对于 `index` 超出范围。
     *
     * 注意：`owner` 为 `address(0)` 表示全局超出范围的索引。
     */
    error ERC721OutOfBoundsIndex(address owner, uint256 index);

    /**
     * @dev 不允许批量铸造。
     */
    error ERC721EnumerableForbiddenBatchMint();

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC721Enumerable
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256) {
        if (index >= balanceOf(owner)) {
            revert ERC721OutOfBoundsIndex(owner, index);
        }
        return _ownedTokens[owner][index];
    }

    /// @inheritdoc IERC721Enumerable
    function totalSupply() public view virtual returns (uint256) {
        return _allTokens.length;
    }

    /// @inheritdoc IERC721Enumerable
    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        if (index >= totalSupply()) {
            revert ERC721OutOfBoundsIndex(address(0), index);
        }
        return _allTokens[index];
    }

    /// @inheritdoc ERC721
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);

        if (previousOwner == address(0)) {  // 铸造
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (previousOwner != to) { // 转移 移除
            _removeTokenFromOwnerEnumeration(previousOwner, tokenId);
        }
        if (to == address(0)) { // 销毁
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (previousOwner != to) { // 转移 添加
            _addTokenToOwnerEnumeration(to, tokenId);
        }

        return previousOwner;
    }

    /**
     * @dev 给to添加tokenId(转移中的接受方)
     * @param to 表示给定代币 ID 的新所有者的地址
     * @param tokenId 要添加到给定地址的代币列表中的代币的 uint256 ID
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = balanceOf(to) - 1;
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev 生成新的token(铸造)时调用
     * @param tokenId 要添加到代币列表中的代币的 uint256 ID
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev 从from中删除tokenId(转移中的发送方)
     * 请注意，虽然代币未分配给新所有者，但 `_ownedTokensIndex` 映射 _未_ 更新：这允许
     * 进行 gas 优化，例如在执行转移操作时（避免双重写入）。
     * 这具有 O(1) 时间复杂度，但会改变 _ownedTokens 数组的顺序。
     * @param from 表示给定代币 ID 的前所有者的地址
     * @param tokenId 要从给定地址的代币列表中移除的代币的 uint256 ID
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // 为防止 from 的代币数组中出现间隙，我们将最后一个代币存储在要删除的代币的索引中，
        // 然后删除最后一个槽（交换并弹出）。

        uint256 lastTokenIndex = balanceOf(from);
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        mapping(uint256 index => uint256) storage _ownedTokensByOwner = _ownedTokens[from];

        // 当要删除的代币是最后一个代币时，交换操作是不必要的
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokensByOwner[lastTokenIndex];

            _ownedTokensByOwner[tokenIndex] = lastTokenId; // 将最后一个代币移动到要删除的代币的槽中
            _ownedTokensIndex[lastTokenId] = tokenIndex; // 更新移动的代币的索引
        }

        // 这也会删除数组最后一个位置的内容
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokensByOwner[lastTokenIndex];
    }

    /**
     * @dev 删除tokenId(销毁)时调用
     * 这具有 O(1) 时间复杂度，但会改变 _allTokens 数组的顺序。
     * @param tokenId 要从代币列表中移除的代币的 uint256 ID
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // 为防止代币数组中出现间隙，我们将最后一个代币存储在要删除的代币的索引中，
        // 然后删除最后一个槽（交换并弹出）。

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // 当要删除的代币是最后一个代币时，交换操作是不必要的。但是，由于这种情况
        // 很少发生（当最后铸造的代币被销毁时），我们仍然在这里进行交换以避免添加
        // 'if' 语句的 gas 成本（如在 _removeTokenFromOwnerEnumeration 中）
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // 将最后一个代币移动到要删除的代币的槽中
        _allTokensIndex[lastTokenId] = tokenIndex; // 更新移动的代币的索引

        // 这也会删除数组最后一个位置的内容
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }

    /**
     * 参见 {ERC721-_increaseBalance}。我们需要它来核算批量铸造的代币
     * （这会干扰可枚举性），因此我们覆盖它以阻止批量铸造。
     */
    function _increaseBalance(address account, uint128 amount) internal virtual override {
        if (amount > 0) {
            revert ERC721EnumerableForbiddenBatchMint();
        }
        super._increaseBalance(account, amount);
    }
}
