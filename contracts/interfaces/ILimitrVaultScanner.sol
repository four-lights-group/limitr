// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/// @author Limitr
/// @title Interface for the vault scanner
interface ILimitrVaultScanner {
    /// @return The registry address
    function registry() external view returns (address);

    /// @return The n vaults starting at index idx that have available balance
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function scanAvailableBalances(
        uint256 idx,
        uint256 n,
        address trader
    ) external view returns (address[] memory);

    /// @return The vaults with available balance
    /// @param trader The trader to scan for
    function scanAvailableBalancesAll(address trader)
        external
        view
        returns (address[] memory);

    /// @return The n vaults starting at index idx that have open orders
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function scanOpenOrders(
        uint256 idx,
        uint256 n,
        address trader
    ) external view returns (address[] memory);

    /// @return The vaults with open orders
    /// @param trader The trader to scan for
    function scanOpenOrdersAll(address trader)
        external
        view
        returns (address[] memory);

    /// @return The n vaults starting at index idx that have open
    ///         orders or available balance
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function scanMemorable(
        uint256 idx,
        uint256 n,
        address trader
    ) external view returns (address[] memory);

    /// @return The vaults with open orders or available balance
    /// @param trader The trader to scan for
    function scanMemorableAll(address trader)
        external
        view
        returns (address[] memory);

    /// @return The vaults containing a particular token
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param token The token to scan for
    function scanForToken(
        uint256 idx,
        uint256 n,
        address token
    ) external view returns (address[] memory);

    /// @return The vaults with a particular token
    /// @param token The token to scan for
    function scanForTokenAll(address token)
        external
        view
        returns (address[] memory);
}
