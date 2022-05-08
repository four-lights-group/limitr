// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

interface ILimitrRegistry {
    // events

    /// @notice VaultImplementationUpdated is emitted when a new vault implementation is set
    /// @param newVaultImplementation Then new vault implementation
    event VaultImplementationUpdated(address indexed newVaultImplementation);

    /// @notice AdminUpdated is emitted when a new admin is set
    /// @param newAdmin Then new admin
    event AdminUpdated(address indexed newAdmin);

    /// @notice FeeReceiverUpdated is emitted when a new fee receiver is set
    /// @param newFeeReceiver Then new fee receiver
    event FeeReceiverUpdated(address indexed newFeeReceiver);

    /// @notice VaultCreated is emitted when a new vault is created and added to the registry
    /// param vault The address of the vault created
    /// @param token0 One of the tokens in the pair
    /// @param token1 the other token in the pair
    event VaultCreated(
        address indexed vault,
        address indexed token0,
        address indexed token1
    );

    /// @notice Initialize addresses
    /// @param _router The address of the router
    /// @param _vaultScanner The address of the vault scanner
    /// @param _vaultImplementation The vault implementation
    function initialize(
        address _router,
        address _vaultScanner,
        address _vaultImplementation
    ) external;

    /// @return The existing URL's for the webui
    function URLS() external view returns (string[] memory);

    /// @notice Add an URL to the URL list
    /// @param url The URL to add
    function addURL(string calldata url) external;

    /// @notice Remove the URL at idx from the URL list
    /// @param idx The idx to remove
    function removeURL(uint256 idx) external;

    /// @notice Update an existing URL
    /// @param idx The idx to remove
    /// @param url The URL to add
    function updateURL(uint256 idx, string calldata url) external;

    /// @return The admin address
    function admin() external view returns (address);

    /// @notice Transfer the admin rights. Emits AdminUpdated
    /// @param newAdmin The new admin
    function transferAdmin(address newAdmin) external;

    /// @return The fee receiver address
    function feeReceiver() external view returns (address);

    /// @notice Set a new fee receiver. Emits FeeReceiverUpdated
    /// @param newFeeReceiver The new fee receiver
    function setFeeReceiver(address newFeeReceiver) external;

    /// @return The router address
    function router() external view returns (address);

    /// @return The vault implementation address
    function vaultImplementation() external view returns (address);

    /// @notice Set a new vault implementation. Emits VaultImplementationUpdated
    /// @param newVaultImplementation The new vault implementation
    function setVaultImplementation(address newVaultImplementation) external;

    /// @notice Create a new vault
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB the other token in the pair
    /// @return The vault address
    function createVault(address tokenA, address tokenB)
        external
        returns (address);

    /// @return The number of available vaults
    function vaultsCount() external view returns (uint256);

    /// @return The vault at index idx
    /// @param idx The vault index
    function vault(uint256 idx) external view returns (address);

    /// @return The n vaults at index idx
    /// @param idx The vault index
    /// @param n The number of vaults
    function vaults(uint256 idx, uint256 n)
        external
        view
        returns (address[] memory);

    /// @return The address of the vault for the trade pair tokenA/tokenB
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB the other token in the pair
    function vaultFor(address tokenA, address tokenB)
        external
        view
        returns (address);

    /// @return The address for the vault with the provided hash
    /// @param hash The vault hash
    function vaultByHash(bytes32 hash) external view returns (address);

    /// @notice Calculate the hash for a vault
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB the other token in the pair
    /// @return The vault hash
    function vaultHash(address tokenA, address tokenB)
        external
        pure
        returns (bytes32);

    /// @return The address of the vault scanner
    function vaultScanner() external view returns (address);
}
