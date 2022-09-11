// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/ILimitrRegistry.sol";
import "./interfaces/ILimitrVault.sol";

/// @author Limitr
/// @notice This is the contract for the Limitr main registry
contract LimitrRegistry is ILimitrRegistry {
    /// @return The admin address
    address public override admin;

    /// @return The router address
    address public override router;

    /// @return The vault implementation address
    address public override vaultImplementation;

    /// @return The fee receiver address
    address public override feeReceiver;

    /// @notice The vault at index idx
    address[] public override vault;

    /// @return The address for the vault with the provided hash
    mapping(bytes32 => address) public override vaultByHash;

    /// @return The address of the vault scanner
    address public override vaultScanner;

    address private _deployer;

    constructor() {
        admin = msg.sender;
        feeReceiver = msg.sender;
        _deployer = msg.sender;
    }

    /// @notice Initialize addresses
    /// @param _router The address of the router
    /// @param _vaultScanner The address of the vault scanner
    /// @param _vaultImplementation The vault implementation
    function initialize(
        address _router,
        address _vaultScanner,
        address _vaultImplementation
    ) external override {
        require(msg.sender == _deployer, "LimitrRegistry: not the deployer");
        require(router == address(0), "LimitrRegistry: already initialized");
        router = _router;
        vaultScanner = _vaultScanner;
        vaultImplementation = _vaultImplementation;
    }

    string[] internal _uriNames;

    /// @return The names of the available uris
    function JS_names() external view override returns (string[] memory) {
        return _uriNames;
    }

    /// @return The uris for the provided `name`
    mapping(string => string) public override JS_get;

    /// @return All uris
    function JS_getAll()
        external
        view
        override
        returns (string[] memory, string[] memory)
    {
        string[] memory rn = new string[](_uriNames.length);
        string[] memory ru = new string[](_uriNames.length);
        for (uint256 i = 0; i < _uriNames.length; i++) {
            rn[i] = _uriNames[i];
            ru[i] = JS_get[rn[i]];
        }
        return (rn, ru);
    }

    /// @notice Add an URL to the URL list
    /// @param name The name of the uri to add
    /// @param uri The URI
    function JS_add(string calldata name, string calldata uri)
        external
        override
        onlyAdmin
    {
        require(bytes(JS_get[name]).length == 0, "JSM: Already exists");
        _uriNames.push(name);
        JS_get[name] = uri;
    }

    /// @notice Remove the URI from the list
    /// @param name The name of the uri to remove
    function JS_remove(string calldata name) external override onlyAdmin {
        bytes32 nameK = keccak256(abi.encodePacked(name));
        for (uint256 i = 0; i < _uriNames.length; i++) {
            if (nameK != keccak256(abi.encodePacked(_uriNames[i]))) {
                continue;
            }
            _uriNames[i] = _uriNames[_uriNames.length - 1];
            _uriNames.pop();
            delete JS_get[name];
            return;
        }
        require(true == false, "JSM: Not found");
    }

    /// @notice Update an existing URL
    /// @param name The name of the URI to update
    /// @param newUri The new URI
    function JS_update(string calldata name, string calldata newUri)
        external
        override
        onlyAdmin
    {
        require(bytes(JS_get[name]).length != 0, "JSM: Not found");
        JS_get[name] = newUri;
    }

    /// @notice Transfer the admin rights. Emits AdminUpdated
    /// @param newAdmin The new admin
    function transferAdmin(address newAdmin) external override onlyAdmin {
        admin = newAdmin;
        emit AdminUpdated(newAdmin);
    }

    /// @notice Set a new fee receiver. Emits FeeReceiverUpdated
    /// @param newFeeReceiver The new fee receiver
    function setFeeReceiver(address newFeeReceiver)
        external
        override
        onlyAdmin
    {
        feeReceiver = newFeeReceiver;
        emit FeeReceiverUpdated(newFeeReceiver);
    }

    /// @notice Set a new vault implementation. Emits VaultImplementationUpdated
    /// @param newVaultImplementation The new vault implementation
    function setVaultImplementation(address newVaultImplementation)
        external
        override
        onlyAdmin
    {
        vaultImplementation = newVaultImplementation;
        emit VaultImplementationUpdated(newVaultImplementation);
    }

    /// @notice Create a new vault
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB the other token in the pair
    /// @return The vault address
    function createVault(address tokenA, address tokenB)
        external
        override
        noZeroAddress(tokenA)
        noZeroAddress(tokenB)
        returns (address)
    {
        require(tokenA != tokenB, "LimitrRegistry: equal src and dst tokens");
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        bytes32 hash = keccak256(abi.encodePacked(t0, t1));
        require(
            vaultByHash[hash] == address(0),
            "LimitrRegistry: vault already exists"
        );
        address addr = _deployClone(vaultImplementation);
        ILimitrVault(addr).initialize(t0, t1);
        vaultByHash[hash] = addr;
        vault.push(addr);
        emit VaultCreated(addr, t0, t1);
        return addr;
    }

    /// @return The number of available vaults
    function vaultsCount() external view override returns (uint256) {
        return vault.length;
    }

    /// @return The `n` vaults at index `idx`
    /// @param idx The vault index
    /// @param n The number of vaults
    function vaults(uint256 idx, uint256 n)
        public
        view
        override
        returns (address[] memory)
    {
        address[] memory r = new address[](n);
        for (uint256 i = 0; i < n && idx + i < vault.length; i++) {
            r[i] = vault[idx + i];
        }
        return r;
    }

    /// @return The address of the vault for the trade pair tokenA/tokenB
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB the other token in the pair
    function vaultFor(address tokenA, address tokenB)
        external
        view
        override
        noZeroAddress(tokenA)
        noZeroAddress(tokenB)
        returns (address)
    {
        require(
            tokenA != tokenB,
            "LimitrRegistry: equal base and counter tokens"
        );
        return vaultByHash[_vaultHash(tokenA, tokenB)];
    }

    /// @notice Calculate the hash for a vault
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB the other token in the pair
    /// @return The vault hash
    function vaultHash(address tokenA, address tokenB)
        public
        pure
        override
        returns (bytes32)
    {
        require(tokenA != tokenB, "LimitrRegistry: equal src and dst tokens");
        return _vaultHash(tokenA, tokenB);
    }

    // modifiers

    /// @dev Check for 0 address
    modifier noZeroAddress(address addr) {
        require(addr != address(0), "LimitrRegistry: zero address not allowed");
        _;
    }

    /// @dev only for the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "LimitrRegistry: not the admin");
        _;
    }

    // private/internal functions

    function _sortTokens(address a, address b)
        internal
        pure
        returns (address, address)
    {
        return a < b ? (a, b) : (b, a);
    }

    function _vaultHash(address a, address b) internal pure returns (bytes32) {
        (address t0, address t1) = _sortTokens(a, b);
        return keccak256(abi.encodePacked(t0, t1));
    }

    function _buildCloneBytecode(address impl)
        internal
        pure
        returns (bytes memory)
    {
        // calldatacopy(0, 0, calldatasize())
        // 3660008037

        // 0x36 CALLDATASIZE
        // 0x60 PUSH1 0x00
        // 0x80 DUP1
        // 0x37 CALLDATACOPY

        // let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
        // 600080368173xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx5af4

        // 0x60 PUSH1 0x00
        // 0x80 DUP1
        // 0x36 CALLDATASIZE
        // 0x81 DUP2
        // 0x73 PUSH20 <concat-address-here>
        // 0x5A GAS
        // 0xF4 DELEGATECALL

        // returndatacopy(0, 0, returndatasize())
        // 3d6000803e

        // 0x3D RETURNDATASIZE
        // 0x60 PUSH1 0x00
        // 0x80 DUP1
        // 0x3E RETURNDATACOPY

        // switch result
        // case 0 { revert(0, returndatasize()) }
        // case 1 { return(0, returndatasize()) }
        // 60003d91600114603157fd5bf3

        // 0x60 PUSH1 0x00
        // 0x3D RETURNDATASIZE
        // 0x91 SWAP2
        // 0x60 PUSH1 0x01
        // 0x14 EQ
        // 0x60 PUSH1 0x31
        // 0x57 JUMPI
        // 0xFD REVERT
        // 0x5B JUMPEST
        // 0xF3 RETURN

        return
            bytes.concat(
                bytes(hex"3660008037600080368173"),
                bytes20(impl),
                bytes(hex"5af43d6000803e60003d91600114603157fd5bf3")
            );
    }

    function _prependCloneConstructor(address impl)
        internal
        pure
        returns (bytes memory)
    {
        // codecopy(0, ofs, codesize() - ofs)
        // return(0, codesize() - ofs)

        // 0x60 PUSH1 0x0D
        // 0x80 DUP1
        // 0x38 CODESIZE
        // 0x03 SUB
        // 0x80 DUP1
        // 0x91 SWAP2
        // 0x60 PUSH1 0x00
        // 0x39 CODECOPY
        // 0x60 PUSH1 0x00
        // 0xF3 RETURN
        // <concat-contract-code-here>

        // 0x600D80380380916000396000F3xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        return
            bytes.concat(
                hex"600D80380380916000396000F3",
                _buildCloneBytecode(impl)
            );
    }

    function _deployClone(address impl)
        internal
        returns (address deploymentAddr)
    {
        bytes memory code = _prependCloneConstructor(impl);
        assembly {
            deploymentAddr := create(callvalue(), add(code, 0x20), mload(code))
        }
        require(
            deploymentAddr != address(0),
            "LimitrRegistry: clone deployment failed"
        );
    }
}
