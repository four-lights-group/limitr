// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./interfaces/IERC20Burnable.sol";
import "./ERC20.sol";
import "./Ownable.sol";


/// @author Limitr
/// @title Burnable ERC20 token
abstract contract ERC20Burnable is IERC20Burnable, ERC20, Ownable {

    /// @notice Burns tokens and emits a Burn()
    /// @param owner The owner address
    /// @param amount The amount to burn
    function burn(address owner, uint256 amount)
        public override
        onlyOwner
        enoughBalance(owner, amount)
    {
        _burn(owner, amount);
    }

    /// @dev Burns tokens and emits a Burn()
    /// @param owner The owner address
    /// @param amount The amount to burn
    function _burn(address owner, uint256 amount) internal {
        balanceOf[owner] -= amount;
        totalSupply -= amount;
        emit Burn(owner, amount);
    }
}