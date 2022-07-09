// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/// @author Limitr
/// @title Interface for the vault scanner
interface ILimitrVaultScanner {
    /// @return The registry address
    function registry() external view returns (address);

    /// @return The `n` vaults starting at index `idx` that have available balance
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function availableBalances(
        uint256 idx,
        uint256 n,
        address trader
    ) external view returns (address[] memory);

    /// @return The vaults with available balance
    /// @param trader The trader to scan for
    function availableBalancesAll(address trader)
        external
        view
        returns (address[] memory);

    /// @return The `n` vaults starting at index `idx` that have open orders
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function openOrders(
        uint256 idx,
        uint256 n,
        address trader
    ) external view returns (address[] memory);

    /// @return The vaults with open orders
    /// @param trader The trader to scan for
    function openOrdersAll(address trader)
        external
        view
        returns (address[] memory);

    /// @return The `n` vaults starting at index `idx` that have open
    ///         orders or available balance
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function memorable(
        uint256 idx,
        uint256 n,
        address trader
    ) external view returns (address[] memory);

    /// @return The vaults with open orders or available balance
    /// @param trader The trader to scan for
    function memorableAll(address trader)
        external
        view
        returns (address[] memory);

    /// @return The `n` vaults starting at index `idx` containing `_token`
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param _token The token to scan for
    function token(
        uint256 idx,
        uint256 n,
        address _token
    ) external view returns (address[] memory);

    /// @return The vaults with a particular token
    /// @param _token The token to scan for
    function tokenAll(address _token) external view returns (address[] memory);
}
