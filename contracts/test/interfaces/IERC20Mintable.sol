// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/// @author Limitr
/// @title Mintable ERC20 interface
interface IERC20Mintable {
    /// @notice Mint is emitted when a tokens are minted
    /// @param owner The owner address
    /// @param amount The amount minted
    event Mint(address indexed owner, uint256 amount);

    /// @notice Mints tokens and emits a Mint()
    /// @param owner The owner address
    /// @param amount The amount to mint
    function mint(address owner, uint256 amount) external;
}
