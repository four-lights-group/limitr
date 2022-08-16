// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

interface IJumpstart {
    /// @return The names of the available uris
    function JS_names() external view returns (string[] memory);

    /// @return The uris for the provided `name`
    /// @param name The name of the uri to retrieve
    function JS_get(string memory name) external view returns (string memory);

    /// @return All uris
    function JS_getAll()
        external
        view
        returns (string[] memory, string[] memory);
}

interface IJumpstartManager {
    /// @notice Add an URL to the URL list
    /// @param name The name of the uri to add
    /// @param uri The URI
    function JS_add(string calldata name, string calldata uri) external;

    /// @notice Remove the URI from the list
    /// @param name The name of the uri to remove
    function JS_remove(string calldata name) external;

    /// @notice Update an existing URL
    /// @param name The name of the URI to update
    /// @param newUri The new URI
    function JS_update(string calldata name, string calldata newUri) external;
}
