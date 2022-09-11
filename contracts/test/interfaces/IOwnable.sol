// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/// @author Limitr
/// @title Ownable interface
interface IOwnable {
    /// @notice OwnershipTransfer is emitted when a transfer of ownership occurs
    /// @param owner The current owner address
    /// @param newOwner The new owner address
    event OwnershipTransfer(address indexed owner, address indexed newOwner);

    /// @return The owner address
    function owner() external view returns (address payable);

    /// @notice Renounces ownership by setting the owner address to 0 and emits a OwnershipTransfer()
    function renounceOwnership() external;

    /// @notice Transfer ownership to the new owner address and emits a OwnershipTransfer()
    /// @param newOwner The new owner
    function transferOwnership(address payable newOwner) external;
}
