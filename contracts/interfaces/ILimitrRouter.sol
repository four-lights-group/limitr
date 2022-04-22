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

    /// @notice Creates a new sell order order using 0 as price pointer
    /// @param sellToken The token to sell
    /// @param buyToken The token to receive in exchange
    /// @param price The order price
    /// @param amount The amount of sellToken to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @return The order ID
    function newSellOrder(
        address sellToken,
        address buyToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline
    ) external returns (uint256);

    /// @notice Creates a new sell order using the provided pointer
    /// @param sellToken The token to sell
    /// @param buyToken The token to receive in exchange
    /// @param price The order price
    /// @param amount The amount of sellToken to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointer The start pointer
    /// @return The order ID
    function newSellOrderWithPointer(
        address sellToken,
        address buyToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline,
        uint256 pointer
    ) external returns (uint256);

    /// @notice Creates a new sell order using the provided pointers
    /// @param sellToken The token to sell
    /// @param buyToken The token to receive in exchange
    /// @param price The order price
    /// @param amount The amount of sellToken to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointers The potential pointers
    /// @return The order ID
    function newSellOrderWithPointers(
        address sellToken,
        address buyToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline,
        uint256[] memory pointers
    ) external returns (uint256);

    /// @notice Creates a new ETH sell order order using 0 as price pointer
    /// @param buyToken The token to receive in exchange
    /// @param price The order price
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @return The order ID
    function newETHSellOrder(
        address buyToken,
        uint256 price,
        address trader,
        uint256 deadline
    ) external payable returns (uint256);

    /// @notice Creates a new ETH sell order using the provided pointer
    /// @param buyToken The token to receive in exchange
    /// @param price The order price
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointer The start pointer
    /// @return The order ID
    function newETHSellOrderWithPointer(
        address buyToken,
        uint256 price,
        address trader,
        uint256 deadline,
        uint256 pointer
    ) external payable returns (uint256);

    /// @notice Creates a new ETH sell order using the provided pointers
    /// @param buyToken The token to receive in exchange
    /// @param price The order price
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointers The potential pointers
    /// @return The order ID
    function newETHSellOrderWithPointers(
        address buyToken,
        uint256 price,
        address trader,
        uint256 deadline,
        uint256[] memory pointers
    ) external payable returns (uint256);

    // order cancellation functions

    /// @notice Cancel an WETH order and receive ETH
    /// @param buyToken The other token of the pair WETH/xxxxx
    /// @param orderID The order ID
    /// @param amount The amount to cancel. 0 cancels the total amount
    /// @param receiver The receiver of the remaining unsold tokens
    /// @param deadline Validity deadline
    function cancelETHOrder(
        address buyToken,
        uint256 orderID,
        uint256 amount,
        address payable receiver,
        uint256 deadline
    ) external;

    // trading functions

    /// @notice Buys buyToken from the vault with a maximum price (per order),
    ///         spending up to maxAmountIn. This function includes the fee in the
    ///         limit set by maxAmountIn
    /// @param buyToken The token to buy
    /// @param sellToken The token to sell
    /// @param maxPrice The price of the trade
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of buyToken received
    function buyAtMaxPrice(
        address buyToken,
        address sellToken,
        uint256 maxPrice,
        uint256 maxAmountIn,
        address receiver,
        uint256 deadline
    ) external returns (uint256 cost, uint256 received);

    /// @notice Buys buyToken from the vault with an average price (total),
    ///         spending up to maxAmountIn. This function includes the fee in the
    ///         limit set by maxAmountIn
    /// @param buyToken The token to buy
    /// @param sellToken The token to sell
    /// @param avgPrice, The maximum average price
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of buyToken received
    function buyAtAvgPrice(
        address buyToken,
        address sellToken,
        uint256 avgPrice,
        uint256 maxAmountIn,
        address receiver,
        uint256 deadline
    ) external returns (uint256 cost, uint256 received);

    /// @notice Buys ETH from the vault with a maximum price (per order),
    ///         spending up to maxAmountIn. This function includes the fee in the
    ///         limit set by maxAmountIn
    /// @param sellToken The other token of the pair WETH/xxxxx
    /// @param maxPrice The price of the trade
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of ETH received
    function buyETHAtMaxPrice(
        address sellToken,
        uint256 maxPrice,
        uint256 maxAmountIn,
        address payable receiver,
        uint256 deadline
    ) external returns (uint256 cost, uint256 received);

    /// @notice Buys ETH from the vault with an average price (total),
    ///         spending up to maxAmountIn. This function includes the fee in the
    ///         limit set by maxAmountIn
    /// @param sellToken The other token of the pair WETH/xxxxx
    /// @param avgPrice, The maximum average price
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of ETH received
    function buyETHAtAvgPrice(
        address sellToken,
        uint256 avgPrice,
        uint256 maxAmountIn,
        address payable receiver,
        uint256 deadline
    ) external returns (uint256 cost, uint256 received);

    /// @notice Buys buyToken from the vault with ETH and a maximum price (per order),
    ///         spending up to msg.value. This function includes the fee in the
    ///         limit set by msg.value
    /// @param buyToken The token to buy
    /// @param maxPrice The price of the trade
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount of ETH spent
    /// @return received The amount of buyToken received
    function buyWithETHAtMaxPrice(
        address buyToken,
        uint256 maxPrice,
        address receiver,
        uint256 deadline
    ) external payable returns (uint256 cost, uint256 received);

    /// @notice Buys buyToken from the vault with ETH at an average price (total),
    ///         spending up to msg.value. This function includes the fee in the
    ///         limit set by msg.value
    /// @param avgPrice, The maximum average price
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of buyToken received
    function buyWithETHAtAvgPrice(
        address buyToken,
        uint256 avgPrice,
        address receiver,
        uint256 deadline
    ) external payable returns (uint256 cost, uint256 received);

    /// @notice Withdraw trader balance in ETH
    /// @param sellToken The other token of the pair WETH/xxxxx
    /// @param to The receiver address
    /// @param amount The amount to withdraw
    function withdrawETH(
        address sellToken,
        address payable to,
        uint256 amount
    ) external;
}
