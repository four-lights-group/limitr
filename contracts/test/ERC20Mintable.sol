// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./interfaces/IERC20Mintable.sol";
import "./ERC20.sol";
import "./Ownable.sol";


/// @author Limitr
/// @title Mintable ERC20 token
abstract contract ERC20Mintable is IERC20Mintable, ERC20, Ownable {

    /// @notice Mints tokens and emits a Mint()
    /// @param owner The owner address
    /// @param amount The amount to mint
    function mint(address owner, uint256 amount)
        public override
        onlyOwner
    {
        _mint(owner, amount);
    }

    /// @dev Mints tokens and emits a Mint()
    /// @param owner The owner address
    /// @param amount The amount to mint
    function _mint(address owner, uint256 amount) internal {
        balanceOf[owner] += amount;
        totalSupply += amount;
        emit Mint(owner, amount);
    }
}