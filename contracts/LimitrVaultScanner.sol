// SPDX-License-Identifier: BUSL-1.1

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

    /// @return The `n` vaults starting at index `idx` that have available balance
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function availableBalances(
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
    function availableBalancesAll(address trader)
        external
        view
        override
        returns (address[] memory)
    {
        return
            availableBalances(
                0,
                ILimitrRegistry(registry).vaultsCount(),
                trader
            );
    }

    /// @return The `n` vaults starting at index `idx` that have open orders
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function openOrders(
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
    function openOrdersAll(address trader)
        external
        view
        override
        returns (address[] memory)
    {
        return openOrders(0, ILimitrRegistry(registry).vaultsCount(), trader);
    }

    /// @return The `n` vaults starting at index `idx` that have open
    ///         orders or available balance
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param trader The trader to scan for
    function memorable(
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
    function memorableAll(address trader)
        external
        view
        override
        returns (address[] memory)
    {
        return memorable(0, ILimitrRegistry(registry).vaultsCount(), trader);
    }

    /// @return The `n` vaults starting at index `idx` containing `token`
    /// @param idx The vault index
    /// @param n The number of vaults
    /// @param _token The token to scan for
    function token(
        uint256 idx,
        uint256 n,
        address _token
    ) public view override returns (address[] memory) {
        address[] memory r = ILimitrRegistry(registry).vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (!_vaultGotToken(r[i], _token)) {
                r[i] = address(0);
            }
        }
        return r;
    }

    /// @return The vaults with a particular token
    /// @param _token The token to scan for
    function tokenAll(address _token)
        external
        view
        override
        returns (address[] memory)
    {
        return token(0, ILimitrRegistry(registry).vaultsCount(), _token);
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

    function _vaultGotToken(address _vault, address _token)
        internal
        view
        returns (bool)
    {
        ILimitrVault v = ILimitrVault(_vault);
        return v.token0() == _token || v.token1() == _token;
    }
}
