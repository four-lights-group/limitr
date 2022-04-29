const {
  twoTokenDeployment,
  vaultNewSellOrder,
  vaultNewSellOrders,
  vaultBuyMaxPrice,
  vaultBuyAvgPrice,
} = require("./util");

contract("LimitrVault", (accounts) => {
  const createOrders = async (depl) => {
    const vault = await depl.vaultAtIdx(0);
    const tkaDecimals = await depl.tokens.tka.decimals();
    const tkbDecimals = await depl.tokens.tkb.decimals();
    const orders = [
      [13n * 10n ** (tkbDecimals - 1n), 50n * 10n ** (tkaDecimals - 1n)],
      [16n * 10n ** (tkbDecimals - 1n), 10n * 10n ** (tkaDecimals - 1n)],
      [15n * 10n ** (tkbDecimals - 1n), 5n * 10n ** (tkaDecimals - 1n)],
      [17n * 10n ** (tkbDecimals - 1n), 40n * 10n ** (tkaDecimals - 1n)],
      [15n * 10n ** (tkbDecimals - 1n), 15n * 10n ** (tkaDecimals - 1n)],
      [16n * 10n ** (tkbDecimals - 1n), 30n * 10n ** (tkaDecimals - 1n)],
      [14n * 10n ** (tkbDecimals - 1n), 20n * 10n ** (tkaDecimals - 1n)],
      [12n * 10n ** (tkbDecimals - 1n), 35n * 10n ** (tkaDecimals - 1n)],
    ].map((v) => [depl.tokens.tka].concat(v).concat([accounts[0]]));
    await vaultNewSellOrders(vault, orders);
  };

  const convertOrdersInfo = (orders) =>
    orders.id
      .filter((id) => id)
      .map((id, idx) => ({
        orderID: id,
        price: orders.price[idx],
        amount: orders.amount[idx],
        trader: orders.trader[idx],
      }));

  // it("can buy small order at max price", async () => {
  //   const depl = await twoTokenDeployment(accounts[0]);
  //   await createOrders(depl);
  //   const vault = await depl.vaultAtIdx(0);
  //   const order = await vault
  //     .firstOrder(depl.tokens.tka.address)
  //     .then((orderID) =>
  //       vault
  //         .orderInfo(depl.tokens.tka.address, orderID)
  //         .then((info) => ({ orderID: orderID, ...info }))
  //     );
  //   const price = order.price - 1n;
  //   const amount = 10000000n;
  //   await vaultNewSellOrder(vault, depl.tokens.tka, price, amount, accounts[0]);
  //   const maxCost = await vault
  //     .costAtPrice(depl.tokens.tka.address, amount + 1n, price)
  //     .then(vault.withFee);
  //   await vaultBuyMaxPrice(
  //     vault,
  //     depl.tokens.tka,
  //     depl.tokens.tkb,
  //     price,
  //     maxCost,
  //     accounts[0]
  //   );
  //   assert.isTrue(
  //     (await vault.firstOrder(depl.tokens.tka.address)) == order.orderID
  //   );
  // });

  // it("can buy partial order at max price", async () => {
  //   const depl = await twoTokenDeployment(accounts[0]);
  //   await createOrders(depl);
  //   const vault = await depl.vaultAtIdx(0);
  //   const firstOrder = await vault
  //     .firstOrder(depl.tokens.tka.address)
  //     .then((orderID) =>
  //       vault
  //         .orderInfo(depl.tokens.tka.address, orderID)
  //         .then((info) => ({ orderID: orderID, ...info }))
  //     );
  //   const maxCost = await vault
  //     .costAtPrice(
  //       depl.tokens.tka.address,
  //       firstOrder.amount / 2n,
  //       firstOrder.price
  //     )
  //     .then(vault.withFee);
  //   await vaultBuyMaxPrice(
  //     vault,
  //     depl.tokens.tka,
  //     depl.tokens.tkb,
  //     firstOrder.price,
  //     maxCost,
  //     accounts[0]
  //   );
  //   const newFirstOrder = await vault
  //     .firstOrder(depl.tokens.tka.address)
  //     .then((orderID) =>
  //       vault
  //         .orderInfo(depl.tokens.tka.address, orderID)
  //         .then((info) => ({ orderID: orderID, ...info }))
  //     );
  //   assert.isTrue(firstOrder.orderID == newFirstOrder.orderID);
  //   assert.isTrue(firstOrder.price == newFirstOrder.price);
  //   assert.isTrue(firstOrder.amount / 2n == newFirstOrder.amount);
  // });

  // it("can buy full order at max price", async () => {
  //   const depl = await twoTokenDeployment(accounts[0]);
  //   await createOrders(depl);
  //   const vault = await depl.vaultAtIdx(0);
  //   const firstOrder = await vault
  //     .firstOrder(depl.tokens.tka.address)
  //     .then((orderID) =>
  //       vault
  //         .orderInfo(depl.tokens.tka.address, orderID)
  //         .then((info) => ({ orderID: orderID, ...info }))
  //     );
  //   const maxCost = await vault
  //     .costAtPrice(depl.tokens.tka.address, firstOrder.amount, firstOrder.price)
  //     .then(vault.withFee);
  //   await vaultBuyMaxPrice(
  //     vault,
  //     depl.tokens.tka,
  //     depl.tokens.tkb,
  //     firstOrder.price,
  //     maxCost,
  //     accounts[0]
  //   );
  //   const newFirstOrder = await vault
  //     .firstOrder(depl.tokens.tka.address)
  //     .then((orderID) =>
  //       vault
  //         .orderInfo(depl.tokens.tka.address, orderID)
  //         .then((info) => ({ orderID: orderID, ...info }))
  //     );
  //   assert.isTrue(firstOrder.orderID != newFirstOrder.orderID);
  // });

  // it("can buy multiple orders at max price", async () => {
  //   const depl = await twoTokenDeployment(accounts[0]);
  //   await createOrders(depl);
  //   const vault = await depl.vaultAtIdx(0);
  //   const orders = await vault
  //     .ordersInfo(depl.tokens.tka.address, 0, 4)
  //     .then(convertOrdersInfo);
  //   const maxCost = await Promise.all(
  //     orders
  //       .slice(0, 3)
  //       .map((order) =>
  //         vault.costAtPrice(depl.tokens.tka.address, order.amount, order.price)
  //       )
  //   )
  //     .then((r) => r.reduce((ac, v) => ac + v, 0n))
  //     .then(vault.withFee);
  //   await vaultBuyMaxPrice(
  //     vault,
  //     depl.tokens.tka,
  //     depl.tokens.tkb,
  //     orders[3].price,
  //     maxCost,
  //     accounts[0]
  //   );
  //   const newFirstOrder = await vault
  //     .firstOrder(depl.tokens.tka.address)
  //     .then((orderID) =>
  //       vault
  //         .orderInfo(depl.tokens.tka.address, orderID)
  //         .then((info) => ({ orderID: orderID, ...info }))
  //     );
  //   assert.isTrue(newFirstOrder.orderID == orders[3].orderID);
  //   assert.isTrue(newFirstOrder.amount == orders[3].amount);
  // });

  // it("can buy small order at average price", async () => {
  //   const depl = await twoTokenDeployment(accounts[0]);
  //   await createOrders(depl);
  //   const vault = await depl.vaultAtIdx(0);
  //   const orders = await vault
  //     .ordersInfo(depl.tokens.tka.address, 0, 2)
  //     .then(convertOrdersInfo);
  //   await vaultNewSellOrder(
  //     vault,
  //     depl.tokens.tka,
  //     orders[0].price - 1n,
  //     1n,
  //     orders[0].trader
  //   );
  //   const cost = await await vault
  //     .costAtMaxPrice(
  //       depl.tokens.tka.address,
  //       orders[0].amount + 1n,
  //       orders[0].price
  //     )
  //     .then((v) => v.amountIn);
  //   const fee = await vault.feeFor(cost);
  //   await vaultBuyAvgPrice(
  //     vault,
  //     depl.tokens.tka,
  //     depl.tokens.tkb,
  //     orders[0].price * 2n,
  //     cost + fee,
  //     accounts[0]
  //   );
  //   const newOrders = await vault
  //     .ordersInfo(depl.tokens.tka.address, 0, 1)
  //     .then(convertOrdersInfo);
  //   assert.isTrue(newOrders[0].orderID == orders[1].orderID);
  //   assert.isTrue(newOrders[0].price == orders[1].price);
  //   assert.isTrue(newOrders[0].amount == orders[1].amount);
  // });

  // it("can buy partial order at average price", async () => {
  //   const depl = await twoTokenDeployment(accounts[0]);
  //   await createOrders(depl);
  //   const vault = await depl.vaultAtIdx(0);
  //   const firstOrder = await vault
  //     .firstOrder(depl.tokens.tka.address)
  //     .then((orderID) => vault.orderInfo(depl.tokens.tka.address, orderID));
  //   const cost = await vault
  //     .costAtMaxPrice(
  //       depl.tokens.tka.address,
  //       firstOrder.amount / 2n,
  //       firstOrder.price
  //     )
  //     .then((v) => v.amountIn);
  //   const fee = await vault.feeFor(cost);
  //   await vaultBuyAvgPrice(
  //     vault,
  //     depl.tokens.tka,
  //     depl.tokens.tkb,
  //     firstOrder.price * 2n,
  //     cost + fee,
  //     accounts[0]
  //   );
  //   const newFirstOrder = await vault
  //     .firstOrder(depl.tokens.tka.address)
  //     .then((orderID) => vault.orderInfo(depl.tokens.tka.address, orderID));
  //   assert.isTrue(firstOrder.price == newFirstOrder.price);
  //   assert.isTrue(firstOrder.amount / 2n == newFirstOrder.amount);
  // });

  // it("can buy full order at average price", async () => {
  //   const depl = await twoTokenDeployment(accounts[0]);
  //   await createOrders(depl);
  //   const vault = await depl.vaultAtIdx(0);
  //   const orders = await vault
  //     .ordersInfo(depl.tokens.tka.address, 0, 2)
  //     .then(convertOrdersInfo);
  //   const cost = await vault
  //     .costAtMaxPrice(
  //       depl.tokens.tka.address,
  //       orders[0].amount,
  //       orders[0].price
  //     )
  //     .then((v) => v.amountIn);
  //   const fee = await vault.feeFor(cost);
  //   await vaultBuyAvgPrice(
  //     vault,
  //     depl.tokens.tka,
  //     depl.tokens.tkb,
  //     orders[0].price * 2n,
  //     cost + fee,
  //     accounts[0]
  //   );
  //   const newOrders = await vault
  //     .ordersInfo(depl.tokens.tka.address, 0, 1)
  //     .then(convertOrdersInfo);
  //   assert.isTrue(newOrders[0].orderID == orders[1].orderID);
  //   assert.isTrue(newOrders[0].price == orders[1].price);
  //   assert.isTrue(newOrders[0].amount == orders[1].amount);
  // });

  it("can buy multiple orders at average price", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    let orders = await vault
      .ordersInfo(depl.tokens.tka.address, 0, 5)
      .then(convertOrdersInfo);
    const price = 13n * 10n ** ((await depl.tokens.tkb.decimals()) - 1n);
    const cost = await vault.costAtAvgPrice(
      depl.tokens.tka.address,
      orders.map((v) => v.amount).reduce((ac, v) => ac + v, 0n),
      price
    );
    const tkaBalance = await depl.tokens.tka.balanceOf(accounts[0]);
    const tkbBalance = await depl.tokens.tkb.balanceOf(accounts[0]);
    let expOrders = Array.from(orders);
    let amountOut = cost.amountOut;
    while (amountOut > 0n) {
      const amt =
        amountOut < expOrders[0].amount ? amountOut : expOrders[0].amount;
      expOrders[0].amount -= amt;
      amountOut -= amt;
      expOrders = expOrders.filter((v) => v.amount);
    }
    const fee = await vault.feeFor(cost.amountIn);
    await vaultBuyAvgPrice(
      vault,
      depl.tokens.tka,
      depl.tokens.tkb,
      price,
      cost.amountIn + fee,
      accounts[0]
    );
    const newFirstOrder = await vault
      .ordersInfo(depl.tokens.tka.address, 0, 1)
      .then(convertOrdersInfo)
      .then((v) => v[0]);
    assert.isTrue(newFirstOrder.orderID == expOrders[0].orderID);
    const realCost =
      tkbBalance - (await depl.tokens.tkb.balanceOf(accounts[0]));
    const realReturn =
      (await depl.tokens.tka.balanceOf(accounts[0])) - tkaBalance;
    const realPrice =
      (10n ** (await depl.tokens.tka.decimals()) * realCost) / realReturn;
    assert.isTrue(realPrice <= price);
  });

  // it("tracks correctly the available trader balance", async () => {});

  // it("send the correct amount of tokens on withdraw", async () => {});
});
