// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./IERC721.sol";

/// @author Limitr
/// @title Trade vault contract interface for Limitr
interface ILimitrVault is IERC721 {
    // events

    /// @notice NewFeePercentage is emitted when a new fee receiver is set
    /// @param oldFeePercentage The old fee percentage
    /// @param newFeePercentage The new fee percentage
    event NewFeePercentage(uint256 oldFeePercentage, uint256 newFeePercentage);

    /// @notice NewSellOrder is emitted when a new order is created
    /// @param token The token to sell, will be either token0 or token1
    /// @param id The id of the order
    /// @param trader The trader address
    /// @param price The price of the order
    /// @param amount The amount deposited
    event NewSellOrder(
        address indexed token,
        uint256 indexed id,
        address indexed trader,
        uint256 price,
        uint256 amount
    );

    /// @notice OrderCanceled is emitted when a trader cancels (even if partially) an order
    /// @param token The token to sell, will be either token0 or token1
    /// @param id The order id
    /// @param amount The amount canceled
    event OrderCanceled(
        address indexed token,
        uint256 indexed id,
        uint256 amount
    );

    /// @notice OrderTaken is emitted when an order is taken (even if partially) from the vault
    /// @param token The token sold
    /// @param id The order id
    /// @param owner The owner of the order
    /// @param amount The amount traded
    /// @param price The trade price
    event OrderTaken(
        address indexed token,
        uint256 indexed id,
        address indexed owner,
        uint256 amount,
        uint256 price
    );

    /// @notice TokenWithdraw is emitted when an withdrawal is requested by a trader
    /// @param token The token withdrawn
    /// @param owner The owner of the funds
    /// @param receiver The receiver of the tokens
    /// @param amount The amount withdrawn
    event TokenWithdraw(
        address indexed token,
        address indexed owner,
        address indexed receiver,
        uint256 amount
    );

    /// @notice ArbitrageProfitTaken is emitted when an arbitrage profit is taken
    /// @param profitToken The main profit token
    /// @param profitAmount The amount of `profitToken` received
    /// @param otherAmount The amount of received of the other token of the vault
    /// @param receiver The profit receiver
    event ArbitrageProfitTaken(
        address indexed profitToken,
        uint256 profitAmount,
        uint256 otherAmount,
        address indexed receiver
    );

    /// @notice FeeCollected is emitted when the fee on a buy is collected
    /// @param token The fee token
    /// @param amount The amount collected
    event FeeCollected(address indexed token, uint256 amount);

    /// @notice Initialize the market. Must be called by the factory once at deployment time
    /// @param _token0 The first token of the pair
    /// @param _token1 The second token of the pair
    function initialize(address _token0, address _token1) external;

    // fee functions

    /// @return The fee percentage represented as a value between 0 and 10^18
    function feePercentage() external view returns (uint256);

    /// @notice Set a new fee (must be smaller than the current, for the `feeReceiverSetter` only)
    ///         Emits a NewFeePercentage event
    /// @param newFeePercentage The new fee in the format described in `feePercentage`
    function setFeePercentage(uint256 newFeePercentage) external;

    // factory and token addresses

    /// @return The registry address
    function registry() external view returns (address);

    /// @return The first token of the pair
    function token0() external view returns (address);

    /// @return The second token of the pair
    function token1() external view returns (address);

    // price listing functions

    /// @return The first price on the order book for the provided `token`
    /// @param token Must be `token0` or `token1`
    function firstPrice(address token) external view returns (uint256);

    /// @return The last price on the order book for the provided `token`
    /// @param token Must be `token0` or `token1`
    function lastPrice(address token) external view returns (uint256);

    /// @return The previous price to the pointer for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param current The current price
    function previousPrice(address token, uint256 current)
        external
        view
        returns (uint256);

    /// @return The next price to the current for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param current The current price
    function nextPrice(address token, uint256 current)
        external
        view
        returns (uint256);

    /// @return N prices after current for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param current The current price
    /// @param n The number of prices to return
    function prices(
        address token,
        uint256 current,
        uint256 n
    ) external view returns (uint256[] memory);

