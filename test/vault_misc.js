const { twoTokenDeployment, vaultAtIdx } = require("./util");

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

  it("returns the correct token addresses", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    const expTokens = [depl.tokens.tka.address, depl.tokens.tkb.address];
    assert.isTrue(
      [(await vault.token0(), await vault.token1())].filter(
        (a) => !expTokens.includes(a)
      ).length == 0
    );
  });
});
