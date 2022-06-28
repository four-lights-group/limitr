// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./libraries/DoubleLinkedList.sol";
import "./libraries/SortedDoubleLinkedList.sol";
import "./interfaces/ILimitrVault.sol";
import "./interfaces/ILimitrRegistry.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721Receiver.sol";

/// @dev Order data
struct Order {
    uint256 price;
    uint256 amount;
    address trader;
}

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

    /// @notice Initialize the market. Must be called by the factory once at deployment time
    /// @param _token0 The first token of the pair
    /// @param _token1 The second token of the pair
    function initialize(address _token0, address _token1) external override {
        require(registry == address(0), "LimitrVault: already initialized");
        require(
            _token0 != _token1,
            "LimitrVault: base and counter tokens are the same"
        );
        require(_token0 != address(0), "LimitrVault: zero address not allowed");
        require(_token1 != address(0), "LimitrVault: zero address not allowed");
        token0 = _token0;
        token1 = _token1;
        registry = msg.sender;
        _oneToken[_token0] = 10**IERC20(_token0).decimals();
        _oneToken[_token1] = 10**IERC20(_token1).decimals();
        feePercentage = 2 * 10**15; // 0.2 %
    }

    /// @return The fee percentage represented as a value between 0 and 10^18
    uint256 public override feePercentage;

    /// @notice Set a new fee (must be smaller than the current, for the `feeReceiverSetter` only)
    ///         Emits a NewFeePercentage event
    /// @param newFeePercentage The new fee in the format described in `feePercentage`
    function setFeePercentage(uint256 newFeePercentage)
        external
        override
        onlyAdmin
    {
        require(
            newFeePercentage < feePercentage,
            "LimitrVault: can only set a smaller fee"
        );
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

    /// @return The first price on the order book for the provided `token`
    /// @param token Must be `token0` or `token1`
    function firstPrice(address token) public view override returns (uint256) {
        return _prices[token].first();
    }

    /// @return The last price on the order book for the provided `token`
    /// @param token Must be `token0` or `token1`
    function lastPrice(address token) public view override returns (uint256) {
        return _prices[token].last();
    }

    /// @return The previous price to the pointer for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param current The current price
    function previousPrice(address token, uint256 current)
        public
        view
        override
        returns (uint256)
    {
        return _prices[token].previous(current);
    }

    /// @return The next price to the current for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param current The current price
    function nextPrice(address token, uint256 current)
        public
        view
        override
        returns (uint256)
    {
        return _prices[token].next(current);
    }

    /// @return N prices after current for the provided `token`
    /// @param token Must be `token0` or `token1`
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

    /// @return n price pointers for the provided price for the provided `token`
    /// @param token Must be `token0` or `token1`
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

    /// @return The ID of the first order for the provided `token`
    /// @param token Must be `token0` or `token1`
    function firstOrder(address token) public view override returns (uint256) {
        return _orders[token].first();
    }

    /// @return The ID of the last order for the provided `token`
    /// @param token Must be `token0` or `token1`
    function lastOrder(address token) public view override returns (uint256) {
        return _orders[token].last();
    }

    /// @return The ID of the previous order for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param currentID Pointer to the current order
    function previousOrder(address token, uint256 currentID)
        public
        view
        override
        returns (uint256)
    {
        return _orders[token].previous(currentID);
    }

    /// @return The ID of the next order for the provided `token`
    /// @param token Must be `token0` or `token1`
    /// @param currentID Pointer to the current order
    function nextOrder(address token, uint256 currentID)
        public
        view
        override
        returns (uint256)
    {
        return _orders[token].next(currentID);
    }

    /// @notice Returns n order IDs from the current for the provided `token`
    /// @param token Must be `token0` or `token1`
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

    /// @return Returns the token for sale of the provided `orderID`
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

    /// liquidity functions

    /// @return Return the available liquidity at a particular price, for the provided `token`
    mapping(address => mapping(uint256 => uint256))
        public
        override liquidityByPrice;

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
        override
        returns (uint256[] memory price, uint256[] memory priceLiquidity)
    {
        uint256 c = current;
        price = new uint256[](n);
        priceLiquidity = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            c = _prices[token].next(c);
            if (c == 0) {
                break;
            }
            price[i] = c;
            priceLiquidity[i] = liquidityByPrice[token][c];
        }
    }

    /// @return The total liquidity available for the provided `token`
    mapping(address => uint256) public override totalLiquidity;

    // trader order listing functions

    /// @return The ID of the first order of the `trader` for the provided `token`
    /// @param token The token to list
    /// @param trader The trader
    function firstTraderOrder(address token, address trader)
        public
        view
        override
        returns (uint256)
    {
        return _traderOrders[token][trader].first();
    }

    /// @return The ID of the last order of the `trader` for the provided `token`
    /// @param token The token to list
    /// @param trader The trader
    function lastTraderOrder(address token, address trader)
        public
        view
        override
        returns (uint256)
    {
        return _traderOrders[token][trader].last();
    }

    /// @return The ID of the previous order of the `trader` for the provided `token`
    /// @param token The token to list
    /// @param trader The trader
    /// @param currentID Pointer to a trade
    function previousTraderOrder(
        address token,
        address trader,
        uint256 currentID
    ) public view override returns (uint256) {
        return _traderOrders[token][trader].previous(currentID);
    }

    /// @return The ID of the next order of the `trader` for the provided `token`
    /// @param token The token to list
    /// @param trader The trader
    /// @param currentID Pointer to a trade
    function nextTraderOrder(
        address token,
        address trader,
        uint256 currentID
    ) public view override returns (uint256) {
        return _traderOrders[token][trader].next(currentID);
    }

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
    ) external view override returns (uint256[] memory) {
        uint256 c = current;
        uint256[] memory r = new uint256[](n);
        DLL storage traderOrderList = _traderOrders[token][trader];
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

    /// @return The amount corresponding to the fee from a provided `amount`
    /// @param amount The traded amount
    function feeOf(uint256 amount) public view override returns (uint256) {
        if (feePercentage == 0 || amount == 0) {
            return 0;
        }
        return (amount * feePercentage) / 10**18;
    }

    /// @return The amount to collect as fee for the provided `amount`
    /// @param amount The amount traded
    function feeFor(uint256 amount) public view override returns (uint256) {
        if (feePercentage == 0 || amount == 0) {
            return 0;
        }
        return (amount * feePercentage) / (10**18 - feePercentage);
    }

    /// @return The amount available after collecting the fee from the provided `amount`
    /// @param amount The total amount
    function withoutFee(uint256 amount) public view override returns (uint256) {
        return amount - feeOf(amount);
    }

    /// @return The provided `amount` with added fee
    /// @param amount The amount without fee
    function withFee(uint256 amount) public view override returns (uint256) {
        return amount + feeFor(amount);
    }

    // trade amounts calculation functions

    /// @return The cost of buying `buyToken` at the provided `price`. Fees not included
    /// @param buyToken The token to buy
    /// @param amountOut The return
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

    /// @return The amount of `buyToken` than can be purchased with the provided
    ///         `amount` at `price`. Fees not included.
    /// @param buyToken The token to buy
    /// @param amountIn The cost
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
    ) public view override returns (uint256 amountIn, uint256 amountOut) {
        return
            _returnAtMaxPrice(
                buyToken,
                costAtPrice(buyToken, maxAmountOut, maxPrice),
                maxPrice
            );
    }

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
    ) public view override returns (uint256 amountIn, uint256 amountOut) {
        return _returnAtMaxPrice(buyToken, maxAmountIn, maxPrice);
    }

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
    ) external view override returns (uint256 amountIn, uint256 amountOut) {
        return
            _returnAtAvgPrice(
                buyToken,
                costAtPrice(buyToken, maxAmountOut, avgPrice),
                avgPrice
            );
    }

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
    ) external view override returns (uint256 amountIn, uint256 amountOut) {
        return _returnAtAvgPrice(buyToken, maxAmountIn, avgPrice);
    }

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
    ) public override returns (uint256) {
        (uint256 orderID, bool created) = _newSellOrderWithPointer(
            sellToken,
            price,
            amount,
            trader,
            deadline,
            0
        );
        require(created, "LimitrVault: can't create new order");
        return orderID;
    }

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
    ) public override returns (uint256) {
        (uint256 orderID, bool created) = _newSellOrderWithPointer(
            sellToken,
            price,
            amount,
            trader,
            deadline,
            pointer
        );
        require(created, "LimitrVault: can't create new order");
        return orderID;
    }

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
        revert("LimitrVault: can't create new order");
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
    )
        public
        override
        withinDeadline(deadline)
        validToken(buyToken)
        lock
        returns (uint256, uint256)
    {
        return
            _trade(
                buyToken,
                maxPrice,
                maxAmountIn,
                receiver,
                _getTradeAmountsMaxPrice,
                _postTrade
            );
    }

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
    )
        external
        override
        withinDeadline(deadline)
        validToken(buyToken)
        lock
        returns (uint256, uint256)
    {
        return
            _trade(
                buyToken,
                avgPrice,
                maxAmountIn,
                receiver,
                _getTradeAmountsAvgPrice,
                _postTrade
            );
    }

    // trader balances

    /// @return The trader balance available to withdraw
    mapping(address => mapping(address => uint256))
        public
        override traderBalance;

    /// @notice Withdraw trader balance
    /// @param token Must be `token0` or `token1`
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
    /// @param token Must be `token0` or `token1`
    /// @param trader The trader to handle
    /// @param receiver The receiver of the tokens
    /// @param amount The amount to withdraw
    function withdrawFor(
        address token,
        address trader,
        address receiver,
        uint256 amount
    ) external override {
        address router = ILimitrRegistry(registry).router();
        require(msg.sender == router, "LimitrVault: not the router");
        _withdraw(token, trader, receiver, amount);
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

    /// @return The version of the vault implementation
    function implementationVersion() external pure override returns (uint16) {
        return 1;
    }

    /// @return The address of the vault implementation
    function implementationAddress() external view override returns (address) {
        bytes memory code = address(this).code;
        require(code.length == 51, "LimitrVault: expecting 51 bytes of code");
        uint160 r;
        for (uint256 i = 11; i < 31; i++) {
            r = (r << 8) | uint8(code[i]);
        }
        return address(r);
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
        ERC721TokenMustExist(tokenId)
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
        require(allowed, "ERC721: not the owner or operator");
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
        ERC721TokenMustExist(tokenId)
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
        require(msg.sender != operator, "ERC721: can't approve yourself");
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
        override
        validToken(profitToken)
        returns (
            uint256 profitIn,
            uint256 profitOut,
            uint256 otherOut
        )
    {
        address other = _otherToken(profitToken);
        uint256 buyOut;
        (profitIn, buyOut) = _returnAtMaxPrice(
            other,
            withoutFee(maxAmountIn),
            maxPrice != 0 ? maxPrice : _prices[other].last()
        );
        profitIn = withFee(profitIn);
        uint256 dumpIn;
        (dumpIn, profitOut) = _returnAtMaxPrice(
            profitToken,
            withoutFee(buyOut),
            _prices[profitToken].last()
        );
        dumpIn = withFee(dumpIn);
        otherOut = buyOut - dumpIn;
    }

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
    )
        external
        override
        withinDeadline(deadline)
        validToken(profitToken)
        lock
        returns (uint256 profitAmount, uint256 otherAmount)
    {
        address otherToken = _otherToken(profitToken);
        // borrow borrowedProfitIn and buy otherOut with it
        uint256 p = maxPrice != 0 ? maxPrice : _prices[otherToken].last();
        (uint256 borrowedProfitIn, uint256 otherOut) = _trade(
            otherToken,
            p,
            maxBorrow,
            receiver,
            _getTradeAmountsMaxPrice,
            _postBorrowTrade
        );
        // borrow borrowedOtherIn and buy profitOut with it
        p = _prices[profitToken].last();
        (uint256 borrowedOtherIn, uint256 profitOut) = _trade(
            profitToken,
            p,
            otherOut,
            receiver,
            _getTradeAmountsMaxPrice,
            _postBorrowTrade
        );
        require(
            profitOut > borrowedProfitIn,
            "LimitrVault: no arbitrage profit"
        );
        profitAmount = profitOut - borrowedProfitIn;
        otherAmount = otherOut - borrowedOtherIn;
        _withdrawToken(profitToken, receiver, profitAmount);
        _withdrawToken(otherToken, receiver, otherAmount);
        emit ArbitrageProfitTaken(
            profitToken,
            profitAmount,
            otherAmount,
            receiver
        );
    }

    // modifiers

    modifier validToken(address token) {
        require(
            token == token0 || token == token1,
            "LimitrVault: invalid token"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == ILimitrRegistry(registry).admin(),
            "LimitrVault: only for the admin"
        );
        _;
    }

    modifier withinDeadline(uint256 deadline) {
        if (deadline > 0) {
            require(
                block.timestamp <= deadline,
                "LimitrVault: past the deadline"
            );
        }
        _;
    }

    bool internal _locked;

    modifier lock() {
        require(!_locked, "LimitrVault: already locked");
        _locked = true;
        _;
        _locked = false;
    }

    modifier postExecBalanceCheck(address token) {
        _;
        require(
            IERC20(token).balanceOf(address(this)) >= _expectedBalance[token],
            "LimitrVault:  Deflationary token"
        );
    }

    modifier senderAllowed(uint256 tokenId) {
        require(
            isAllowed(msg.sender, tokenId),
            "ERC721: not the owner, approved or operator"
        );
        _;
    }

    modifier ERC721TokenMustExist(uint256 tokenId) {
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

    mapping(address => mapping(address => DLL)) internal _traderOrders;

    mapping(uint256 => address) private _approvals;

    function _withdraw(
        address token,
        address sender,
        address to,
        uint256 amount
    ) internal {
        require(
            traderBalance[token][sender] >= amount,
            "LimitrVault: can't withdraw(): not enough balance"
        );
        if (amount == 0) {
            amount = traderBalance[token][sender];
        }
        traderBalance[token][sender] -= amount;
        _withdrawToken(token, to, amount);
        emit TokenWithdraw(token,sender, to, amount);
    }

    function _tokenTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool ok = IERC20(token).transfer(to, amount);
        require(ok, "LimitrVault: can't transfer()");
    }

    function _tokenTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool ok = IERC20(token).transferFrom(from, to, amount);
        require(ok, "LimitrVault: can't transferFrom()");
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
        require(trader != address(0), "LimitrVault: zero address not allowed");
        require(amount > 0, "LimitrVault: zero amount not allowed");
        require(price > 0, "LimitrVault: zero price not allowed");
        // validate pointer
        if (pointer != 0 && _lastOrder[sellToken][pointer] == 0) {
            return (0, false);
        }
        // save the order
        uint256 orderID = _nextID();
        orderInfo[sellToken][orderID] = Order(price, amount, trader);
        // insert order into the order list and insert the price in the
        // price list if necessary
        if (!_insertOrder(sellToken, orderID, price, pointer)) {
            return (0, false);
        }
        // insert order in the trader orders
        _traderOrders[sellToken][trader].insertEnd(orderID);
        // update erc721 balance
        balanceOf[trader] += 1;
        emit Transfer(address(0), trader, orderID);
        // update the liquidity info
        liquidityByPrice[sellToken][price] += amount;
        totalLiquidity[sellToken] += amount;
        return (orderID, true);
    }

    function _insertOrder(
        address sellToken,
        uint256 orderID,
        uint256 price,
        uint256 pointer
    ) internal returns (bool) {
        mapping(uint256 => uint256) storage _last = _lastOrder[sellToken];
        // the insert point is after the last order at the same price
        uint256 _prevID = _last[price];
        if (_prevID == 0) {
            // price doesn't exist. insert it
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
        // can only cancel up to the amount of the order
        require(
            _order.amount >= amount,
            "LimitrVault: can't cancel a bigger amount than the order size"
        );
        // 0 means full amount
        uint256 _amount = amount != 0 ? amount : _order.amount;
        uint256 remAmount = _order.amount - _amount;
        if (remAmount == 0) {
            // remove the order from the list. remove the price also if no
            // other order exists at the same price
            _removeOrder(sellToken, orderID);
        } else {
            // update the available amount
            orderInfo[sellToken][orderID].amount = remAmount;
        }
        // update the available liquidity info
        liquidityByPrice[sellToken][_order.price] -= _amount;
        totalLiquidity[sellToken] -= _amount;
        emit OrderCanceled(sellToken, orderID, _amount);
    }

    /// @dev remove an order
    function _removeOrder(address sellToken, uint256 orderID) internal {
        uint256 orderPrice = orderInfo[sellToken][orderID].price;
        address orderTrader = orderInfo[sellToken][orderID].trader;
        DLL storage orderList = _orders[sellToken];
        // find previous order
        uint256 _prevID = orderList.previous(orderID);
        // is the previous order at the same price?
        bool prevPriceNotEqual = orderPrice !=
            orderInfo[sellToken][_prevID].price;
        // single order at the price
        bool onlyOrderAtPrice = prevPriceNotEqual &&
            orderPrice != orderInfo[sellToken][orderList.next(orderID)].price;
        // delete the order and remove it from the list
        delete orderInfo[sellToken][orderID];
        orderList.remove(orderID);
        // update _last
        mapping(uint256 => uint256) storage _last = _lastOrder[sellToken];
        if (_last[orderPrice] == orderID) {
            if (prevPriceNotEqual) {
                delete _last[orderPrice];
            } else {
                _last[orderPrice] = _prevID;
            }
        }
        if (onlyOrderAtPrice) {
            // remove price
            _prices[sellToken].remove(orderPrice);
        }
        // update trader orders and ERC721 balance
        _traderOrders[sellToken][orderTrader].remove(orderID);
        balanceOf[orderTrader] -= 1;
        emit Transfer(orderTrader, address(0), orderID);
    }

    /// @dev The maximum amount that can be purchased of `buyToken` at `avgPrice`
    ///      accounting for the current `trade` at a particular `orderPrice`
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
        // avoid converting to signed int
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
    ) internal lock ERC721TokenMustExist(tokenId) senderAllowed(tokenId) {
        require(
            ownerOf(tokenId) == from,
            "ERC721: transfer of token that is not own"
        );
        require(to != address(0), "ERC721: transfer to the zero address");
        // reset approval for the order
        _approvals[tokenId] = address(0);
        // update balances
        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        // update order
        address t = orderToken(tokenId);
        orderInfo[t][tokenId].trader = to;
        // update trader orders
        _traderOrders[t][from].remove(tokenId);
        _traderOrders[t][to].insertEnd(tokenId);
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

    function _otherToken(address token) internal view returns (address) {
        return token == token0 ? token1 : token0;
    }

    function _tradeFirstOrder(
        address buyToken,
        address sellToken,
        TradeHandler memory trade,
        uint256 price,
        function(address, Order memory, TradeHandler memory, uint256)
            view
            returns (uint256, uint256) _getTradeAmounts
    ) internal returns (bool) {
        // get the order ID
        uint256 orderID = _orders[buyToken].first();
        if (orderID == 0) {
            return false;
        }
        // get the order
        Order memory _order = orderInfo[buyToken][orderID];
        // calculate cost and return
        (uint256 cost, uint256 buyAmount) = _getTradeAmounts(
            buyToken,
            _order,
            trade,
            price
        );
        if (buyAmount == 0) {
            return false;
        }
        // update order owner balance
        traderBalance[sellToken][_order.trader] += cost;
        // update liquidity info
        liquidityByPrice[buyToken][_order.price] -= buyAmount;
        totalLiquidity[buyToken] -= buyAmount;
        // update order
        _order.amount -= buyAmount;
        if (_order.amount == 0) {
            _removeOrder(buyToken, orderID);
        } else {
            orderInfo[buyToken][orderID].amount -= buyAmount;
        }
        // update trade data
        trade.update(cost, buyAmount);
        emit OrderTaken(buyToken, orderID, buyAmount, _order.price);
        if (_order.amount != 0) {
            return false;
        }
        return true;
    }

    function _trade(
        address buyToken,
        uint256 price,
        uint256 maxAmountIn,
        address receiver,
        function(address, Order memory, TradeHandler memory, uint256)
            view
            returns (uint256, uint256) _getTradeAmounts,
        function(
            address,
            address,
            TradeHandler memory,
            address
        ) _postTradeHandler
    ) internal returns (uint256 amountIn, uint256 amountOut) {
        TradeHandler memory trade = TradeHandler(0, 0, withoutFee(maxAmountIn));
        address sellToken = _otherToken(buyToken);
        while (trade.availableAmountIn > 0) {
            if (
                !_tradeFirstOrder(
                    buyToken,
                    sellToken,
                    trade,
                    price,
                    _getTradeAmounts
                )
            ) {
                break;
            }
        }
        require(
            trade.amountIn > 0 && trade.amountOut > 0,
            "LimitrVault: no trade"
        );
        _postTradeHandler(buyToken, sellToken, trade, receiver);
        return (withFee(trade.amountIn), trade.amountOut);
    }

    // deposit payment
    // collect fee
    // withdraw purchased tokens
    function _postTrade(
        address buyToken,
        address sellToken,
        TradeHandler memory trade,
        address receiver
    ) internal {
        // deposit payment
        _depositToken(sellToken, msg.sender, trade.amountIn);
        // calculate fee
        uint256 fee = feeFor(trade.amountIn);
        // collect fee
        _tokenTransferFrom(
            sellToken,
            msg.sender,
            ILimitrRegistry(registry).feeReceiver(),
            fee
        );
        emit FeeCollected(sellToken, fee);
        // transfer purchased tokens
        _withdrawToken(buyToken, receiver, trade.amountOut);
    }

    // only collect fee from the vault
    function _postBorrowTrade(
        address,
        address sellToken,
        TradeHandler memory trade,
        address
    ) internal {
        // calculate fee
        uint256 fee = feeFor(trade.amountIn);
        // collect fee
        _withdrawToken(sellToken, ILimitrRegistry(registry).feeReceiver(), fee);
        emit FeeCollected(sellToken, fee);
    }

    function _getTradeAmountsMaxPrice(
        address buyToken,
        Order memory _order,
        TradeHandler memory trade,
        uint256 maxPrice
    ) internal view returns (uint256, uint256) {
        // check price
        if (_order.price > maxPrice) {
            return (0, 0);
        }
        // max amount of the base token that can be purchased with the
        uint256 buyAmount = returnAtPrice(
            buyToken,
            trade.availableAmountIn,
            _order.price
        );
        if (buyAmount == 0) {
            return (0, 0);
        }
        return _tradeAmounts(buyToken, _order, trade, buyAmount);
    }

    function _tradeAmounts(
        address buyToken,
        Order memory _order,
        TradeHandler memory trade,
        uint256 maxBuyAmount
    ) internal view returns (uint256, uint256) {
        // cap at the order amount
        if (maxBuyAmount > _order.amount) {
            maxBuyAmount = _order.amount;
        }
        // max that can be afforded
        uint256 cost = costAtPrice(buyToken, maxBuyAmount, _order.price);
        if (cost > trade.availableAmountIn) {
            cost = trade.availableAmountIn;
            maxBuyAmount = returnAtPrice(buyToken, cost, _order.price);
        }
        return (cost, maxBuyAmount);
    }

    function _getTradeAmountsAvgPrice(
        address buyToken,
        Order memory _order,
        TradeHandler memory trade,
        uint256 avgPrice
    ) internal view returns (uint256, uint256) {
        // max amount that can be purchased
        uint256 buyAmount = _maxAmountAvgPrice(
            buyToken,
            avgPrice,
            trade,
            _order.price
        );
        if (buyAmount == 0) {
            return (0, 0);
        }
        return _tradeAmounts(buyToken, _order, trade, buyAmount);
    }
}