    /// @return n price pointers for the provided price for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param price The price to insert
    /// @param nPointers The number of pointers to return
    function pricePointers(
        address token,
        uint256 price,
        uint256 nPointers
    ) external view returns (uint256[] memory);

    // orders functions

    /// @return The ID of the first order for the provided `token`
    /// @param token Must be `token0` or `token1`
    function firstOrder(address token) external view returns (uint256);

    /// @return The ID of the last order for the provided `token`
    /// @param token Must be `token0` or `token1`
    function lastOrder(address token) external view returns (uint256);

    /// @return The ID of the previous order for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param currentID Pointer to the current order
    function previousOrder(address token, uint256 currentID)
        external
        view
        returns (uint256);

    /// @return The ID of the next order for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param currentID Pointer to the current order
    function nextOrder(address token, uint256 currentID)
        external
        view
        returns (uint256);

    /// @notice Returns n order IDs from the current for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param current The current ID
    /// @param n The number of IDs to return
    function orders(
        address token,
        uint256 current,
        uint256 n
    ) external view returns (uint256[] memory);

    /// @notice Returns the order data for `n` orders of the provided `token`,
    ///         starting after `current`
    /// @param token Must be `token0` or `token1`
    /// @param current The current ID
    /// @param n The number of IDs to return
    /// @return id Array of order IDs
    /// @return price Array of prices
    /// @return amount Array of amounts
    /// @return trader Array of traders
    function ordersInfo(
        address token,
        uint256 current,
        uint256 n
    )
        external
        view
        returns (
            uint256[] memory id,
            uint256[] memory price,
            uint256[] memory amount,
            address[] memory trader
        );

    /// @notice Returns the order data for the provided `token` and `orderID`
    /// @param token Must be `token0` or `token1`
    /// @param orderID ID of the order
    /// @return price The price for the order
    /// @return amount The amount of the base token for sale
    /// @return trader The owner of the order
    function orderInfo(address token, uint256 orderID)
        external
        view
        returns (
            uint256 price,
            uint256 amount,
            address trader
        );

    /// @return Returns the token for sale of the provided `orderID`
    /// @param orderID The order ID
    function orderToken(uint256 orderID) external view returns (address);

    /// @return The last assigned order ID
    function lastID() external view returns (uint256);

    /// liquidity functions

    /// @return Return the available liquidity at a particular price, for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param price The price
    function liquidityByPrice(address token, uint256 price)
        external
        view
        returns (uint256);

    /// @notice Return the available liquidity until `maxPrice`
    /// @param token Must be `token0` or `token1`
    /// @param current The current price
    /// @param n The number of prices to return
    /// @return price Array of prices
    /// @return priceLiquidity Array of liquidity
    function liquidity(
        address token,
        uint256 current,
        uint256 n
    )
        external
        view
        returns (uint256[] memory price, uint256[] memory priceLiquidity);

    /// @return The total liquidity available for the provided `token`
    /// @param token Must be `token0` or `token1`
    function totalLiquidity(address token) external view returns (uint256);

    // trader order functions

    /// @return The ID of the first order of the `trader` for the provided `token`
    /// @param token The token to list
    /// @param trader The trader
    function firstTraderOrder(address token, address trader)
        external
        view
        returns (uint256);

    /// @return The ID of the last order of the `trader` for the provided `token`
    /// @param token The token to list
    /// @param trader The trader
    function lastTraderOrder(address token, address trader)
        external
        view
        returns (uint256);

    /// @return The ID of the previous order of the `trader` for the provided `token`
    /// @param token The token to list
    /// @param trader The trader
    /// @param currentID Pointer to a trade
    function previousTraderOrder(
        address token,
        address trader,
        uint256 currentID
    ) external view returns (uint256);

    /// @return The ID of the next order of the `trader` for the provided `token`
    /// @param token The token to list
    /// @param trader The trader
    /// @param currentID Pointer to a trade
    function nextTraderOrder(
        address token,
        address trader,
        uint256 currentID
    ) external view returns (uint256);

    /// @notice Returns n order IDs from `current` for the provided `token`
    /// @param token The `token` to list
    /// @param trader The trader
    /// @param current The current ID
    /// @param n The number of IDs to return
    function traderOrders(
        address token,
        address trader,
        uint256 current,
        uint256 n
    ) external view returns (uint256[] memory);

