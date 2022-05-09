const {
  assertReason,
  ethTokenDeployment,
  vaultNewSellOrders,
  toBigInt,
} = require("./util");

contract("LimitrRouter", (accounts) => {
  const createOrders = async (depl) => {
    const vault = await depl.vaultAtIdx(0);
    const tkaDecimals = await depl.tokens.tka.decimals();
    const wethDecimals = await depl.weth.decimals();
    const tkaOrders = [
      [13n * 10n ** (wethDecimals - 1n), 50n * 10n ** (tkaDecimals - 1n)],
      [16n * 10n ** (wethDecimals - 1n), 10n * 10n ** (tkaDecimals - 1n)],
      [15n * 10n ** (wethDecimals - 1n), 5n * 10n ** (tkaDecimals - 1n)],
      [17n * 10n ** (wethDecimals - 1n), 40n * 10n ** (tkaDecimals - 1n)],
    ].map((v) => [depl.tokens.tka].concat(v).concat([accounts[0]]));
    await vaultNewSellOrders(vault, tkaOrders);
    const wethOrders = [
      [13n * 10n ** (tkaDecimals - 1n), 50n * 10n ** (wethDecimals - 1n)],
      [16n * 10n ** (tkaDecimals - 1n), 10n * 10n ** (wethDecimals - 1n)],
      [15n * 10n ** (tkaDecimals - 1n), 5n * 10n ** (wethDecimals - 1n)],
      [17n * 10n ** (tkaDecimals - 1n), 40n * 10n ** (wethDecimals - 1n)],
    ].map((v) => [depl.weth].concat(v).concat([accounts[0]]));
    await depl.weth.deposit({
      value: (
        wethOrders.map((v) => v[1]).reduce((ac, v) => ac + v, 0n) * 2n
      ).toString(),
    });
    await vaultNewSellOrders(vault, wethOrders);
  };

  it("can only cancel own orders or if approved", async () => {
    const depl = await ethTokenDeployment(accounts[0], accounts[2]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    try {
      await depl.router.cancelETHOrder(
        depl.tokens.tka.address,
        1n,
        0n,
        accounts[0],
        0n,
        { from: accounts[1] }
      );
      assert.isTrue(false);
    } catch (err) {
      assertReason.notAllowed(err);
    }
    await vault.approve(accounts[1], 1);
    await depl.router.cancelETHOrder(
      depl.tokens.tka.address,
      1n,
      0n,
      accounts[0],
      0n,
      { from: accounts[1] }
    );
    await vault.setApprovalForAll(accounts[1], true);
    await depl.router.cancelETHOrder(
      depl.tokens.tka.address,
      2n,
      0n,
      accounts[0],
      0n,
      { from: accounts[1] }
    );
  });

  it("sends ETH after canceling order", async () => {
    const depl = await ethTokenDeployment(accounts[0], accounts[2]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const order5 = await vault.orderInfo(depl.weth.address, 5);
    const preBalance = toBigInt(await web3.eth.getBalance(accounts[0]));
    const resp = await depl.router.cancelETHOrder(
      depl.tokens.tka.address,
      5n,
      0n,
      accounts[0],
      0n
    );
    const postBalance = toBigInt(await web3.eth.getBalance(accounts[0]));
    const tx = await web3.eth.getTransaction(resp.tx);
    const gasCost = toBigInt(tx.gas) * toBigInt(tx.gasPrice);
    assert.isTrue(postBalance - preBalance >= order5.amount - gasCost);
  });

  it("returns excess tokens after buy max price and sends the correct amount of purchased tokens", async () => {
    const depl = await ethTokenDeployment(accounts[0], accounts[2]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const orderID = await vault.firstOrder(depl.weth.address);
    const order = await vault.orderInfo(depl.weth.address, orderID);
    const orderCost = await vault.costAtMaxPrice(
      depl.weth.address,
      order.amount,
      order.price
    );
    const fee = await vault.feeFor(orderCost.amountIn);
    const totalAmount = orderCost.amountIn + fee;
    const tkaBalancePre = await depl.tokens.tka.balanceOf(accounts[0]);
    const wethBalancePre = await depl.weth.balanceOf(accounts[0]);
    await depl.tokens.tka.approve(depl.router.address, totalAmount * 2n);
    await depl.router.buyAtMaxPrice(
      depl.weth.address,
      depl.tokens.tka.address,
      order.price,
      totalAmount * 2n,
      accounts[0],
      0
    );
    const tkaBalancePost = await depl.tokens.tka.balanceOf(accounts[0]);
    const wethBalancePost = await depl.weth.balanceOf(accounts[0]);
    assert.isTrue(tkaBalancePre - tkaBalancePost == totalAmount);
    assert.isTrue(wethBalancePost - wethBalancePre == orderCost.amountOut);
  });

  it("returns excess ETH after buy max price and sends the correct amount of purchased tokens", async () => {
    const depl = await ethTokenDeployment(accounts[0], accounts[2]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const orderID = await vault.firstOrder(depl.weth.address);
    const order = await vault.orderInfo(depl.weth.address, orderID);
    const orderCost = await vault.costAtMaxPrice(
      depl.weth.address,
      order.amount,
      order.price
    );
    const fee = await vault.feeFor(orderCost.amountIn);
    const totalAmount = orderCost.amountIn + fee;
    const tkaBalancePre = await depl.tokens.tka.balanceOf(accounts[0]);
    const ethBalancePre = toBigInt(await web3.eth.getBalance(accounts[1]));
    await depl.router.buyWithETHAtMaxPrice(
      depl.tokens.tka.address,
      order.price,
      accounts[0],
      0,
      { from: accounts[1], value: (totalAmount * 2n).toString() }
    );
    const tkaBalancePost = await depl.tokens.tka.balanceOf(accounts[0]);
    const ethBalancePost = toBigInt(await web3.eth.getBalance(accounts[1]));
    assert.isTrue(tkaBalancePost - tkaBalancePre == orderCost.amountOut);
    assert.isTrue(ethBalancePre - totalAmount >= ethBalancePost);
  });

  it("sends the correct ETH when withdrawing", async () => {
    const depl = await ethTokenDeployment(accounts[0], accounts[2]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const orderID = await vault.firstOrder(depl.weth.address);
    const order = await vault.orderInfo(depl.weth.address, orderID);
    const orderCost = await vault.costAtMaxPrice(
      depl.weth.address,
      order.amount,
      order.price
    );
    const fee = await vault.feeFor(orderCost.amountIn);
    const totalAmount = orderCost.amountIn + fee;
    await depl.router.buyWithETHAtMaxPrice(
      depl.tokens.tka.address,
      order.price,
      accounts[0],
      0,
      { value: (totalAmount * 2n).toString() }
    );
    const availableBalance = await vault.traderBalance(
      depl.weth.address,
      accounts[0]
    );
    const ethBalancePre = toBigInt(await web3.eth.getBalance(accounts[0]));
    const resp = await depl.router.withdrawETH(
      depl.tokens.tka.address,
      accounts[0],
      0
    );
    const tx = await web3.eth.getTransaction(resp.tx);
    const gasCost = toBigInt(tx.gas * tx.gasPrice);
    const ethBalancePost = toBigInt(await web3.eth.getBalance(accounts[0]));
    assert.isTrue(ethBalancePost >= ethBalancePre + availableBalance - gasCost);
  });
});
