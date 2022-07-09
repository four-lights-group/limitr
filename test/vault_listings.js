const { twoTokenDeployment, toBigInt, vaultNewOrders } = require("./util");

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
    await vaultNewOrders(vault, orders);
    await depl.vaultTrackers[0].newOrders(
      orders.map((order) => {
        order[0] = order[0].address;
        return order;
      })
    );
  };

  it("create orders", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
  });

  const cancelOrder = async (depl, orderID, amount) => {
    const vault = await depl.vaultAtIdx(0);
    const order = await vault.orderInfo(depl.tokens.tka.address, orderID);
    const resp = await vault.cancelOrder(
      orderID,
      amount || 0,
      order.trader,
      0,
      {
        from: order.trader,
      }
    );
    const logs = resp.logs.filter((e) => e.event == "OrderCanceled");
    if (logs.length != 1) {
      throw new Error("invalid number of events");
    }
    if (logs[0].args.token != depl.tokens.tka.address) {
      throw new Error("token address mismatch");
    }
    if (logs[0].args.id != toBigInt(orderID)) {
      throw new Error("order id mismatch");
    }
    if (
      logs[0].args.amount !=
      (amount == 0 || amount == 0n ? order.amount : amount)
    ) {
      throw new Error("token address mismatch");
    }
    depl.vaultTrackers[0].cancelOrder(orderID, amount);
  };

  const cancelOrders = (depl, ids) =>
    Promise.all(ids.map((id) => cancelOrder(depl, id, 0)));

  it("remove all orders except the first and last", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    depl.vaultTrackers[0].orders.sort();
    await cancelOrders(
      depl,
      depl.vaultTrackers[0].orders.orders[depl.tokens.tka.address]
        .slice(1, -1)
        .map((order) => order.orderID)
    );
    await depl.vaultTrackers[0].verifyOrders();
  });

  it("remove all orders except one", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    depl.vaultTrackers[0].orders.sort();
    const orders = depl.vaultTrackers[0].orders.orders[depl.tokens.tka.address];
    const order = orders[Math.floor(Math.random() * orders.length)];
    await cancelOrders(
      depl,
      orders.map((v) => v.orderID).filter((id) => id != order.orderID)
    );
    await depl.vaultTrackers[0].verifyOrders();
  });

  it("remove all", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    depl.vaultTrackers[0].orders.sort();
    const orders = depl.vaultTrackers[0].orders.orders[depl.tokens.tka.address];
    await cancelOrders(
      depl,
      orders.map((v) => v.orderID)
    );
    await depl.vaultTrackers[0].verifyOrders();
  });

  it("remove first", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    depl.vaultTrackers[0].orders.sort();
    await cancelOrder(
      depl,
      depl.vaultTrackers[0].orders.orders[depl.tokens.tka.address][0].orderID,
      0
    );
    await depl.vaultTrackers[0].verifyOrders();
  });

  it("remove last", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    depl.vaultTrackers[0].orders.sort();
    await cancelOrder(
      depl,
      depl.vaultTrackers[0].orders.orders[depl.tokens.tka.address].slice(-1)[0]
        .orderID,
      0
    );
    await depl.vaultTrackers[0].verifyOrders();
  });

  it("remove all and add again", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    depl.vaultTrackers[0].orders.sort();
    const orders = depl.vaultTrackers[0].orders.orders[depl.tokens.tka.address];
    await cancelOrders(
      depl,
      orders.map((v) => v.orderID)
    );
    await depl.vaultTrackers[0].verifyOrders();
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
  });

  it("create order and cancel partially", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    depl.vaultTrackers[0].orders.sort();
    const order =
      depl.vaultTrackers[0].orders.orders[depl.tokens.tka.address][0];
    await cancelOrder(depl, order.orderID, order.amount / 2n);
    await depl.vaultTrackers[0].verifyOrders();
  });
});
