const {
  twoTokenDeployment,
  vaultNewSellOrders,
  vaultBuyMaxPrice,
  formatAmount,
  assertReason,
} = require("./util");
IERC20 = artifacts.require("IERC20");

IERC20.numberFormat = "BigInt";

contract("LimitrVault", (accounts) => {
  const convertOrdersInfo = (orders) =>
    orders.id
      .filter((id) => id)
      .map((id, idx) => ({
        orderID: id,
        price: orders.price[idx],
        amount: orders.amount[idx],
        trader: orders.trader[idx],
      }));

  const createOrders = async (depl) => {
    const vault = await depl.vaultAtIdx(0);
    const tkaOrders = [
      [13n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n), 1n],
      [
        13n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        50n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [13n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n), 1n],
      [
        131n * 10n ** (depl.tokenSpecs.tkb.decimals - 2n),
        50n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        132n * 10n ** (depl.tokenSpecs.tkb.decimals - 2n),
        50n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        133n * 10n ** (depl.tokenSpecs.tkb.decimals - 2n),
        85n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
      [
        15n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
        100n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
      ],
    ].map((v) => [depl.tokens.tka].concat(v).concat([accounts[0]]));
    await vaultNewSellOrders(vault, tkaOrders);
    const tkbOrders = [
      [7n * 10n ** (depl.tokenSpecs.tka.decimals - 1n), 1n],
      [
        7n * 10n ** (depl.tokenSpecs.tka.decimals - 1n),
        100n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
      ],
      [7n * 10n ** (depl.tokenSpecs.tka.decimals - 1n), 1n],
      [
        71n * 10n ** (depl.tokenSpecs.tka.decimals - 2n),
        100n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
      ],
      [
        72n * 10n ** (depl.tokenSpecs.tka.decimals - 2n),
        100n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
      ],
      [
        73n * 10n ** (depl.tokenSpecs.tka.decimals - 2n),
        125n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
      ],
      [
        80n * 10n ** (depl.tokenSpecs.tka.decimals - 2n),
        100n * 10n ** (depl.tokenSpecs.tkb.decimals - 1n),
      ],
    ].map((v) => [depl.tokens.tkb].concat(v).concat([accounts[0]]));
    await vaultNewSellOrders(vault, tkbOrders);
  };

  const removeNumericalKeys = (obj) =>
    Object.fromEntries(
      Object.entries(obj).filter((e) => Number.isNaN(Number.parseInt(e[0])))
    );

  it("can take arbitrage profit", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    await createOrders(depl);
    const vault = await depl.vaultAtIdx(0);
    const profitToken = depl.tokens.tka.address;
    const maxAmountIn = 100n * 10n ** (depl.tokenSpecs.tka.decimals - 1n);
    const maxPrice = 7n * 10n ** (depl.tokenSpecs.tka.decimals - 1n);
    const getBalances = async (acc) => ({
      profit: await depl.tokens.tka.balanceOf(acc),
      other: await depl.tokens.tkb.balanceOf(acc),
    });
    const preBalances = {
      [accounts[0]]: await getBalances(accounts[0]),
      [accounts[1]]: await getBalances(accounts[1]),
    };
    const expAmountsOut = await vault.arbitrageAmountsOut(
      profitToken,
      maxAmountIn,
      maxPrice
    );
    const expBalances = {
      profit: expAmountsOut.profitOut - expAmountsOut.profitIn,
      other: expAmountsOut.otherOut,
    };
    await vault.arbitrageTrade(
      profitToken,
      maxAmountIn,
      maxPrice,
      accounts[1],
      0
    );
    const postBalances = {
      [accounts[0]]: await getBalances(accounts[0]),
      [accounts[1]]: await getBalances(accounts[1]),
    };
    console.log(expBalances);
    const bals = {
      profit:
        postBalances[accounts[1]].profit - preBalances[accounts[1]].profit,
      other: postBalances[accounts[1]].other - preBalances[accounts[1]].other,
    };
    console.log(bals);
    assert.isTrue(bals.profit > 0n);
  });
});
