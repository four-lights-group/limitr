const { assertReason, newDeployment, generateTokensSpecs } = require("./util");

contract("LimitrRegistry", (accounts) => {
  const deploy = (owner) =>
    newDeployment(generateTokensSpecs(owner, { A: 18n, B: 12n }));

  it("URL management, Jumpstart implementation", async () => {
    const depl = await deploy(accounts[0]);
    const URIS = {
      https: "https://limitr.com",
      ipfs: "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
      onion:
        "http://haystak5njsmn2hqkewecpaxetahtwhsbsa64jom2k22z5afxhnpxfid.onion",
    };
    try {
      await depl.registry.JS_add("hello", "world", { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    let p = Promise.resolve(undefined);
    Object.entries(URIS).forEach((ent) => {
      p = p.then(() => depl.registry.JS_add(ent[0], ent[1]));
    });
    await p;
    const r = await depl.registry.JS_getAll();
    r[0].forEach((name, idx) => assert.isTrue(URIS[name] === r[1][idx]));
    try {
      await depl.registry.JS_add("https", "hello world");
      assert.isTrue(true == false);
    } catch (err) {
      assertReason.JSM_alreadyExists(err);
    }
    const NEW_URI = "https://limitr.finance";
    try {
      await depl.registry.JS_update("https", NEW_URI, { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    await depl.registry.JS_update("https", NEW_URI);
    assert.isTrue((await depl.registry.JS_get("https")) === NEW_URI);
    try {
      await depl.registry.JS_update("hello", "world");
      assert.isTrue(true == false);
    } catch (err) {
      assertReason.JSM_notFound(err);
    }
    try {
      await depl.registry.JS_remove("https", { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheAdmin(err);
    }
    await depl.registry.JS_remove("https");
    assert.isTrue(
      (await depl.registry.JS_names()).find((v) => v == "https") == undefined
    );
    try {
      await depl.registry.JS_remove("hello");
      assert.isTrue(true == false);
    } catch (err) {
      assertReason.JSM_notFound(err);
    }
    assert.isTrue((await depl.registry.JS_get("https")) == "");
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
