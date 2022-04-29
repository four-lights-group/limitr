// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/// @author Limitr
/// @title ERC721 token receiver interface
/// @dev Interface for any contract that wants to support safeTransfers from ERC721 asset contracts.
interface IERC721Receiver {
    /// @notice Whenever an {IERC721} `tokenId` token is transferred to this contract
    ///      by `operator` from `from`, this function is called.
    ///      It must return its Solidity selector to confirm the token transfer.
    ///      If any other value is returned or the interface is not implemented
    ///      by the recipient, the transfer will be reverted.
    ///      The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
    /// @param operator The sender of the token
    /// @param from The owner of the token
    /// @param tokenId The token ID
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
