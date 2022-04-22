// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/// @author Limitr
/// @title Burnable ERC20 interface
interface IERC20Burnable {

    /// @notice Burn is emitted when tokens are burned
    /// @param owner The owner address
    /// @param amount The amount burned
    event Burn(address indexed owner, uint256 amount);

    /// @notice Burns tokens and emits a Burn()
    /// @param owner The owner address
    /// @param amount The amount to burn
    function burn(address owner, uint256 amount) external;
}