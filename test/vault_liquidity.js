const { twoTokenDeployment, vaultNewSellOrders, objEqual } = require("./util");

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
    await depl.vaultTrackers[0].newSellOrders(
      orders.map((order) => {
        order[0] = order[0].address;
        return order;
      })
    );
  };
  const expLiquidity = async (depl) => {
    return [
      [
        12n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        35n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        13n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        50n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        14n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        20n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        15n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        20n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        16n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        40n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        17n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        40n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
    ];
  };

  it("returns the correct liquidity per price", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    const vol = await expLiquidity(depl);
    const vault = await depl.vaultAtIdx(0);
    const prices = await vault
      .prices(
        depl.tokens.tka.address,
        0,
        depl.vaultTrackers[0].orders.orders[depl.tokens.tka.address].length * 2
      )
      .then((prices) => prices.map((p) => p).filter((p) => p != 0n));
    assert.isTrue(prices.length == vol.length);
    const vaultLiquidity = await Promise.all(
      prices.map((price) =>
        vault
          .liquidityByPrice(depl.tokens.tka.address, price)
          .then((v) => [price, v])
      )
    );
    assert.isTrue(objEqual(vaultLiquidity, vol));
  });

  it("returns the correct total liquidity", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    await depl.vaultTrackers[0].verifyOrders();
    const volTotal = await expLiquidity(depl).then((r) =>
      r.map((v) => v[1]).reduce((ac, v) => ac + v, 0n)
    );
    const vault = await depl.vaultAtIdx(0);
    assert.isTrue(
      volTotal == (await vault.totalLiquidity(depl.tokens.tka.address))
    );
  });
});
