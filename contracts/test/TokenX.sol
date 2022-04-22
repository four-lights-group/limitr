// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./ERC20Mintable.sol";
import "./ERC20Burnable.sol";


/// @author Limitr
/// @title TokenX is a mintable/burnable ERC20 token
contract TokenX is ERC20Mintable, ERC20Burnable {

    /// @notice contract constructor
    /// @param _name The token name
    /// @param _symbol The token symbol
    /// @param _decimals The token decimals
    /// @param _owner The owner address for any pre-minted tokens
    /// @param _amount The amount of tokens to pre-mint
    constructor (
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner,
        uint256 _amount
    ) ERC20(_name, _symbol, _decimals)
    {
        if (_amount > 0) {
        if (_owner == address(0)) {
            _owner = msg.sender;
        }
        _mint(_owner, _amount);
        }
    }
}
