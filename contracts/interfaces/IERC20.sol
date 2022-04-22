// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/// @author Limitr
/// @title ERC20 token interface
interface IERC20 {
    /// @notice Approval is emitted when a token approval occurs
    /// @param owner The address that approved an allowance
    /// @param spender The address of the approved spender
    /// @param value The amount approved
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /// @notice Transfer is emitted when a transfer occurs
    /// @param from The address that owned the tokens
    /// @param to The address of the new owner
    /// @param value The amount transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @return Token name
    function name() external view returns (string memory);

    /// @return Token symbol
    function symbol() external view returns (string memory);

    /// @return Token decimals
    function decimals() external view returns (uint8);

    /// @return Total token supply
    function totalSupply() external view returns (uint256);

    /// @param owner The address to query
    /// @return owner balance
    function balanceOf(address owner) external view returns (uint256);

    /// @param owner The owner ot the tokens
    /// @param spender The approved spender of the tokens
    /// @return Allowed balance for spender
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /// @notice Approves the provided amount to the provided spender address
    /// @param spender The spender address
    /// @param amount The amount to approve
    /// @return true on success
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers tokens to the provided address
    /// @param to The new owner address
    /// @param amount The amount to transfer
    /// @return true on success
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Transfers tokens from an approved address to the provided address
    /// @param from The tokens owner address
    /// @param to The new owner address
    /// @param amount The amount to transfer
    /// @return true on success
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