    // fee calculation functions

    /// @return The amount corresponding to the fee from a provided `amount`
    /// @param amount The traded amount
    function feeOf(uint256 amount) external view returns (uint256);

    /// @return The amount to collect as fee for the provided `amount`
    /// @param amount The amount traded
    function feeFor(uint256 amount) external view returns (uint256);

    /// @return The amount available after collecting the fee from the provided `amount`
    /// @param amount The total amount
    function withoutFee(uint256 amount) external view returns (uint256);

    /// @return The provided `amount` with added fee
    /// @param amount The amount without fee
    function withFee(uint256 amount) external view returns (uint256);

    // trade amounts calculation functions

    /// @return The cost of buying `buyToken` at the provided `price`. Fees not included
    /// @param buyToken The token to buy
    /// @param amountOut The return
    /// @param price The buy price
    function costAtPrice(
        address buyToken,
        uint256 amountOut,
        uint256 price
    ) external view returns (uint256);

    /// @return The amount of `buyToken` than can be purchased with the provided
    ///         `amount` at `price`. Fees not included.
    /// @param buyToken The token to buy
    /// @param amountIn The cost
    /// @param price The sell price
    function returnAtPrice(
        address buyToken,
        uint256 amountIn,
        uint256 price
    ) external view returns (uint256);

    /// @notice Cost of buying `buyToken` up to `maxAmountOut` at a `maxPrice`
    ///         (maximum order price). Fees not included
    /// @param buyToken The token to buy
    /// @param maxAmountOut The maximum return
    /// @param maxPrice The max price
    /// @return amountIn The cost
    /// @return amountOut The return
    function costAtMaxPrice(
        address buyToken,
        uint256 maxAmountOut,
        uint256 maxPrice
    ) external view returns (uint256 amountIn, uint256 amountOut);

    /// @notice The amount of `buyToken` that can be purchased with up to
    ///         `maxAmountIn`, at a `maxPrice` (maximum order price). Fees not included.
    /// @param buyToken The token to buy
    /// @param maxAmountIn The maximum cost
    /// @param maxPrice The max price
    /// @return amountIn The cost
    /// @return amountOut The return
    function returnAtMaxPrice(
        address buyToken,
        uint256 maxAmountIn,
        uint256 maxPrice
    ) external view returns (uint256 amountIn, uint256 amountOut);

    /// @notice Cost of buying `buyToken` up to `maxAmountOut` at `avgPrice`
    ///         (average order price). Fees not included.
    /// @param buyToken The token to buy
    /// @param maxAmountOut The maximum return
    /// @param avgPrice The max average price
    /// @return amountIn The cost
    /// @return amountOut The return
    function costAtAvgPrice(
        address buyToken,
        uint256 maxAmountOut,
        uint256 avgPrice
    ) external view returns (uint256 amountIn, uint256 amountOut);

    /// @notice The amount `buyToken` that can be purchased with up to `maxAmountIn`,
    ///         at `avgPrice` (average order price). Fees not included
    /// @param buyToken The token to buy
    /// @param maxAmountIn The maximum cost
    /// @param avgPrice The max average price
    /// @return amountIn The cost
    /// @return amountOut The return

    function returnAtAvgPrice(
        address buyToken,
        uint256 maxAmountIn,
        uint256 avgPrice
    ) external view returns (uint256 amountIn, uint256 amountOut);

    // order creation functions

    /// @notice Creates a new sell order order using 0 as price pointer
    /// @param sellToken The token to sell
    /// @param price The order price
    /// @param amount The amount of sellToken to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @return The order ID
    function newSellOrder(
        address sellToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline
    ) external returns (uint256);

    /// @notice Creates a new sell order using a `pointer`
    /// @param sellToken The token to sell
    /// @param price The order price
    /// @param amount The amount of sellToken to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointer The start pointer
    /// @return The order ID
    function newSellOrderWithPointer(
        address sellToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline,
        uint256 pointer
    ) external returns (uint256);

