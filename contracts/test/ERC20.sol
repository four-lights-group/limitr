// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";

/// @author Limitr
/// @title ERC20 token
contract ERC20 is IERC20 {

    /// @return Token name
    string public override name;

    /// @return Token symbol
    string public override symbol;

    /// @return Token decimals
    uint8 public override decimals;

    /// @return Total token supply
    uint256 public override totalSupply;

    /// @return Balance for owner
    mapping(address => uint256) public override balanceOf;

    /// @return Allowed balance for spender
    mapping(address => mapping(address => uint256)) public override allowance;

    /// @notice contract constructor
    /// @param _name The token name
    /// @param _symbol The token symbol
    /// @param _decimals The token decimals
    constructor (
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    /// @dev Checks if owner has enough balance
    /// @param owner The owner address
    /// @param amount The amount required
    modifier enoughBalance(address owner, uint256 amount) {
        require(balanceOf[owner] >= amount, "not enough balance");
        _;
    }

    /// @dev Checks if spender has enough approved balance
    /// @param owner The owner address
    /// @param spender The spender address
    /// @param amount The amount required
    modifier enoughAllowance(address owner, address spender, uint256 amount) {
        require(allowance[owner][spender] >= amount, "not enough allowance");
        _;
    }

    /// @dev Checks if the address is zero
    /// @param addr The address
    modifier noZeroAddress(address addr) {
        require(addr != address(0), "zero address is not allowed");
        _;
    }

    /// @notice Transfers tokens to the provided address
    /// @param to The new owner address
    /// @param amount The amount to transfer
    /// @return true on success
    function transfer(address to, uint256 amount)
        public virtual override
        enoughBalance(msg.sender, amount)
        noZeroAddress(to)
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Approves the provided amount to the provided spender address
    /// @param spender The spender address
    /// @param amount The amount to approve
    /// @return true on success
    function approve(address spender, uint256 amount)
        public override
        noZeroAddress(spender)
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers tokens from an approved address to the provided address
    /// @param from The tokens owner address
    /// @param to The new owner address
    /// @param amount The amount to transfer
    /// @return true on success
    function transferFrom(address from, address to, uint256 amount)
        public virtual override
        noZeroAddress(from)
        noZeroAddress(to)
        enoughBalance(from, amount)
        enoughAllowance(from, msg.sender, amount)
        returns (bool)
    {
        if (allowance[from][msg.sender] != uint256(int256(-1))) {
            allowance[from][msg.sender] -= amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    /// @dev makes a token transfer and emits a Transfer()
    /// @param from The origin address
    /// @param to The destination address
    /// @param amount The amount to transfer
    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    /// @dev approves an amount and emits an Approval()
    /// @param owner The owner address
    /// @param spender The spender address
    /// @param amount The amount to approve
    function _approve(address owner, address spender, uint256 amount) internal {
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}