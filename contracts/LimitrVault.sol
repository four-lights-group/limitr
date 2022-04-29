// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./libraries/DoubleLinkedList.sol";
import "./libraries/SortedDoubleLinkedList.sol";
import "./interfaces/ILimitrVault.sol";
import "./interfaces/ILimitrRegistry.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721Receiver.sol";

/// @dev trade handler
struct TradeHandler {
    uint256 amountIn;
    uint256 amountOut;
    uint256 availableAmountIn;
}

/// @dev trade handler methods
library TradeHandlerLib {
    function update(
        TradeHandler memory _trade,
        uint256 amountIn,
        uint256 amountOut
    ) internal pure {
        _trade.amountIn += amountIn;
        _trade.amountOut += amountOut;
        _trade.availableAmountIn -= amountIn;
    }
}

/// @author Limitr
/// @title Trade vault contract for Limitr
contract LimitrVault is ILimitrVault {
    using DoubleLinkedList for DLL;

    using SortedDoubleLinkedList for SDLL;

    using TradeHandlerLib for TradeHandler;

    /// @dev Order data
    struct Order {
        uint256 price;
        uint256 amount;
        address trader;
    }

    /// @notice Initialize the market. Must be called by the factory once at deployment time
    /// @param _token0 The first token of the pair
    /// @param _token1 The second token of the pair
    function initialize(address _token0, address _token1) external override {
        require(registry == address(0), "already initialized");
        require(_token0 != _token1, "base and counter tokens are the same");
        require(_token0 != address(0), "zero address not allowed");
        require(_token1 != address(0), "zero address not allowed");
        token0 = _token0;
        token1 = _token1;
        registry = msg.sender;
        _oneToken[_token0] = 10**IERC20(_token0).decimals();
        _oneToken[_token1] = 10**IERC20(_token1).decimals();
        feePercentage = 2 * 10**15;
    }

    /// @return The fee percentage represented as a value between 0 and 1 multiplied by 10^18
    uint256 public override feePercentage;

    /// @notice Set a new fee (must be smaller than the current, for the feeReceiverSetter only)
    ///         Emits a NewFeePercentage event
    /// @param newFeePercentage The new fee in the format describedin feePercentage
    function setFeePercentage(uint256 newFeePercentage)
        external
        override
        onlyAdmin
    {
        require(newFeePercentage < feePercentage, "Can only set a smaller fee");
        uint256 oldPercentage = feePercentage;
        feePercentage = newFeePercentage;
        emit NewFeePercentage(oldPercentage, newFeePercentage);
    }

    // factory and token addresses

    /// @return The registry address
    address public override registry;

    /// @return The first token of the pair
    address public override token0;

    /// @return The second token of the pair
    address public override token1;

    // price listing functions

    /// @return The first price on the order book for the provided token
    /// @param token Must be token0 or token1
    function firstPrice(address token) public view override returns (uint256) {
        return _prices[token].first();
    }

    /// @return The last price on the order book for the provided token
    /// @param token Must be token0 or token1
    function lastPrice(address token) public view override returns (uint256) {
        return _prices[token].last();
    }

    /// @return The previous price to the pointer for the provided token
    /// @param token Must be token0 or token1
    /// @param current The current price
    function previousPrice(address token, uint256 current)
        public
        view
        override
        returns (uint256)
    {
        return _prices[token].previous(current);
    }

    /// @return The next price to the current for the provided token
    /// @param token Must be token0 or token1
    /// @param current The current price
    function nextPrice(address token, uint256 current)
        public
        view
        override
        returns (uint256)
    {
        return _prices[token].next(current);
    }

    /// @return N prices after current for the provided token
    /// @param token Must be token0 or token1
    /// @param current The current price
    /// @param n The number of prices to return
    function prices(
        address token,
        uint256 current,
        uint256 n
    ) external view override returns (uint256[] memory) {
        SDLL storage priceList = _prices[token];
        uint256 c = current;
        uint256[] memory r = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            c = priceList.next(c);
            if (c == 0) {
                break;
            }
            r[i] = c;
        }
        return r;
    }

    /// @return n price pointers for the provided price for the provided token
    /// @param token Must be token0 or token1
    /// @param price The price to insert
    /// @param nPointers The number of pointers to return
    function pricePointers(
        address token,
        uint256 price,
        uint256 nPointers
    ) external view override returns (uint256[] memory) {
        uint256[] memory r = new uint256[](nPointers);
        uint256 c;
        SDLL storage priceList = _prices[token];
        if (_lastOrder[token][price] != 0) {
            c = price;
        } else {
            c = 0;
            while (c < price) {
                c = priceList.next(c);
                if (c == 0) {
                    break;
                }
            }
        }
        for (uint256 i = 0; i < nPointers; i++) {
            c = priceList.previous(c);
            if (c == 0) {
                break;
            }
            r[i] = c;
        }
        return r;
    }

    // orders listing functions

    /// @return The ID of the first order for the provided token
    /// @param token Must be token0 or token1
    function firstOrder(address token) public view override returns (uint256) {
        return _orders[token].first();
    }

    /// @return The ID of the last order for the provided token
    /// @param token Must be token0 or token1
    function lastOrder(address token) public view override returns (uint256) {
        return _orders[token].last();
    }

    /// @return The ID of the previous order for the provided token
    /// @param token Must be token0 or token1
    /// @param currentID Pointer to the current order
    function previousOrder(address token, uint256 currentID)
        public
        view
        override
        returns (uint256)
    {
        return _orders[token].previous(currentID);
    }

    /// @return The ID of the next order for the provided token
    /// @param token Must be token0 or token1
    /// @param currentID Pointer to the current order
    function nextOrder(address token, uint256 currentID)
        public
        view
        override
        returns (uint256)
    {
        return _orders[token].next(currentID);
    }

    /// @notice Returns n order IDs from the current for the provided token
    /// @param token Must be token0 or token1
    /// @param current The current ID
    /// @param n The number of IDs to return
    function orders(
        address token,
        uint256 current,
        uint256 n
    ) external view override returns (uint256[] memory) {
        uint256 c = current;
        uint256[] memory r = new uint256[](n);
        DLL storage orderList = _orders[token];
        for (uint256 i = 0; i < n; i++) {
            c = orderList.next(c);
            if (c == 0) {
                break;
            }
            r[i] = c;
        }
        return r;
    }

    /// @notice Returns the order data for n orders of the provided token, starting after current
    /// @param token Must be token0 or token1
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
        override
        returns (
            uint256[] memory id,
            uint256[] memory price,
            uint256[] memory amount,
            address[] memory trader
        )
    {
        uint256 c = current;
        id = new uint256[](n);
        price = new uint256[](n);
        amount = new uint256[](n);
        trader = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            c = _orders[token].next(c);
            if (c == 0) {
                break;
            }
            id[i] = c;
            Order memory t = orderInfo[token][c];
            price[i] = t.price;
            amount[i] = t.amount;
            trader[i] = t.trader;
        }
    }

    /// @return Returns the token for sale of the provided orderID
    /// @param orderID The order ID
    function orderToken(uint256 orderID)
        public
        view
        override
        returns (address)
    {
        return
            orderInfo[token0][orderID].trader != address(0) ? token0 : token1;
    }

    /// @notice Returns the order data
    mapping(address => mapping(uint256 => Order)) public override orderInfo;

    /// @return The last assigned order ID
    uint256 public override lastID;

    /// volume functions

    /// @return Return the available volume at a particular price, for the provided token
    mapping(address => mapping(uint256 => uint256))
        public
        override volumeByPrice;

    /// @notice Return the available volume until maxPrice
    /// @param token Must be token0 or token1
    /// @param current The current price
    /// @param n The number of prices to return
    /// @return price Array of prices
    /// @return volume Array of volumes
    function volume(
        address token,
        uint256 current,
        uint256 n
    )
        external
        view
        override
        returns (uint256[] memory price, uint256[] memory volume)
    {
        uint256 c = current;
        price = new uint256[](n);
        volume = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            c = _prices[token].next(c);
            if (c == 0) {
                break;
            }
            price[i] = c;
            volume[i] = volumeByPrice[token][c];
        }
    }

    /// @return The total volume available for the provided token
    mapping(address => uint256) public override totalVolume;

    // trader order listing functions

    /// @return The ID of the first order of the trader for the provided token
    /// @param token The token to list
    /// @param trader The trader
    function firstTraderOrder(address token, address trader)
        public
        view
        override
        returns (uint256)
    {
        return _tradersOrders[token][trader].first();
    }

    /// @return The ID of the last order of the trader
    /// @param token The token to list
    /// @param trader The trader
    function lastTraderOrder(address token, address trader)
        public
        view
        override
        returns (uint256)
    {
        return _tradersOrders[token][trader].last();
    }

    /// @return The ID of the previous order of the trader for the provided token
    /// @param token The token to list
    /// @param trader The trader
    /// @param currentID Pointer to a trade
    function previousTraderOrder(
        address token,
        address trader,
        uint256 currentID
    ) public view override returns (uint256) {
        return _tradersOrders[token][trader].previous(currentID);
    }

    /// @return The ID of the next order of the trader for the provided token
    /// @param token The token to list
    /// @param trader The trader
    /// @param currentID Pointer to a trade
    function nextTraderOrder(
        address token,
        address trader,
        uint256 currentID
    ) public view override returns (uint256) {
        return _tradersOrders[token][trader].next(currentID);
    }

    /// @notice Returns n trader order IDs from the current for the provided token
    /// @param token The token to list
    /// @param trader The trader
    /// @param current The current ID
    /// @param n The number of IDs to return
    function traderOrders(
        address token,
        address trader,
        uint256 current,
        uint256 n
    ) external view override returns (uint256[] memory) {
        uint256 c = current;
        uint256[] memory r = new uint256[](n);
        DLL storage traderOrderList = _tradersOrders[token][trader];
        for (uint256 i = 0; i < n; i++) {
            c = traderOrderList.next(c);
            if (c == 0) {
                break;
            }
            r[i] = c;
        }
        return r;
    }

    // fee calculation functions

    /// @return The amount corresponding to the fee from a given amount
    /// @param amount The traded amount
    function feeOf(uint256 amount) public view override returns (uint256) {
        if (feePercentage == 0 || amount == 0) {
            return 0;
        }
        return (amount * feePercentage) / 10**18;
    }

    /// @return The amount to collect as fee for the provided amount
    /// @param amount The amount traded
    function feeFor(uint256 amount) public view override returns (uint256) {
        if (feePercentage == 0 || amount == 0) {
            return 0;
        }
        return (amount * feePercentage) / (10**18 - feePercentage);
    }

    /// @return The amount available after collecting the fee
    /// @param amount The total amount
    function withoutFee(uint256 amount) public view override returns (uint256) {
        return amount - feeOf(amount);
    }

    /// @return The amount with added fee
    /// @param amount The amount without fee
    function withFee(uint256 amount) public view override returns (uint256) {
        return amount + feeFor(amount);
    }

    // trade amounts calculation functions

    /// @return The cost of buying the provided buyToken at the provided price. Fees not included
    /// @param buyToken The token to buy
    /// @param amountOut The amount of buyToken to buy
    /// @param price The buy price
    function costAtPrice(
        address buyToken,
        uint256 amountOut,
        uint256 price
    ) public view override returns (uint256) {
        if (price == 0 || amountOut == 0) {
            return 0;
        }
        return (price * amountOut) / _oneToken[buyToken];
    }

    /// @return The amount of tokens than can be purchased with a given amount at price
    ///         Fees not included.
    /// @param buyToken The token to buy
    /// @param amountIn The amount of sellToken to spend
    /// @param price The sell price
    function returnAtPrice(
        address buyToken,
        uint256 amountIn,
        uint256 price
    ) public view override returns (uint256) {
        if (price == 0 || amountIn == 0) {
            return 0;
        }
        return (_oneToken[buyToken] * amountIn) / price;
    }

    /// @notice Cost of buying (from the vault) up to maxAmountOut of the
    ///         provided token, at a maxPrice (maximum order price). Fees not included
    /// @param buyToken The token to buy
    /// @param maxAmountOut The maximum amount of buyToken to buy
    /// @param maxPrice The max price
    /// @return amountIn The cost
    /// @return amountOut The return
    function costAtMaxPrice(
        address buyToken,
        uint256 maxAmountOut,
        uint256 maxPrice
    ) external view override returns (uint256 amountIn, uint256 amountOut) {
        return
            _returnAtMaxPrice(
                buyToken,
                costAtPrice(buyToken, maxAmountOut, maxPrice),
                maxPrice
            );
    }

    /// @notice The amount of tokens that can be purchased (from the vault) with up to
    ///         maxAmountIn, at a maxPrice (maximum order price). Fees not included.
    /// @param buyToken The token to buy
    /// @param maxAmountIn The maximum amount of sellToken to sell
    /// @param maxPrice The max price
    /// @return amountIn The cost
    /// @return amountOut The return
    function returnAtMaxPrice(
        address buyToken,
        uint256 maxAmountIn,
        uint256 maxPrice
    ) external view override returns (uint256 amountIn, uint256 amountOut) {
        return _returnAtMaxPrice(buyToken, maxAmountIn, maxPrice);
    }

    function _returnAtMaxPrice(
        address buyToken,
        uint256 maxAmountIn,
        uint256 maxPrice
    ) internal view returns (uint256 amountIn, uint256 amountOut) {
        uint256 orderID = 0;
        Order memory _order;
        DLL storage orderList = _orders[buyToken];
        while (true) {
            orderID = orderList.next(orderID);
            if (orderID == 0) {
                break;
            }
            _order = orderInfo[buyToken][orderID];
            if (_order.trader == address(0)) {
                break;
            }
            if (_order.price > maxPrice) {
                break;
            }
            uint256 buyAmount = returnAtPrice(
                buyToken,
                maxAmountIn,
                _order.price
            );
            if (buyAmount > _order.amount) {
                buyAmount = _order.amount;
            }
            amountOut += buyAmount;
            uint256 price = costAtPrice(buyToken, buyAmount, _order.price);
            amountIn += price;
            maxAmountIn -= price;
            if (maxAmountIn == 0) {
                break;
            }
        }
    }

    /// @notice Cost of buying (from the vault) up to maxAmountOut of the
    ///         provided token, at avgPrice (average order price). Fees not included.
    /// @param buyToken The token to buy
    /// @param maxAmountOut The maximum amount of buyToken to buy
    /// @param avgPrice The max average price
    /// @return amountIn The cost
    /// @return amountOut The return
    function costAtAvgPrice(
        address buyToken,
        uint256 maxAmountOut,
        uint256 avgPrice
    ) external view override returns (uint256 amountIn, uint256 amountOut) {
        return
            _returnAtAvgPrice(
                buyToken,
                costAtPrice(buyToken, maxAmountOut, avgPrice),
                avgPrice
            );
    }

    /// @notice The amount of tokens that can be purchased (from the vault) with up to
    ///         maxAmountIn, at avgPrice (average order price). Fees not included
    /// @param buyToken The token to buy
    /// @param maxAmountIn The maximum amount of sellToken to sell
    /// @param avgPrice The max average price
    /// @return amountIn The cost
    /// @return amountOut The return
    function returnAtAvgPrice(
        address buyToken,
        uint256 maxAmountIn,
        uint256 avgPrice
    ) external view override returns (uint256 amountIn, uint256 amountOut) {
        return _returnAtAvgPrice(buyToken, maxAmountIn, avgPrice);
    }

    // order creation functions

    /// @notice Creates a new sell order using the provided pointer
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
    ) public override returns (uint256) {
        (uint256 orderID, bool created) = _newSellOrderWithPointer(
            sellToken,
            price,
            amount,
            trader,
            deadline,
            pointer
        );
        require(created, "can" "t create new order");
        return orderID;
    }

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
    ) public override returns (uint256) {
        (uint256 orderID, bool created) = _newSellOrderWithPointer(
            sellToken,
            price,
            amount,
            trader,
            deadline,
            0
        );
        require(created, "can" "t create new order");
        return orderID;
    }

    /// @notice Creates a new sell order using the provided pointers
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
    ) public override returns (uint256) {
        for (uint256 i = 0; i < pointers.length; i++) {
            (uint256 orderID, bool created) = _newSellOrderWithPointer(
                sellToken,
                price,
                amount,
                trader,
                deadline,
                pointers[i]
            );
            if (created) {
                return orderID;
            }
        }
        revert("can" "t create new order");
    }

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
    ) public override withinDeadline(deadline) senderAllowed(orderID) lock {
        address t = orderToken(orderID);
        Order memory _order = orderInfo[t][orderID];
        uint256 _amount = amount != 0 ? amount : _order.amount;
        _cancelOrder(t, orderID, amount);
        _withdrawToken(t, receiver, _amount);
    }

    // trading functions

    /// @notice Buys buyToken from the vault with a maximum price (per order),
    ///         spending up to maxAmountIn. This function includes the fee in the
    ///         limit set by maxAmountIn
    /// @param buyToken The token to buy
    /// @param maxPrice The price of the trade
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of buyToken received
    function buyAtMaxPrice(
        address buyToken,
        uint256 maxPrice,
        uint256 maxAmountIn,
        address receiver,
        uint256 deadline
    )
        public
        override
        withinDeadline(deadline)
        validToken(buyToken)
        lock
        returns (uint256, uint256)
    {
        TradeHandler memory trade = TradeHandler(0, 0, withoutFee(maxAmountIn));
        while (trade.availableAmountIn > 0) {
            // get the order ID
            uint256 orderID = _orders[buyToken].first();
            if (orderID == 0) {
                break;
            }
            // get the order
            Order memory _order = orderInfo[buyToken][orderID];
            // check price
            if (_order.price > maxPrice) {
                break;
            }
            // max amount of the base token that can be purchased with the
            uint256 buyAmount = returnAtPrice(
                buyToken,
                trade.availableAmountIn,
                _order.price
            );
            if (buyAmount == 0) {
                break;
            }
            if (buyAmount > _order.amount) {
                buyAmount = _order.amount;
            }
            uint256 cost = costAtPrice(buyToken, buyAmount, _order.price);
            if (cost > trade.availableAmountIn) {
                cost = trade.availableAmountIn;
                buyAmount = returnAtPrice(buyToken, cost, _order.price);
            }
            _order.amount -= buyAmount;
            _updateTraderBalance(
                buyToken == token0 ? token1 : token0,
                _order.trader,
                cost
            );
            _updateVolume(buyToken, _order.price, cost);
            _updateOrderList(buyToken, orderID, _order.amount);
            trade.update(cost, buyAmount);
            emit OrderTaken(buyToken, orderID, buyAmount, _order.price);
        }
        require(trade.amountIn > 0 && trade.amountOut > 0, "No trade");
        uint256 fee = feeFor(trade.amountIn);
        assert(trade.amountIn + fee <= maxAmountIn);
        address sellToken = buyToken == token0 ? token1 : token0;
        _depositToken(sellToken, msg.sender, trade.amountIn);
        _tokenTransferFrom(
            sellToken,
            msg.sender,
            ILimitrRegistry(registry).feeReceiver(),
            fee
        );
        _withdrawToken(buyToken, receiver, trade.amountOut);
        return (trade.amountIn + fee, trade.amountOut);
    }

    function _updateTraderBalance(
        address token,
        address owner,
        uint256 cost
    ) internal {
        traderBalance[token][owner] += cost;
    }

    function _updateVolume(
        address token,
        uint256 price,
        uint256 amount
    ) internal {
        volumeByPrice[token][price] -= amount;
        totalVolume[token] -= amount;
    }

    function _updateOrderList(
        address token,
        uint256 orderID,
        uint256 newAmount
    ) internal {
        if (newAmount == 0) {
            _removeOrder(token, orderID);
        } else {
            orderInfo[token][orderID].amount = newAmount;
        }
    }

    /// @notice Buys buyToken from the vault with an average price (total),
    ///         spending up to maxAmountIn. This function includes the fee in the
    ///         limit set by maxAmountIn
    /// @param avgPrice, The maximum average price
    /// @param maxAmountIn The maximum amount to spend
    /// @param receiver The receiver of the tokens
    /// @param deadline Validity deadline
    /// @return cost The amount spent
    /// @return received The amount of buyToken received
    function buyAtAvgPrice(
        address buyToken,
        uint256 avgPrice,
        uint256 maxAmountIn,
        address receiver,
        uint256 deadline
    )
        external
        override
        withinDeadline(deadline)
        validToken(buyToken)
        lock
        returns (uint256, uint256)
    {
        TradeHandler memory trade = TradeHandler(0, 0, withoutFee(maxAmountIn));
        while (trade.availableAmountIn > 0) {
            // get the order ID
            uint256 orderID = _orders[buyToken].first();
            if (orderID == 0) {
                break;
            }
            // get the order
            Order memory _order = orderInfo[buyToken][orderID];
            // max amount of the base token that can be purchased
            uint256 buyAmount = _maxAmountAvgPrice(
                buyToken,
                avgPrice,
                trade,
                _order.price
            );
            if (buyAmount == 0) {
                break;
            }
            if (buyAmount > _order.amount) {
                buyAmount = _order.amount;
            }
            uint256 cost = costAtPrice(buyToken, buyAmount, _order.price);
            if (cost > trade.availableAmountIn) {
                cost = trade.availableAmountIn;
                buyAmount = returnAtPrice(buyToken, cost, _order.price);
            }
            _order.amount -= buyAmount;
            _updateTraderBalance(
                buyToken == token0 ? token1 : token0,
                _order.trader,
                cost
            );
            _updateVolume(buyToken, _order.price, cost);
            _updateOrderList(buyToken, orderID, _order.amount);
            trade.update(cost, buyAmount);
            emit OrderTaken(buyToken, orderID, buyAmount, _order.price);
        }
        require(trade.amountIn > 0 && trade.amountOut > 0, "No trade");
        uint256 fee = feeFor(trade.amountIn);
        assert(trade.amountIn + fee <= maxAmountIn);
        address sellToken = buyToken == token0 ? token1 : token0;
        _depositToken(sellToken, msg.sender, trade.amountIn);
        _tokenTransferFrom(
            sellToken,
            msg.sender,
            ILimitrRegistry(registry).feeReceiver(),
            fee
        );
        _withdrawToken(buyToken, receiver, trade.amountOut);
        return (trade.amountIn + fee, trade.amountOut);
    }

    // ERC165

    function supportsInterface(bytes4 interfaceId)
        external
        pure
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(ILimitrVault).interfaceId;
    }

    // ERC721

    /// @return The number of tokens/orders owned by owner
    mapping(address => uint256) public override balanceOf;

    /// @return If the operator is allowed to manage all tokens/orders of owner
    mapping(address => mapping(address => bool))
        public
        override isApprovedForAll;

    /// @notice Returns the owner of a token/order. The ID must be valid
    /// @param tokenId The token/order ID
    /// @return owner The owner of a token/order. The ID must be valid
    function ownerOf(uint256 tokenId)
        public
        view
        override
        ERC721tokenMustExist(tokenId)
        returns (address)
    {
        address t = orderInfo[token0][tokenId].trader;
        if (t != address(0)) {
            return t;
        }
        return orderInfo[token1][tokenId].trader;
    }

    /// @notice Approves an account to transfer the token/order with the given ID.
    ///         The token/order must exists
    /// @param to The address of the account to approve
    /// @param tokenId the token/order
    function approve(address to, uint256 tokenId) public override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        bool allowed = msg.sender == owner ||
            isApprovedForAll[owner][msg.sender];
        require(allowed, "not the owner or operator");
        _ERC721Approve(owner, to, tokenId);
    }

    /// @notice Returns the address approved to transfer the token/order with the given ID
    ///         The token/order must exists
    /// @param tokenId the token/order
    /// @return The address approved to transfer the token/order with the given ID
    function getApproved(uint256 tokenId)
        public
        view
        override
        ERC721tokenMustExist(tokenId)
        returns (address)
    {
        return _approvals[tokenId];
    }

    /// @notice Approves or removes the operator for the caller tokens/orders
    /// @param operator The operator to be approved/removed
    /// @param approved Set true to approve, false to remove
    function setApprovalForAll(address operator, bool approved)
        public
        override
    {
        require(msg.sender != operator, "can" "t approve yourself");
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Transfers the ownership of the token/order. Can be called by the owner
    ///         or approved operators
    /// @param from The token/order owner
    /// @param to The new owner
    /// @param tokenId The token/order ID to transfer
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        _ERC721Transfer(from, to, tokenId);
    }

    /// @notice Safely transfers the token/order. It checks contract recipients are aware
    ///         of the ERC721 protocol to prevent tokens from being forever locked.
    /// @param from The token/order owner
    /// @param to the new owner
    /// @param tokenId The token/order ID to transfer
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /// @notice Safely transfers the token/order. It checks contract recipients are aware
    ///         of the ERC721 protocol to prevent tokens from being forever locked.
    /// @param from The token/order owner
    /// @param to the new owner
    /// @param tokenId The token/order ID to transfer
    /// @param _data The data to be passed to the onERC721Received() call
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        _ERC721SafeTransfer(from, to, tokenId, _data);
    }

    /// @return If an address is allowed to handle a order
    /// @param sender The sender address
    /// @param tokenId The orderID / tokenId
    function isAllowed(address sender, uint256 tokenId)
        public
        view
        override
        returns (bool)
    {
        address owner = ownerOf(tokenId);
        return
            sender == owner ||
            isApprovedForAll[owner][sender] ||
            sender == _approvals[tokenId] ||
            sender == ILimitrRegistry(registry).router();
    }

    // trader balances

    /// @return The trader balance available to withdraw
    mapping(address => mapping(address => uint256))
        public
        override traderBalance;

    /// @notice Withdraw trader balance
    /// @param token Must be token0 or token1
    /// @param to The receiver address
    /// @param amount The amount to withdraw
    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external override lock {
        _withdraw(token, msg.sender, to, amount);
    }

    /// @notice Withdraw on behalf of a trader. Can only be called by the router
    /// @param token Must be token0 or token1
    /// @param trader The trader to handle
    /// @param amount The amount to withdraw
    function withdrawFor(
        address token,
        address trader,
        uint256 amount
    ) external override {
        address router = ILimitrRegistry(registry).router();
        require(msg.sender == router, "not the router");
        _withdraw(token, trader, router, amount);
    }

    /// @return The version of the vault implementation
    function implementationVersion() external pure override returns (uint16) {
        return 1;
    }

    /// @return The address of the vault implementation
    function implementationAddress() external view override returns (address) {
        bytes memory code = address(this).code;
        require(code.length == 51, "expecting 51 bytes of code");
        uint160 r;
        for (uint256 i = 11; i < 31; i++) {
            r = (r << 8) | uint8(code[i]);
        }
        return address(r);
    }

    // modifiers

    modifier validToken(address token) {
        require(token == token0 || token == token1, "invalid token");
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == ILimitrRegistry(registry).admin(),
            "Only for the admin"
        );
        _;
    }

    modifier withinDeadline(uint256 deadline) {
        if (deadline > 0) {
            require(block.timestamp <= deadline, "Past the deadline");
        }
        _;
    }

    bool internal _locked;

    modifier lock() {
        require(!_locked, "already locked");
        _locked = true;
        _;
        _locked = false;
    }

    modifier postExecBalanceCheck(address token) {
        _;
        require(
            IERC20(token).balanceOf(address(this)) >= _expectedBalance[token],
            "ERROR: Deflationary token"
        );
    }

    modifier senderAllowed(uint256 tokenId) {
        require(
            isAllowed(msg.sender, tokenId),
            "not the owner, approved or operator"
        );
        _;
    }

    modifier ERC721tokenMustExist(uint256 tokenId) {
        require(
            orderToken(tokenId) != address(0),
            "ERC721: token does not exist"
        );
        _;
    }

    // internal variables and methods

    mapping(address => uint256) internal _oneToken;

    mapping(address => uint256) internal _expectedBalance;

    mapping(address => mapping(uint256 => uint256)) internal _lastOrder;

    mapping(address => SDLL) internal _prices;

    mapping(address => DLL) internal _orders;

    mapping(address => mapping(address => DLL)) internal _tradersOrders;

    mapping(uint256 => address) private _approvals;

    function _withdraw(
        address token,
        address sender,
        address to,
        uint256 amount
    ) internal {
        require(
            traderBalance[token][sender] >= amount,
            "can"
            "t withdraw(): not enough balance"
        );
        traderBalance[token][sender] -= amount;
        _withdrawToken(token, to, amount);
    }

    function _tokenTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool ok = IERC20(token).transfer(to, amount);
        require(ok, "can" "t transfer()");
    }

    function _tokenTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        require(ok, "can" "t transferFrom()");
    }

    /// @dev withdraw a token, accounting for the balance
    function _withdrawToken(
        address token,
        address to,
        uint256 amount
    ) internal postExecBalanceCheck(token) {
        _expectedBalance[token] -= amount;
        _tokenTransfer(token, to, amount);
    }

    /// @dev take a token deposit from a user
    function _depositToken(
        address token,
        address from,
        uint256 amount
    ) internal postExecBalanceCheck(token) {
        _expectedBalance[token] += amount;
        _tokenTransferFrom(token, from, address(this), amount);
    }

    /// @dev increment lastID and return it
    function _nextID() internal returns (uint256) {
        lastID++;
        return lastID;
    }

    /// @dev Creates a new order using the provided pointer
    /// @param sellToken The token to sell
    /// @param price The sell price
    /// @param amount The amount to trade
    /// @param trader The owner of the order
    /// @param deadline Validity deadline
    /// @return orderID The order ID
    /// @return created True on success
    function _newSellOrderWithPointer(
        address sellToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 deadline,
        uint256 pointer
    )
        internal
        withinDeadline(deadline)
        validToken(sellToken)
        lock
        returns (uint256 orderID, bool created)
    {
        (orderID, created) = _createNewOrder(
            sellToken,
            price,
            amount,
            trader,
            pointer
        );
        if (!created) {
            return (0, false);
        }
        _depositToken(sellToken, msg.sender, amount);
        emit NewSellOrder(sellToken, orderID, trader, price, amount);
    }

    function _createNewOrder(
        address sellToken,
        uint256 price,
        uint256 amount,
        address trader,
        uint256 pointer
    ) internal returns (uint256, bool) {
        require(trader != address(0), "zero address not allowed");
        require(amount > 0, "zero amount not allowed");
        require(price > 0, "zero price not allowed");
        // validate pointer
        if (pointer != 0 && _lastOrder[sellToken][pointer] == 0) {
            return (0, false);
        }
        // save the order
        uint256 orderID = _nextID();
        orderInfo[sellToken][orderID] = Order(price, amount, trader);
        // insert order
        if (!_insertOrder(sellToken, orderID, price, pointer)) {
            return (0, false);
        }
        // insert order in the trader's orders
        _tradersOrders[sellToken][trader].insertEnd(orderID);
        balanceOf[trader] += 1;
        emit Transfer(address(0), trader, orderID);
        // update the volume by price
        volumeByPrice[sellToken][price] += amount;
        totalVolume[sellToken] += amount;
        return (orderID, true);
    }

    function _insertOrder(
        address sellToken,
        uint256 orderID,
        uint256 price,
        uint256 pointer
    ) internal returns (bool) {
        mapping(uint256 => uint256) storage _last = _lastOrder[sellToken];
        uint256 _prevID = _last[price];
        if (_prevID == 0) {
            if (pointer != 0 && _last[pointer] == 0) {
                return false;
            }
            SDLL storage priceList = _prices[sellToken];
            if (!priceList.insertWithPointer(price, pointer)) {
                return false;
            }
            _prevID = _last[priceList.previous(price)];
        }
        _orders[sellToken].insertAfter(orderID, _prevID);
        _last[price] = orderID;
        return true;
    }

    function _cancelOrder(
        address sellToken,
        uint256 orderID,
        uint256 amount
    ) internal {
        Order memory _order = orderInfo[sellToken][orderID];
        require(
            _order.amount >= amount,
            "can"
            "t cancel a bigger amount than the order size"
        );
        uint256 _amount = amount != 0 ? amount : _order.amount;
        uint256 remAmount = _order.amount - _amount;
        if (remAmount == 0) {
            _removeOrder(sellToken, orderID);
        } else {
            orderInfo[sellToken][orderID].amount = remAmount;
        }
        volumeByPrice[sellToken][_order.price] -= _amount;
        totalVolume[sellToken] -= _amount;
        emit OrderCanceled(sellToken, orderID, _amount);
    }

    /// @dev remove an order
    function _removeOrder(address sellToken, uint256 orderID) internal {
        uint256 orderPrice = orderInfo[sellToken][orderID].price;
        address orderTrader = orderInfo[sellToken][orderID].trader;
        DLL storage orderList = _orders[sellToken];
        uint256 _prevID = orderList.previous(orderID);
        bool prevPriceNotEqual = orderPrice !=
            orderInfo[sellToken][_prevID].price;
        bool onlyOrderAtPrice = prevPriceNotEqual &&
            orderPrice != orderInfo[sellToken][orderList.next(orderID)].price;
        delete orderInfo[sellToken][orderID];
        orderList.remove(orderID);
        mapping(uint256 => uint256) storage _last = _lastOrder[sellToken];
        if (_last[orderPrice] == orderID) {
            if (prevPriceNotEqual) {
                delete _last[orderPrice];
            } else {
                _last[orderPrice] = _prevID;
            }
        }
        if (onlyOrderAtPrice) {
            _prices[sellToken].remove(orderPrice);
        }
        _tradersOrders[sellToken][orderTrader].remove(orderID);
        balanceOf[orderTrader] -= 1;
        emit Transfer(orderTrader, address(0), orderID);
    }

    // /// @dev trade the first order at an average price
    // function _tradeFirstOrderAvgPrice(
    //     address buyToken,
    //     uint256 avgPrice,
    //     TradeHandler memory trade
    // ) internal returns (bool) {
    //     // get the order ID
    //     uint256 orderID = _orders[buyToken].first();
    //     if (orderID == 0) {
    //         return false;
    //     }
    //     // get the order
    //     Order memory _order = orderInfo[buyToken][orderID];
    //     // // max amount of the base token that can be purchased with the
    //     // // remaining amount of counter token
    //     // uint256 maxAmount = _maxAmountAvgPrice(
    //     //     buyToken,
    //     //     avgPrice,
    //     //     trade,
    //     //     _order.price
    //     // );
    //     // if (maxAmount == 0) {
    //     //     return false;
    //     // }
    //     // return _tradeOrder(buyToken, orderID, _order, trade, maxAmount);
    // }

    function _maxAmountAvgPrice(
        address buyToken,
        uint256 avgPrice,
        TradeHandler memory trade,
        uint256 orderPrice
    ) internal view returns (uint256) {
        if (trade.amountOut == 0 || trade.amountIn == 0) {
            if (orderPrice + feeFor(orderPrice) <= avgPrice) {
                return
                    returnAtPrice(
                        buyToken,
                        trade.availableAmountIn,
                        orderPrice
                    );
            }
            return 0;
        }
        uint256 a = 10**18 * _oneToken[buyToken] * trade.amountIn;
        uint256 remPercentage = 10**18 - feePercentage;
        uint256 t = remPercentage * avgPrice * trade.amountOut;
        a = a > t ? a - t : t - a;
        uint256 b = 10**18 * orderPrice;
        t = remPercentage * avgPrice;
        b = b > t ? b - t : t - b;
        return a / b;
    }

    function _ERC721SafeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _ERC721Transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _ERC721Transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal lock ERC721tokenMustExist(tokenId) senderAllowed(tokenId) {
        require(
            ownerOf(tokenId) == from,
            "ERC721: transfer of token that is not own"
        );
        require(to != address(0), "ERC721: transfer to the zero address");
        _approvals[tokenId] = address(0);
        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        address t = orderToken(tokenId);
        orderInfo[t][tokenId].trader = to;
        _tradersOrders[t][from].remove(tokenId);
        _tradersOrders[t][to].insertEnd(tokenId);
        emit Transfer(from, to, tokenId);
    }

    function _ERC721Approve(
        address owner,
        address to,
        uint256 tokenId
    ) internal {
        _approvals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.code.length == 0) {
            return true;
        }
        try
            IERC721Receiver(to).onERC721Received(
                msg.sender,
                from,
                tokenId,
                _data
            )
        returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }

    function _returnAtAvgPrice(
        address buyToken,
        uint256 maxAmountIn,
        uint256 avgPrice
    ) internal view returns (uint256 amountIn, uint256 amountOut) {
        uint256 orderID = 0;
        Order memory _order;
        DLL storage orderList = _orders[buyToken];
        TradeHandler memory trade = TradeHandler(0, 0, maxAmountIn);
        while (true) {
            orderID = orderList.next(orderID);
            if (orderID == 0) {
                break;
            }
            _order = orderInfo[buyToken][orderID];
            uint256 buyAmount = _maxAmountAvgPrice(
                buyToken,
                avgPrice,
                trade,
                _order.price
            );
            if (buyAmount == 0) {
                break;
            }
            if (buyAmount > _order.amount) {
                buyAmount = _order.amount;
            }
            uint256 cost = costAtPrice(buyToken, buyAmount, _order.price);
            if (cost > trade.availableAmountIn) {
                buyAmount = returnAtPrice(
                    buyToken,
                    trade.availableAmountIn,
                    _order.price
                );
                if (buyAmount == 0) {
                    break;
                }
                cost = costAtPrice(buyToken, buyAmount, _order.price);
            }
            trade.update(cost, buyAmount);
            if (trade.availableAmountIn == 0) {
                break;
            }
        }
        return (trade.amountIn, trade.amountOut);
    }
}