    /// @notice Creates a new sell order using an array of possible `pointers`
    /// @param sellToken The token to sell
    /// @param price The order price
    /// @param amount The amount of sellToken to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @param pointers The potential pointers
    /// @return The order ID
    function newSellOrderWithPointers(
        address sellToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline,
        uint256[] memory pointers
    ) external returns (uint256);

    // order cancellation functions

    /// @notice Cancel an order
    /// @param orderID The order ID
    /// @param amount The amount to cancel. 0 cancels the total amount
    /// @param receiver The receiver of the remaining unsold tokens
    /// @param deadline Validity deadline
    function cancelOrder(
        uint256 orderID,
        uint256 amount,
        address receiver,
        uint256 deadline
    ) external;

    // trading functions

    /// @notice Buys `buyToken` from the vault with a `maxPrice` (per order),
    ///         spending up to `maxAmountIn`. This function includes the fee in the
    ///         limit set by `maxAmountIn`
    /// @param buyToken The token to buy
    /// @param maxPrice The price of the trade
    /// @param maxAmountIn The maximum cost
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of `buyToken` received
    function buyAtMaxPrice(
        address buyToken,
        uint256 maxPrice,
        uint256 maxAmountIn,
        address receiver,
        uint256 deadline
    ) external returns (uint256 cost, uint256 received);

    /// @notice Buys `buyToken` from the vault with an `avgPrice` (average price),
    ///         spending up to `maxAmountIn`. This function includes the fee in the
    ///         limit set by `maxAmountIn`
    /// @param avgPrice, The maximum average price
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of `buyToken` received
    function buyAtAvgPrice(
        address buyToken,
        uint256 avgPrice,
        uint256 maxAmountIn,
        address receiver,
        uint256 deadline
    ) external returns (uint256 cost, uint256 received);

    // trader balances

    /// @return The trader balance available to withdraw
    /// @param token Must be `token0` or `token1`
    /// @param trader The trader address
    function traderBalance(address token, address trader)
        external
        view
        returns (uint256);

    /// @notice Withdraw trader balance
    /// @param token Must be `token0` or `token1`
    /// @param to The receiver address
    /// @param amount The amount to withdraw
    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external;

    /// @notice Withdraw on behalf of a trader. Can only be called by the router
    /// @param token Must be `token0` or `token1`
    /// @param trader The trader to handle
    /// @param amount The amount to withdraw
    function withdrawFor(
        address token,
        address trader,
        address receiver,
        uint256 amount
    ) external;

    // function arbitrage_trade() external;

    /// @return If an address is allowed to handle a order
    /// @param sender The sender address
    /// @param tokenId The orderID / tokenId
    function isAllowed(address sender, uint256 tokenId)
        external
        view
        returns (bool);

    /// @return The version of the vault implementation
    function implementationVersion() external view returns (uint16);

    /// @return The address of the vault implementation
    function implementationAddress() external view returns (address);

    /// @notice Returns the estimated profit for an arbitrage trade
    /// @param profitToken The token to take profit in
    /// @param maxAmountIn The maximum amount of `profitToken` to borrow
    /// @param maxPrice The maximum purchase price
    /// @return profitIn The amount to borrow of the `profitToken`
    /// @return profitOut The total amount to receive `profitToken`
    /// @return otherOut the amount of the other token of the vault to receive
    function arbitrageAmountsOut(
        address profitToken,
        uint256 maxAmountIn,
        uint256 maxPrice
    )
        external
        view
        returns (
            uint256 profitIn,
            uint256 profitOut,
            uint256 otherOut
        );

    /// @notice Buys from one side of the vault with borrowed funds and dumps on
    ///         the other side
    /// @param profitToken The token to take profit in
    /// @param maxBorrow The maximum amount of `profitToken` to borrow
    /// @param maxPrice The maximum purchase price
    /// @param receiver The receiver of the arbitrage profits
    /// @param deadline Validity deadline
    function arbitrageTrade(
        address profitToken,
        uint256 maxBorrow,
        uint256 maxPrice,
        address receiver,
        uint256 deadline
    ) external returns (uint256 profitAmount, uint256 otherAmount);
}
