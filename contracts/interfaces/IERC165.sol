// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/// @author Limitr
/// @title ERC165 interface needed for the ERC721 implementation
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
