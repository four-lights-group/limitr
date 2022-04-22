pragma solidity ^0.8.0;

import "./interfaces/ILimitrRegistry.sol";
import "./interfaces/ILimitrVault.sol";

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

    constructor(address _vaultImplementation) {
        admin = msg.sender;
        feeReceiver = msg.sender;
        vaultImplementation = _vaultImplementation;
    }

    string[] internal _URLS;

    /// @return The existing URL's for the webui
    function URLS() external view override returns (string[] memory) {
        return _URLS;
    }

    /// @notice Add an URL to the URL list
    /// @param url The URL to add
    function addURL(string calldata url) external override {
        _URLS.push(url);
    }

    /// @notice Remove the URL at idx from the URL list
    /// @param idx The idx to remove
    function removeURL(uint256 idx) external override {
        _URLS[idx] = _URLS[_URLS.length - 1];
        _URLS.pop();
    }

    /// @notice Update an existing URL
    /// @param idx The idx to remove
    /// @param url The URL to add
    function updateURL(uint256 idx, string calldata url) external override {
        _URLS[idx] = url;
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

    /// @notice Set the router. Can only be called once by the admin
    /// @param newRouter The new router
    function setRouter(address newRouter) external override onlyAdmin {
        require(router == address(0), "already set");
        router = newRouter;
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
        require(tokenA != tokenB, "Equal src and dst tokens");
        (address t0, address t1) = _sortTokens(tokenA, tokenB);
        bytes32 hash = keccak256(abi.encodePacked(t0, t1));
        require(vaultByHash[hash] == address(0), "Vault already exists");
        address addr = _deployProxy(vaultImplementation);
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

    /// @return The n vaults at index idx
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
        require(tokenA != tokenB, "Equal base and counter tokens");
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
        require(tokenA != tokenB, "Equal src and dst tokens");
        return _vaultHash(tokenA, tokenB);
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
        address[] memory r = vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (_vaultGotBalance(r[i], trader)) {
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
        return scanAvailableBalances(0, vault.length, trader);
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
        address[] memory r = vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (_vaultGotOrders(r[i], trader)) {
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
        return scanOpenOrders(0, vault.length, trader);
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
        address[] memory r = vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (_vaultIsMemorable(r[i], trader)) {
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
        return scanMemorable(0, vault.length, trader);
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
        address[] memory r = vaults(idx, n);
        for (uint256 i = 0; i < r.length; i++) {
            if (r[i] == address(0)) {
                break;
            }
            if (_vaultGotToken(r[i], token)) {
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
        return scanForToken(0, vault.length, token);
    }

    // modifiers

    /// @dev Check for 0 address
    modifier noZeroAddress(address addr) {
        require(addr != address(0), "Zero address not allowed");
        _;
    }

    /// @dev only for the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not the admin");
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

    function _buildProxyBytecode(address impl)
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

    function _prependProxyConstructor(address impl)
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
                _buildProxyBytecode(impl)
            );
    }

    function _deployProxy(address impl)
        internal
        returns (address deploymentAddr)
    {
        bytes memory code = _prependProxyConstructor(impl);
        assembly {
            deploymentAddr := create(callvalue(), add(code, 0x20), mload(code))
        }
        require(deploymentAddr != address(0), "deployment failed");
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
