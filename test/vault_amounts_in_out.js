const { twoTokenDeployment, vaultNewSellOrders } = require("./util");

contract("LimitrVault", (accounts) => {
  it("returnAtPrice and costAtPrice return the correct values", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    const buyToken = depl.tokens.tka.address;
    const nTokens = 3n;
    const amount = nTokens * 10n ** depl.tokenSpecs.tka.decimals;
    const price = 2n * 10n ** depl.tokenSpecs.tkb.decimals;
    const cost = await vault.costAtPrice(buyToken, amount, price);
    assert.isTrue(cost == nTokens * price);
    const ret = await vault.returnAtPrice(buyToken, cost, price);
    assert.isTrue(ret == amount);
  });

  const createOrders = async (depl) => {
    const vault = await depl.vaultAtIdx(0);
    await vaultNewSellOrders(
      vault,
      [
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
      ].map((v) => [depl.tokens.tka].concat(v).concat([accounts[0]]))
    );
  };

  it("returnAtMaxPrice and costAtMaxPrice return the correct values", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const maxAmountOut = 100n * 10n ** (depl.tokenSpecs.tka.decimals - 1n);
    const maxPrice = 13n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n);
    let amtInOut = await vault.costAtMaxPrice(
      depl.tokens.tka.address,
      maxAmountOut,
      maxPrice
    );
    const expCost = 107n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n);
    const expReturn = 85n * 10n ** (depl.tokenSpecs.tka.decimals - 1n);
    assert.isTrue(expCost == amtInOut.amountIn);
    assert.isTrue(expReturn == amtInOut.amountOut);
    amtInOut = await vault.returnAtMaxPrice(
      depl.tokens.tka.address,
      expCost * 2n,
      maxPrice
    );
    assert.isTrue(expCost == amtInOut.amountIn);
    assert.isTrue(expReturn == amtInOut.amountOut);
  });
});
