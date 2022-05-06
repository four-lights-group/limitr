// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "./interfaces/ILimitrRouter.sol";
import "./interfaces/ILimitrVault.sol";
import "./interfaces/ILimitrRegistry.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";

/// @author Limitr
/// @notice This is the vault router, which handles wrapping/unwrapping ETH and
///         vault creation
contract LimitrRouter is ILimitrRouter {
    /// @return The address for the registry
    address public immutable override registry;

    /// @return The address for WETH
    address public immutable override weth;

    constructor(address _weth, address _registry) {
        weth = _weth;
        registry = _registry;
    }

    receive() external payable {}

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
    ) external override returns (uint256) {
        return
            newSellOrderWithPointer(
                sellToken,
                buyToken,
                price,
                amount,
                trader,
                deadline,
                0
            );
    }

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
    ) public override returns (uint256) {
        uint256[] memory pointers = new uint256[](1);
        pointers[0] = pointer;
        return
            newSellOrderWithPointers(
                sellToken,
                buyToken,
                price,
                amount,
                trader,
                deadline,
                pointers
            );
    }

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
    ) public override returns (uint256) {
        ILimitrVault v = _getOrCreateVault(sellToken, buyToken);
        _tokenTransferFrom(sellToken, msg.sender, address(this), amount);
        _tokenApprove(sellToken, address(v), amount);
        return
            v.newSellOrderWithPointers(
                sellToken,
                price,
                amount,
                trader,
                deadline,
                pointers
            );
    }

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
    ) external payable override returns (uint256) {
        return newETHSellOrderWithPointer(buyToken, price, trader, deadline, 0);
    }

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
    ) public payable override returns (uint256) {
        uint256[] memory pointers = new uint256[](1);
        pointers[0] = pointer;
        return
            newETHSellOrderWithPointers(
                buyToken,
                price,
                trader,
                deadline,
                pointers
            );
    }

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
    ) public payable override returns (uint256) {
        ILimitrVault v = _getOrCreateVault(weth, buyToken);
        uint256 amt = _wrapBalance();
        _tokenApprove(weth, address(v), amt);
        return
            v.newSellOrderWithPointers(
                weth,
                price,
                amt,
                trader,
                deadline,
                pointers
            );
    }

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
    ) external override {
        ILimitrVault v = _getExistingVault(weth, buyToken);
        require(v.isAllowed(msg.sender, orderID), "not allowed");
        v.cancelOrder(orderID, amount, address(this), deadline);
        _unwrapBalance();
        _returnETHBalance(receiver);
    }

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
    ) external override returns (uint256 cost, uint256 received) {
        ILimitrVault v = _getExistingVault(buyToken, sellToken);
        _tokenTransferFrom(sellToken, msg.sender, address(this), maxAmountIn);
        _tokenApprove(sellToken, address(v), maxAmountIn);
        (cost, received) = v.buyAtMaxPrice(
            buyToken,
            maxPrice,
            maxAmountIn,
            receiver,
            deadline
        );
        _returnTokenBalance(sellToken, msg.sender);
    }

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
    ) external override returns (uint256 cost, uint256 received) {
        ILimitrVault v = _getExistingVault(buyToken, sellToken);
        _tokenTransferFrom(sellToken, msg.sender, address(this), maxAmountIn);
        _tokenApprove(sellToken, address(v), maxAmountIn);
        (cost, received) = v.buyAtAvgPrice(
            buyToken,
            avgPrice,
            maxAmountIn,
            receiver,
            deadline
        );
        _returnTokenBalance(sellToken, msg.sender);
    }

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
    ) external override returns (uint256 cost, uint256 received) {
        ILimitrVault v = _getExistingVault(weth, sellToken);
        _tokenTransferFrom(sellToken, msg.sender, address(this), maxAmountIn);
        _tokenApprove(sellToken, address(v), maxAmountIn);
        (cost, received) = v.buyAtMaxPrice(
            weth,
            maxPrice,
            maxAmountIn,
            address(this),
            deadline
        );
        _unwrapBalance();
        _returnETHBalance(receiver);
        _returnTokenBalance(sellToken, msg.sender);
    }

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
    ) external override returns (uint256 cost, uint256 received) {
        ILimitrVault v = _getExistingVault(weth, sellToken);
        _tokenTransferFrom(sellToken, msg.sender, address(this), maxAmountIn);
        _tokenApprove(sellToken, address(v), maxAmountIn);
        (cost, received) = v.buyAtAvgPrice(
            weth,
            avgPrice,
            maxAmountIn,
            address(this),
            deadline
        );
        _unwrapBalance();
        _returnETHBalance(receiver);
        _returnTokenBalance(sellToken, msg.sender);
    }

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
    ) external payable override returns (uint256 cost, uint256 received) {
        ILimitrVault v = _getExistingVault(weth, buyToken);
        uint256 maxAmountIn = _wrapBalance();
        _tokenApprove(weth, address(v), maxAmountIn);
        (cost, received) = v.buyAtMaxPrice(
            buyToken,
            maxPrice,
            maxAmountIn,
            receiver,
            deadline
        );
        _unwrapBalance();
        _returnETHBalance(payable(msg.sender));
    }

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
    ) external payable override returns (uint256 cost, uint256 received) {
        ILimitrVault v = _getExistingVault(weth, buyToken);
        uint256 maxAmountIn = _wrapBalance();
        _tokenApprove(weth, address(v), maxAmountIn);
        (cost, received) = v.buyAtAvgPrice(
            buyToken,
            avgPrice,
            maxAmountIn,
            receiver,
            deadline
        );
        _unwrapBalance();
        _returnETHBalance(payable(msg.sender));
    }

    /// @notice Withdraw trader balance in ETH
    /// @param sellToken The other token of the pair WETH/xxxxx
    /// @param to The receiver address
    /// @param amount The amount to withdraw
    function withdrawETH(
        address sellToken,
        address payable to,
        uint256 amount
    ) external override {
        ILimitrVault v = _getExistingVault(weth, sellToken);
        v.withdrawFor(weth, msg.sender, address(this), amount);
        _unwrapBalance();
        _returnETHBalance(to);
    }

    // internal / private functions

    function _getOrCreateVault(address tokenA, address tokenB)
        internal
        returns (ILimitrVault)
    {
        ILimitrRegistry r = ILimitrRegistry(registry);
        address v = r.vaultFor(tokenA, tokenB);
        if (v == address(0)) {
            v = r.createVault(tokenA, tokenB);
        }
        return ILimitrVault(v);
    }

    function _getExistingVault(address tokenA, address tokenB)
        internal
        view
        returns (ILimitrVault)
    {
        address v = ILimitrRegistry(registry).vaultFor(tokenA, tokenB);
        require(v != address(0), "Vault doesn" "t exist");
        return ILimitrVault(v);
    }

    function _returnETHBalance(address payable receiver) internal {
        uint256 amt = address(this).balance;
        if (amt == 0) {
            return;
        }
        receiver.transfer(amt);
    }

    function _returnTokenBalance(address token, address receiver) internal {
        IERC20 t = IERC20(token);
        uint256 amt = t.balanceOf(address(this));
        if (amt == 0) {
            return;
        }
        _tokenTransfer(token, receiver, amt);
    }

    function _tokenApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        IERC20(token).approve(spender, amount);
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
        address owner,
        address to,
        uint256 amount
    ) internal {
        bool ok = IERC20(token).transferFrom(owner, to, amount);
        require(ok, "can" "t transferFrom()");
    }

    function _wrapBalance() internal returns (uint256) {
        uint256 amt = address(this).balance;
        WETH9(weth).deposit{value: amt}();
        return amt;
    }

    function _unwrapBalance() internal {
        uint256 amt = IERC20(weth).balanceOf(address(this));
        if (amt == 0) {
            return;
        }
        WETH9(weth).withdraw(amt);
    }
}
