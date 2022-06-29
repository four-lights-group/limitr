const {
  twoTokenDeployment,
  vaultNewSellOrder,
  vaultNewSellOrders,
  vaultBuyMaxPrice,
} = require("./util");

contract("LimitrVault", (accounts) => {
  const createOrders = async (depl) => {
    const vault = await depl.vaultAtIdx(0);
    const orders = [
      [
        13n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        50n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        16n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        10n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        15n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        5n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        17n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        40n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        15n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        15n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        16n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        30n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        14n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        20n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        12n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        35n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
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

  it("can buy small order at max price", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const order = await vault
      .firstOrder(depl.tokens.tka.address)
      .then((orderID) =>
        vault
          .orderInfo(depl.tokens.tka.address, orderID)
          .then((info) => ({ orderID: orderID, ...info }))
      );
    const price = order.price - 1n;
    const amount = 10000000n;
    await vaultNewSellOrder(vault, depl.tokens.tka, price, amount, accounts[0]);
    const maxCost = await vault
      .costAtPrice(depl.tokens.tka.address, amount * 2n, price)
      .then(vault.withFee);
    await vaultBuyMaxPrice(
      vault,
      depl.tokens.tka,
      depl.tokens.tkb,
      order.price,
      maxCost,
      accounts[0]
    );
    const newOrder = await vault
      .firstOrder(depl.tokens.tka.address)
      .then((orderID) =>
        vault
          .orderInfo(depl.tokens.tka.address, orderID)
          .then((info) => ({ orderID, ...info }))
      );
    assert.isTrue(newOrder.orderID == order.orderID);
    assert.isTrue(newOrder.amount < order.amount);
  });

  it("can buy partial order at max price", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const firstOrder = await vault
      .firstOrder(depl.tokens.tka.address)
      .then((orderID) =>
        vault
          .orderInfo(depl.tokens.tka.address, orderID)
          .then((info) => ({ orderID: orderID, ...info }))
      );
    const maxCost = await vault
      .costAtPrice(
        depl.tokens.tka.address,
        firstOrder.amount / 2n,
        firstOrder.price
      )
      .then(vault.withFee);
    await vaultBuyMaxPrice(
      vault,
      depl.tokens.tka,
      depl.tokens.tkb,
      firstOrder.price,
      maxCost,
      accounts[0]
    );
    const newFirstOrder = await vault
      .firstOrder(depl.tokens.tka.address)
      .then((orderID) =>
        vault
          .orderInfo(depl.tokens.tka.address, orderID)
          .then((info) => ({ orderID: orderID, ...info }))
      );
    assert.isTrue(firstOrder.orderID == newFirstOrder.orderID);
    assert.isTrue(firstOrder.price == newFirstOrder.price);
    assert.isTrue(firstOrder.amount / 2n == newFirstOrder.amount);
  });

  it("can buy full order at max price", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const firstOrder = await vault
      .firstOrder(depl.tokens.tka.address)
      .then((orderID) =>
        vault
          .orderInfo(depl.tokens.tka.address, orderID)
          .then((info) => ({ orderID: orderID, ...info }))
      );
    const maxCost = await vault
      .costAtPrice(depl.tokens.tka.address, firstOrder.amount, firstOrder.price)
      .then(vault.withFee);
    await vaultBuyMaxPrice(
      vault,
      depl.tokens.tka,
      depl.tokens.tkb,
      firstOrder.price,
      maxCost,
      accounts[0]
    );
    const newFirstOrder = await vault
      .firstOrder(depl.tokens.tka.address)
      .then((orderID) =>
        vault
          .orderInfo(depl.tokens.tka.address, orderID)
          .then((info) => ({ orderID: orderID, ...info }))
      );
    assert.isTrue(firstOrder.orderID != newFirstOrder.orderID);
  });

  it("can buy multiple orders at max price", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const orders = await vault
      .ordersInfo(depl.tokens.tka.address, 0, 10)
      .then(convertOrdersInfo);
    const maxCost = await Promise.all(
      orders
        .slice(0, 5)
        .map((order) =>
          vault.costAtPrice(depl.tokens.tka.address, order.amount, order.price)
        )
    )
      .then((r) => r.reduce((ac, v) => ac + v, 0n))
      .then(vault.withFee);
    const receipt = await vaultBuyMaxPrice(
      vault,
      depl.tokens.tka,
      depl.tokens.tkb,
      orders[5].price,
      maxCost,
      accounts[0]
    );
    const newFirstOrder = await vault
      .firstOrder(depl.tokens.tka.address)
      .then((orderID) =>
        vault
          .orderInfo(depl.tokens.tka.address, orderID)
          .then((info) => ({ orderID: orderID, ...info }))
      );
    assert.isTrue(newFirstOrder.orderID == orders[5].orderID);
    assert.isTrue(newFirstOrder.amount == orders[5].amount);
  });

  it("accounts correctly the available trader balance", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    assert.isTrue(
      (await vault.traderBalance(depl.tokens.tkb.address, accounts[0])) == 0n
    );
    let orders = await vault
      .ordersInfo(depl.tokens.tka.address, 0, 5)
      .then(convertOrdersInfo);
    const cost = await vault.costAtMaxPrice(
      depl.tokens.tka.address,
      orders
        .slice(0, 3)
        .map((order) => order.amount)
        .reduce((ac, v) => ac + v, 0n),
      orders[2].price
    );
    const fee = await vault.feeFor(cost.amountIn);
    await vaultBuyMaxPrice(
      vault,
      depl.tokens.tka,
      depl.tokens.tkb,
      orders[2].price,
      cost.amountIn + fee,
      accounts[0]
    );
    let traderBalance = await vault.traderBalance(
      depl.tokens.tkb.address,
      accounts[0]
    );
    assert.isTrue(traderBalance == cost.amountIn);
    let accountBalance = await depl.tokens.tkb.balanceOf(accounts[0]);
    await vault.withdraw(
      depl.tokens.tkb.address,
      accounts[0],
      traderBalance / 3n
    );
    assert.isTrue(
      (await vault.traderBalance(depl.tokens.tkb.address, accounts[0])) ==
        traderBalance - traderBalance / 3n
    );
    assert.isTrue(
      (await depl.tokens.tkb.balanceOf(accounts[0])) ==
        accountBalance + traderBalance / 3n
    );
    await vault.withdraw(depl.tokens.tkb.address, accounts[0], 0n);
    assert.isTrue(
      (await vault.traderBalance(depl.tokens.tkb.address, accounts[0])) == 0n
    );
    assert.isTrue(
      (await depl.tokens.tkb.balanceOf(accounts[0])) ==
        accountBalance + traderBalance
    );
  });
});
