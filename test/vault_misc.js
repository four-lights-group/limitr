const {
  twoTokenDeployment,
  vaultNewSellOrder,
  vaultBuyMaxPrice,
  assertReason,
} = require("./util");

contract("LimitrVault", (accounts) => {
  it("returns the correct vault implementation address", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    assert.isTrue(
      (await vault.implementationAddress()) == depl.vaultImplementation.address
    );
  });

  it("returns the correct version (1)", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    assert.isTrue((await vault.implementationVersion()) == 1);
  });

  it("returns the correct registry address", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    assert.isTrue((await vault.registry()) == depl.registry.address);
  });

  it("returns the correct tokens addresses", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    const expTokens = [depl.tokens.tka.address, depl.tokens.tkb.address];
    assert.isTrue(
      [(await vault.token0(), await vault.token1())].filter(
        (a) => !expTokens.includes(a)
      ).length == 0
    );
  });

  it("ensure that withdrawFor can only be called by the router", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    const price = 12n * 10n ** ((await depl.tokens.tkb.decimals()) - 1n);
    const amount = 2n * 10n ** (await depl.tokens.tka.decimals());
    await vaultNewSellOrder(vault, depl.tokens.tka, price, amount, accounts[0]);
    const cost = await vault.costAtMaxPrice(
      depl.tokens.tka.address,
      amount,
      price
    );
    const fee = await vault.feeFor(cost.amountIn);
    await vaultBuyMaxPrice(
      vault,
      depl.tokens.tka,
      depl.tokens.tkb,
      price,
      cost.amountIn + fee,
      accounts[0]
    );
    try {
      await vault.withdrawFor(
        depl.tokens.tkb.address,
        accounts[0],
        accounts[1],
        0
      );
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheRouter(err);
    }
  });
});
