// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IOwnable.sol";

/// @author Limitr
/// @title Ownable contract
contract Ownable is IOwnable {
    /// @return The owner address
    address payable public override owner;

    /// @notice contract constructor
    constructor() {
        owner = payable(msg.sender);
        emit OwnershipTransfer(address(0), owner);
    }

    /// @dev Checks if the calling address is the owner
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /// @notice Renounces ownership by setting the owner address to 0 and emits a OwnershipTransfer()
    function renounceOwnership() external override onlyOwner {
        address oldOwner = owner;
        owner = payable(0);
        emit OwnershipTransfer(oldOwner, owner);
    }

    /// @notice Transfer ownership to the new owner address and emits a OwnershipTransfer()
    /// @param newOwner The new owner
    function transferOwnership(address payable newOwner)
        external
        override
        onlyOwner
    {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransfer(oldOwner, newOwner);
    }
}
