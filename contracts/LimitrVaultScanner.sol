// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./interfaces/ILimitrVaultScanner.sol";
import "./interfaces/ILimitrRegistry.sol";
import "./interfaces/ILimitrVault.sol";

/// @author Limitr
/// @title Vault scanner
contract LimitrVaultScanner is ILimitrVaultScanner {
    address public override registry;

    constructor(address _registry) {
        registry = _registry;
    }

    /// @return The n vaults starting at index idx that have available balance
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function scanAvailableBalances(
        uint256 idx,
        uint256 n,
        address trader
    ) public view override returns (address[] memory) {
        address[] memory r = ILimitrRegistry(registry).vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (!_vaultGotBalance(r[i], trader)) {
                r[i] = address(0);
            }
        }
        return r;
    }

    /// @return The vaults with available balance
    /// @param trader The trader to scan for
    function scanAvailableBalancesAll(address trader)
        external
        view
        override
        returns (address[] memory)
    {
        return
            scanAvailableBalances(
                0,
                ILimitrRegistry(registry).vaultsCount(),
                trader
            );
    }

    /// @return The n vaults starting at index idx that have open orders
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function scanOpenOrders(
        uint256 idx,
        uint256 n,
        address trader
    ) public view override returns (address[] memory) {
        address[] memory r = ILimitrRegistry(registry).vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (!_vaultGotOrders(r[i], trader)) {
                r[i] = address(0);
            }
        }
        return r;
    }

    /// @return The vaults with open orders
    /// @param trader The trader to scan for
    function scanOpenOrdersAll(address trader)
        external
        view
        override
        returns (address[] memory)
    {
        return
            scanOpenOrders(0, ILimitrRegistry(registry).vaultsCount(), trader);
    }

    /// @return The n vaults starting at index idx that have open
    ///         orders or available balance
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function scanMemorable(
        uint256 idx,
        uint256 n,
        address trader
    ) public view override returns (address[] memory) {
        address[] memory r = ILimitrRegistry(registry).vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (!_vaultIsMemorable(r[i], trader)) {
                r[i] = address(0);
            }
        }
        return r;
    }

    /// @return The vaults with open orders or available balance
    /// @param trader The trader to scan for
    function scanMemorableAll(address trader)
        external
        view
        override
        returns (address[] memory)
    {
        return
            scanMemorable(0, ILimitrRegistry(registry).vaultsCount(), trader);
    }

    /// @return The vaults containing a particular token
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param token The token to scan for
    function scanForToken(
        uint256 idx,
        uint256 n,
        address token
    ) public view override returns (address[] memory) {
        address[] memory r = ILimitrRegistry(registry).vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (!_vaultGotToken(r[i], token)) {
                r[i] = address(0);
            }
        }
        return r;
    }

    /// @return The vaults with a particular token
    /// @param token The token to scan for
    function scanForTokenAll(address token)
        external
        view
        override
        returns (address[] memory)
    {
        return scanForToken(0, ILimitrRegistry(registry).vaultsCount(), token);
    }

    function _vaultGotOrders(address _vault, address trader)
        internal
        view
        returns (bool)
    {
        ILimitrVault v = ILimitrVault(_vault);
        return
            v.firstTraderOrder(v.token0(), trader) != 0 ||
            v.firstTraderOrder(v.token1(), trader) != 0;
    }

    function _vaultGotBalance(address _vault, address trader)
        internal
        view
        returns (bool)
    {
        ILimitrVault v = ILimitrVault(_vault);
        return
            v.traderBalance(v.token0(), trader) != 0 ||
            v.traderBalance(v.token1(), trader) != 0;
    }

    function _vaultIsMemorable(address _vault, address trader)
        internal
        view
        returns (bool)
    {
        return
            _vaultGotOrders(_vault, trader) || _vaultGotBalance(_vault, trader);
    }

    function _vaultGotToken(address _vault, address token)
        internal
        view
        returns (bool)
    {
        ILimitrVault v = ILimitrVault(_vault);
        return v.token0() == token || v.token1() == token;
    }
}
