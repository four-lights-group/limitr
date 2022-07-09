const { newDeployment, generateTokensSpecs, ADDRESS_ZERO } = require("./util");
const LimitrVault = artifacts.require("LimitrVault");
const IERC20 = artifacts.require("IERC20");

[LimitrVault, IERC20].forEach((a) => {
  a.numberFormat = "BigInt";
});

const createVaults = async (owner) => {
  const depl = await newDeployment(
    generateTokensSpecs(owner, {
      A: 18n,
      B: 12n,
      C: 8n,
      D: 18n,
      E: 10n,
    })
  );
  const tokens = Object.keys(depl.tokens);
  await Promise.all(
    tokens
      .slice(1)
      .map((t) => [tokens[0], t])
      .map((pair) =>
        depl.registry.createVault(
          depl.tokens[pair[0]].address,
          depl.tokens[pair[1]].address
        )
      )
  );
  return depl;
};

const createOrder = async (vault, token, price, amount, owner) => {
  await token.approve(vault.address, amount, { from: owner });
  await vault.newOrder(token.address, price, amount, owner, 0, {
    from: owner,
  });
};

const createOrders = async (depl, owners) => {
  let idx = 0;
  while (true) {
    try {
      var a = await depl.registry.vault(idx);
    } catch {
      break;
    }
    idx++;
    const vault = await LimitrVault.at(a);
    const t0 = await vault.token0().then((t) => IERC20.at(t));
    const t0Decimals = BigInt(await t0.decimals());
    const t1 = await vault.token1().then((t) => IERC20.at(t));
    const t1Decimals = BigInt(await t1.decimals());
    await [
      [t0, 15n * 10n ** (t1Decimals - 1n), 2n * 10n ** t0Decimals, owners[0]],
      [t0, 17n * 10n ** (t1Decimals - 1n), 2n * 10n ** t0Decimals, owners[0]],
      [t1, 17n * 10n ** (t0Decimals - 1n), 2n * 10n ** t1Decimals, owners[0]],
      [t1, 19n * 10n ** (t0Decimals - 1n), 2n * 10n ** t1Decimals, owners[0]],
    ].reduce(
      (ac, v) => ac.then(() => createOrder(vault, ...v)),
      Promise.resolve(undefined)
    );
  }
};

const tradeAll = async (vault, wantToken, gotToken, traders) => {
  const lastPrice = await vault
    .prices(wantToken.address, 0, 5)
    .then((r) => r.filter((v) => v).slice(-1)[0]);
  const liquidity = await vault.totalLiquidity(wantToken.address);
  const cost = await vault.costAtMaxPrice(
    wantToken.address,
    liquidity,
    lastPrice
  );
  const fee = await vault.feeFor(cost.amountIn);
  const amount = cost.amountIn + fee;
  await gotToken.approve(vault.address, amount);
  await vault.tradeAtMaxPrice(
    wantToken.address,
    lastPrice,
    amount,
    traders[0],
    0
  );
};

const tradeAllOrders = async (depl, traders) => {
  let idx = 0;
  while (true) {
    try {
      var a = await depl.registry.vault(idx);
    } catch {
      break;
    }
    idx++;
    const vault = await LimitrVault.at(a);
    const t0 = await vault.token0().then((t) => IERC20.at(t));
    const t1 = await vault.token1().then((t) => IERC20.at(t));
    await tradeAll(vault, t0, t1, traders);
    await tradeAll(vault, t1, t0, traders);
  }
};

const withdrawAll = async (depl, traders) => {
  let idx = 0;
  while (true) {
    try {
      var a = await depl.registry.vault(idx);
    } catch {
      break;
    }
    idx++;
    const vault = await LimitrVault.at(a);
    const t0 = await vault.token0().then((t) => IERC20.at(t));
    const t1 = await vault.token1().then((t) => IERC20.at(t));
    await vault.withdraw(t0.address, traders[0], 0);
    await vault.withdraw(t1.address, traders[0], 0);
  }
};

contract("LimitrVaultScanner", (accounts) => {
  it("reports the correct list of vaults with open orders and available balance", async () => {
    const noZeroAddress = (r) => r.filter((a) => a != ADDRESS_ZERO);
    const depl = await createVaults(accounts[0]);
    // check memorable
    assert.isTrue(
      (await depl.scanner.memorableAll(accounts[0]).then(noZeroAddress))
        .length == 0n
    );
    // check open orders
    assert.isTrue(
      (await depl.scanner.openOrdersAll(accounts[0]).then(noZeroAddress))
        .length == 0n
    );
    // check available balance
    assert.isTrue(
      (await depl.scanner.availableBalancesAll(accounts[0]).then(noZeroAddress))
        .length == 0n
    );
    // create orders
    await createOrders(depl, accounts);
    // should have orders on all vaults
    assert.isTrue(
      (await depl.scanner.openOrdersAll(accounts[0]).then(noZeroAddress))
        .length == 4n
    );
    // no available balance yet
    assert.isTrue(
      (await depl.scanner.availableBalancesAll(accounts[0]).then(noZeroAddress))
        .length == 0n
    );
    // all vaults are memorable
    assert.isTrue(
      (await depl.scanner.memorableAll(accounts[0]).then(noZeroAddress))
        .length == 4n
    );
    // buy all orders
    await tradeAllOrders(depl, accounts);
    // no orders
    assert.isTrue(
      (await depl.scanner.openOrdersAll(accounts[0]).then(noZeroAddress))
        .length == 0n
    );
    // got balance available on all vaults
    assert.isTrue(
      (await depl.scanner.availableBalancesAll(accounts[0]).then(noZeroAddress))
        .length == 4n
    );
    // all vaults are memorable
    assert.isTrue(
      (await depl.scanner.memorableAll(accounts[0]).then(noZeroAddress))
        .length == 4n
    );
    // withdraw from all vaults
    await withdrawAll(depl, accounts);
    // no orders
    assert.isTrue(
      (await depl.scanner.openOrdersAll(accounts[0]).then(noZeroAddress))
        .length == 0n
    );
    // no balance
    assert.isTrue(
      (await depl.scanner.availableBalancesAll(accounts[0]).then(noZeroAddress))
        .length == 0n
    );
    // not memorable
    assert.isTrue(
      (await depl.scanner.memorableAll(accounts[0]).then(noZeroAddress))
        .length == 0n
    );
  });

  it("reports the correct list of vaults for a given token", async () => {
    const depl = await createVaults(accounts[0]);
    const vaults = await depl.scanner
      .tokenAll(depl.tokens.tka.address)
      .then((r) => r.filter((v) => v != ADDRESS_ZERO));
    assert.isTrue(vaults.length == 4);
    assert.isTrue(
      await Promise.all(
        Object.keys(depl.tokens)
          .filter((t) => t != "tka")
          .map((tk) => depl.scanner.tokenAll(depl.tokens[tk].address))
      ).then(
        (r) =>
          r
            .map((r) => r.filter((v) => v != ADDRESS_ZERO).length != 1)
            .filter((v) => v).length == 0
      )
    );
  });
});
