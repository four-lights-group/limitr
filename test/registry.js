const { assertReason, newDeployment, generateTokensSpecs } = require("./util");

contract("LimitrRegistry", (accounts) => {
  const deploy = (owner) =>
    newDeployment(generateTokensSpecs(owner, { A: 18n, B: 12n }));

  it("only admin can change URLs", async () => {
    const depl = await deploy(accounts[0]);
    assert.isTrue((await depl.registry.URLS()).length == 0);
    const URL1 = "https://limitr.com";
    const URL2 = "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";
    const URL3 = "ipfs://QmSgvgwxZGaBLqkGyWemEDqikCqU52XxsYLKtdy3vGZ8uq";
    try {
      await depl.registry.addURL(URL1, { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    await depl.registry.addURL(URL1);
    await depl.registry.addURL(URL2);
    let urls = await depl.registry.URLS();
    assert.isTrue(urls[0] == URL1);
    assert.isTrue(urls[1] == URL2);
    try {
      await depl.registry.updateURL(1, URL3, { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    await depl.registry.updateURL(1, URL3);
    urls = await depl.registry.URLS();
    assert.isTrue(urls[0] == URL1);
    assert.isTrue(urls[1] == URL3);
    try {
      await depl.registry.removeURL(1, { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    await depl.registry.removeURL(1);
    urls = await depl.registry.URLS();
    assert.isTrue(urls.length == 1);
    assert.isTrue(urls[0] == URL1);
    await depl.registry.removeURL(0);
    urls = await depl.registry.URLS();
    assert.isTrue(urls.length == 0);
  });

  it("only the admin can change the admin", async () => {
    const depl = await deploy(accounts[0]);
    try {
      await depl.registry.transferAdmin(accounts[1], { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    await depl.registry.transferAdmin(accounts[1]);
    assert.isTrue((await depl.registry.admin()) == accounts[1]);
  });

  it("only the admin can change the fee receiver", async () => {
    const depl = await deploy(accounts[0]);
    try {
      await depl.registry.setFeeReceiver(accounts[1], { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    await depl.registry.setFeeReceiver(accounts[1]);
    assert.isTrue((await depl.registry.feeReceiver()) == accounts[1]);
  });

  it("only the admin can change the vault implementation", async () => {
    const depl = await deploy(accounts[0]);
    try {
      await depl.registry.setVaultImplementation(accounts[1], {
        from: accounts[1],
      });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    await depl.registry.setVaultImplementation(accounts[1]);
    assert.isTrue((await depl.registry.vaultImplementation()) == accounts[1]);
  });
});
