// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./IERC165.sol";

/// @author Limitr
/// @title ERC721 interface for the Limit vault
interface IERC721 is IERC165 {
    // events

    /// @notice Transfer is emitted when an order is transferred to a new owner
    /// @param from The order owner
    /// @param to The new order owner
    /// @param tokenId The token/order ID transferred
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /// @notice Approval is emitted when the owner approves approved to transfer tokenId
    /// @param owner The token/order owner
    /// @param approved The address approved to transfer the token/order
    /// @param tokenId the token/order ID
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /// @notice ApprovalForAll is emitted when the owner approves operator sets a new approval flag (true/false) for all tokens/orders
    /// @param owner The tokens/orders owner
    /// @param operator The operator address
    /// @param approved The approval status for all tokens/orders
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /// @param owner The tokens/orders owner
    /// @return balance The number of tokens/orders owned by owner
    function balanceOf(address owner) external view returns (uint256 balance);

    /// @notice Returns the owner of a token/order. The ID must be valid
    /// @param tokenId The token/order ID
    /// @return owner The owner of a token/order. The ID must be valid
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /// @notice Approves an account to transfer the token/order with the given ID.
    ///         The token/order must exists
    /// @param to The address of the account to approve
    /// @param tokenId the token/order
    function approve(address to, uint256 tokenId) external;

    /// @notice Returns the address approved to transfer the token/order with the given ID
    ///         The token/order must exists
    /// @param tokenId the token/order
    /// @return operator The address approved to transfer the token/order with the given ID
    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    /// @notice Approves or removes the operator for the caller tokens/orders
    /// @param operator The operator to be approved/removed
    /// @param _approved Set true to approve, false to remove
    function setApprovalForAll(address operator, bool _approved) external;

    /// @notice Returns if the operator is allowed to manage all tokens/orders of owner
    /// @param owner The owner of the tokens/orders
    /// @param operator The operator
    /// @return If the operator is allowed to manage all tokens/orders of owner
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    /// @notice Transfers the ownership of the token/order. Can be called by the owner
    ///         or approved operators
    /// @param from The token/order owner
    /// @param to The new owner
    /// @param tokenId The token/order ID to transfer
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /// @notice Safely transfers the token/order. It checks contract recipients are aware
    ///         of the ERC721 protocol to prevent tokens from being forever locked.
    /// @param from The token/order owner
    /// @param to the new owner
    /// @param tokenId The token/order ID to transfer
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /// @notice Safely transfers the token/order. It checks contract recipients are aware
    ///         of the ERC721 protocol to prevent tokens from being forever locked.
    /// @param from The token/order owner
    /// @param to the new owner
    /// @param tokenId The token/order ID to transfer
    /// @param data The data to be passed to the onERC721Received() call
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}
