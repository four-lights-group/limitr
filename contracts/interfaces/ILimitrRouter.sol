// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/// @author Limitr
/// @title Limitr router interface
interface ILimitrRouter {
    /// @return The address for the registry
    function registry() external view returns (address);

    /// @return The address for WETH
    function weth() external view returns (address);

    // order creation functions

    /// @notice Creates a new order using 0 as price pointer
    /// @param gotToken The token to trade in
    /// @param wantToken The token to receive in exchange
    /// @param price The order price
    /// @param amount The amount of `gotToken` to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @return The order ID
    function newOrder(
        address gotToken,
        address wantToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline
    ) external returns (uint256);

    /// @notice Creates a new order using the provided `pointer`
    /// @param gotToken The token to trade in
    /// @param wantToken The token to receive in exchange
    /// @param price The order price
    /// @param amount The amount of `gotToken` to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointer The start pointer
    /// @return The order ID
    function newOrderWithPointer(
        address gotToken,
        address wantToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline,
        uint256 pointer
    ) external returns (uint256);

    /// @notice Creates a new order using the provided `pointers`
    /// @param gotToken The token to trade in
    /// @param wantToken The token to receive in exchange
    /// @param price The order price
    /// @param amount The amount of `gotToken` to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointers The potential pointers
    /// @return The order ID
    function newOrderWithPointers(
        address gotToken,
        address wantToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline,
        uint256[] memory pointers
    ) external returns (uint256);

    /// @notice Creates a new ETH order order using 0 as price pointer
    /// @param wantToken The token to receive in exchange
    /// @param price The order price
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @return The order ID
    function newETHOrder(
        address wantToken,
        uint256 price,
        address trader,
        uint256 deadline
    ) external payable returns (uint256);

    /// @notice Creates a new ETH order using the provided `pointer`
    /// @param wantToken The token to receive in exchange
    /// @param price The order price
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointer The start pointer
    /// @return The order ID
    function newETHOrderWithPointer(
        address wantToken,
        uint256 price,
        address trader,
        uint256 deadline,
        uint256 pointer
    ) external payable returns (uint256);

    /// @notice Creates a new ETH order using the provided `pointers`
    /// @param wantToken The token to receive in exchange
    /// @param price The order price
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointers The potential pointers
    /// @return The order ID
    function newETHOrderWithPointers(
        address wantToken,
        uint256 price,
        address trader,
        uint256 deadline,
        uint256[] memory pointers
    ) external payable returns (uint256);

    // order cancellation functions

    /// @notice Cancel an WETH order and receive ETH
    /// @param wantToken The other token of the pair WETH/xxxxx
    /// @param orderID The order ID
    /// @param amount The amount to cancel. 0 cancels the total amount
    /// @param receiver The receiver of the remaining unsold tokens
    /// @param deadline Validity deadline
    function cancelETHOrder(
        address wantToken,
        uint256 orderID,
        uint256 amount,
        address payable receiver,
        uint256 deadline
    ) external;

    // trading functions

    /// @notice Trades up to `maxAmountIn` of `gotToken` for `wantToken` from the
    ///         vault with a maximum price (per order). This function includes
    ///         the fee in the limit set by `maxAmountIn`
    /// @param wantToken The token to trade in
    /// @param gotToken The token to receive
    /// @param maxPrice The price of the trade
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount of `gotToken` spent
    /// @return received The amount of `wantToken` received
    function tradeAtMaxPrice(
        address wantToken,
        address gotToken,
        uint256 maxPrice,
        uint256 maxAmountIn,
        address receiver,
        uint256 deadline
    ) external returns (uint256 cost, uint256 received);

    /// @notice Trades up to `maxAmountIn` of `gotToken` for ETH from the
    ///         vault with a maximum price (per order). This function includes
    ///         the fee in the limit set by `maxAmountIn`
    /// @param gotToken The other token of the pair WETH/xxxxx
    /// @param maxPrice The price of the trade
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of ETH received
    function tradeForETHAtMaxPrice(
        address gotToken,
        uint256 maxPrice,
        uint256 maxAmountIn,
        address payable receiver,
        uint256 deadline
    ) external returns (uint256 cost, uint256 received);

    /// @notice Trades ETH for `wantToken` from the vault with a maximum price
    ///         (per order). This function includes the fee in the limit set by `msg.value`
    /// @param wantToken The token to receive
    /// @param maxPrice The price of the trade
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount of ETH spent
    /// @return received The amount of `wantToken` received
    function tradeETHAtMaxPrice(
        address wantToken,
        uint256 maxPrice,
        address receiver,
        uint256 deadline
    ) external payable returns (uint256 cost, uint256 received);

    /// @notice Withdraw trader balance in ETH
    /// @param gotToken The other token of the pair WETH/xxxxx
    /// @param to The receiver address
    /// @param amount The amount to withdraw
    function withdrawETH(
        address gotToken,
        address payable to,
        uint256 amount
    ) external;
}
