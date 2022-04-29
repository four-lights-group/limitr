const {
  assertReason,
  twoTokenDeployment,
  vaultNewSellOrder,
  ADDRESS_ZERO,
} = require("./util");

contract("LimitrVault", (accounts) => {
  const createOrder = async (depl) =>
    await vaultNewSellOrder(
      await depl.vaultAtIdx(0),
      depl.tokens.tka,
      2n * 10n ** (await depl.tokens.tkb.decimals()),
      10n ** (await depl.tokens.tka.decimals()),
      accounts[0]
    );

  it("can't transfer or cancel without permission", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    await createOrder(depl);
    try {
      await vault.cancelOrder(1, 0, accounts[1], 0, {
        from: accounts[1],
      });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheOwnerApprovedOrOperator(err);
    }
    try {
      await vault.safeTransferFrom(accounts[0], accounts[1], 1, {
        from: accounts[1],
      });
      assert.isTrue(false);
    } catch (err) {
      assertReason.notTheOwnerApprovedOrOperator(err);
    }
  });

  it("owner can transfer and cancel", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    await createOrder(depl);
    const logs = (
      await vault.safeTransferFrom(accounts[0], accounts[1], 1)
    ).logs.filter((e) => e.event == "Transfer");
    const order = await vault.orderInfo(depl.tokens.tka.address, 1n);
    assert.isTrue(logs.length == 1);
    assert.isTrue(logs[0].args.from == accounts[0]);
    assert.isTrue(logs[0].args.to == accounts[1]);
    assert.isTrue(logs[0].args.tokenId == 1n);
    const resp = await vault.cancelOrder(1, 0, accounts[1], 0, {
      from: accounts[1],
    });
    const burnLogs = resp.logs.filter((e) => e.event == "Transfer");
    assert.isTrue(burnLogs.length == 1);
    assert.isTrue(burnLogs[0].args.from == accounts[1]);
    assert.isTrue(burnLogs[0].args.to == ADDRESS_ZERO);
    assert.isTrue(burnLogs[0].args.tokenId == 1n);
    const cancelLogs = resp.logs.filter((e) => e.event == "OrderCanceled");
    assert.isTrue(cancelLogs.length == 1);
    assert.isTrue(cancelLogs[0].args.token == depl.tokens.tka.address);
    assert.isTrue(cancelLogs[0].args.id == 1n);
    assert.isTrue(cancelLogs[0].args.amount == order.amount);
  });

  it("approved can transfer and cancel", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    await createOrder(depl);
    const approveLogs = (await vault.approve(accounts[1], 1)).logs.filter(
      (e) => e.event == "Approval"
    );
    assert.isTrue(approveLogs.length == 1);
    assert.isTrue(approveLogs[0].args.owner == accounts[0]);
    assert.isTrue(approveLogs[0].args.approved == accounts[1]);
    assert.isTrue(approveLogs[0].args.tokenId == 1n);
    assert.isTrue((await vault.getApproved(1)) == accounts[1]);
    await vault.safeTransferFrom(accounts[0], accounts[1], 1, {
      from: accounts[1],
    });
    await vault.approve(accounts[2], 1, { from: accounts[1] });
    await vault.cancelOrder(1, 0, accounts[2], 0, {
      from: accounts[2],
    });
  });

  it("operator can transfer and cancel", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    await createOrder(depl);
    const approveLogs = (await vault.setApprovalForAll(accounts[1], true)).logs;
    assert.isTrue(approveLogs.length == 1);
    assert.isTrue(approveLogs[0].args.owner == accounts[0]);
    assert.isTrue(approveLogs[0].args.operator == accounts[1]);
    assert.isTrue(approveLogs[0].args.approved == true);
    assert.isTrue(await vault.isApprovedForAll(accounts[0], accounts[1]));
    await vault.safeTransferFrom(accounts[0], accounts[1], 1, {
      from: accounts[1],
    });
    await vault.setApprovalForAll(accounts[2], true, { from: accounts[1] });
    await vault.cancelOrder(1, 0, accounts[2], 0, {
      from: accounts[2],
    });
  });

  it("returns the correct balance (ERC721)", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    for (let i = 0n; i < 10n; i++) {
      assert.isTrue((await vault.balanceOf(accounts[0])) == i);
      await createOrder(depl);
      assert.isTrue((await vault.balanceOf(accounts[0])) == i + 1n);
    }
    await vault.cancelOrder(1, 0, accounts[0], 0);
    assert.isTrue((await vault.balanceOf(accounts[0])) == 9n);
    await vault.safeTransferFrom(accounts[0], accounts[1], 2);
    assert.isTrue((await vault.balanceOf(accounts[0])) == 8n);
  });

  it("returns the correct order owner (ERC721)", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    for (let i = 0n; i < 5n; i++) {
      await createOrder(depl);
      assert.isTrue((await vault.ownerOf(i + 1n)) == accounts[0]);
    }
    await vault.safeTransferFrom(accounts[0], accounts[1], 1);
    assert.isTrue((await vault.ownerOf(1)) == accounts[1]);
  });

  it("the router is always allowed", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    await createOrder(depl);
    assert.isTrue(await vault.isAllowed(depl.router.address, 1n));
  });
});
