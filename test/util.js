const TokenX = artifacts.require("TokenX");
const WETH = artifacts.require("WETH9");
const LimitrVault = artifacts.require("LimitrVault");
const LimitrRegistry = artifacts.require("LimitrRegistry");
const LimitrRouter = artifacts.require("LimitrRouter");
const LimitrVaultScanner = artifacts.require("LimitrVaultScanner");

[
  TokenX,
  WETH,
  LimitrVault,
  LimitrRegistry,
  LimitrRouter,
  LimitrVaultScanner,
].forEach((a) => {
  a.numberFormat = "BigInt";
});

const toBigInt = (bn) => BigInt(bn.toString());

const objEntries = (obj) =>
  Object.entries(obj).map((e) => ({ key: e[0], value: e[1] }));

const objFromEntries = (ent) =>
  Object.fromEntries(ent.map((e) => [e.key, e.value]));

const expectReason = (err, reason) => assert.isTrue(err.reason == reason);

const assertReason = {
  JSM_alreadyExists: (err) => expectReason(err, "JSM: Already exists"),
  JSM_notFound: (err) => expectReason(err, "JSM: Not found"),
  onlyForTheAdmin: (err) =>
    expectReason(err, "LimitrVault: only for the admin"),
  canOnlySetASmallerFee: (err) =>
    expectReason(err, "LimitrVault: can only set a smaller fee"),
  notTheOwnerApprovedOrOperator: (err) => (
    err, "LimitrVault: not the owner, approved or operator"
  ),
  notTheRouter: (err) => expectReason(err, "LimitrVault: not the router"),
  tradingPaused: (err) => expectReason(err, "LimitrVault: trading is paused"),
  notTheAdmin: (err) => expectReason(err, "LimitrRegistry: not the admin"),
  notAllowed: (err) => expectReason(err, "LimitrRouter: not allowed"),
};

const estimateGas = (func, ...args) => func.estimateGas(...args);

const sendWithExtraGas = (func, args, ratio) =>
  estimateGas(func, ...args)
    .then((gas) => Math.ceil(ratio ? gas * ratio : gas * 1.5))
    .then((gas) => func(...args.concat([{ gas }])));

const deployTokenX = ({ name, symbol, decimals, owner, amount }) =>
  TokenX.new(name, symbol, decimals, owner, amount, { from: owner });

const deploy = {
  tokenX: deployTokenX,
  tokens: (tokensSpec) =>
    Promise.all(
      tokensSpec.map((t) =>
        deployTokenX(t).then((d) => {
          let ac = {};
          ac[t.symbol.toLowerCase()] = d;
          return ac;
        })
      )
    ).then((t) => t.reduce((ac, v) => Object.assign(ac, v), {})),
  vaultImplementation: () => LimitrVault.new(),
  registry: () => LimitrRegistry.new(),
  router: async (registry) => LimitrRouter.new(WETH.address, registry),
  scanner: async (registry) => LimitrVaultScanner.new(registry),
};

const sortOrders = (a, b) =>
  a.price < b.price
    ? -1
    : a.price > b.price
    ? 1
    : a.orderID < b.orderID
    ? -1
    : 1;

const vaultTracker = function (vault) {
  return {
    vault: vault,
    orders: {
      incrementOrderID: function () {
        return ++this.lastID;
      },
      lastID: 0n,
      orders: {},
      sort: function () {
        this.orders = objFromEntries(
          objEntries(this.orders).map((orders) => ({
            key: orders.key,
            value: orders.value.sort(sortOrders),
          }))
        );
      },
    },
    newOrder: function (token, price, amount, owner, dontSort) {
      if (!this.orders.orders[token]) {
        this.orders.orders[token] = [];
      }
      this.orders.orders[token].push({
        orderID: this.orders.incrementOrderID(),
        price,
        amount,
        owner,
      });
      if (!dontSort) {
        this.orders.sort();
      }
    },
    newOrders: function (orders) {
      orders.forEach((order) => this.newOrder(...order.concat([false])));
      this.orders.sort();
    },
    cancelOrder: function (orderID, amount) {
      const token = objEntries(this.orders.orders)
        .map((token) => ({
          value: token.value.filter((v) => v.orderID == orderID),
          key: token.key,
        }))
        .filter((e) => e.value.length != 0)
        .map((e) => e.key)[0];
      const order = this.orders.orders[token].filter(
        (e) => e.orderID == orderID
      )[0];
      order.amount -= amount || order.amount;
      if (!amount) {
        this.orders.orders[token] = this.orders.orders[token].filter(
          (v) => v.amount
        );
      }
    },
    verifyOrders: async function () {
      this.orders.sort();
      const tokenOrders = (token) =>
        this.vault
          .ordersInfo(token, 0, this.orders.orders?.[token]?.length || 1000)
          .then((resp) =>
            resp.id
              .map((id, idx) => ({
                orderID: id,
                price: resp.price[idx],
                amount: resp.amount[idx],
                owner: resp.trader[idx],
              }))
              .filter((v) => v.orderID != 0n)
          );
      const vaultOrders = await Promise.all(
        Object.keys(this.orders.orders).map((token) =>
          tokenOrders(token).then((resp) => ({ key: token, value: resp }))
        )
      ).then((v) => objFromEntries(v));
      if (!objEqual(this.orders.orders, vaultOrders)) {
        throw new Error("order book mismatch");
      }
    },
  };
};

function objEqual(a, b) {
  if (typeof a != "object") {
    return a == b;
  }
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);
  if (keysA.length !== keysB.length) {
    return false;
  }
  if (keysA.map((k) => !keysB.includes(k)).filter((v) => v).length != 0) {
    return false;
  }
  for (let i = 0; i < keysA.length; i++) {
    if (!objEqual(a[keysA[i]], b[keysA[i]])) {
      return false;
    }
  }
  return true;
}

const newDeployment = async (tokensSpecs, feeReceiver) => {
  const a = (await WETH.deployed()).address;
  WETH.numberFormat = "BigInt";
  const r = {
    weth: await WETH.at(a),
    tokens: await deploy.tokens(tokensSpecs),
    tokenSpecs: Object.fromEntries(
      tokensSpecs.map((ent) => [ent.symbol.toLowerCase(), ent])
    ),
    vaultImplementation: await deploy.vaultImplementation(),
    registry: undefined,
    router: undefined,
    scanner: undefined,
    vaultAtIdx: function (idx) {
      return this.registry.vault(idx).then((v) => LimitrVault.at(v));
    },
    vaultTrackers: {},
    trackVaultAtIdx: function (idx) {
      return this.vaultAtIdx(idx)
        .then((v) => vaultTracker(v))
        .then((vt) => (this.vaultTrackers[idx] = vt));
    },
  };
  r.registry = await deploy.registry();
  r.router = await deploy.router(r.registry.address);
  r.scanner = await deploy.scanner(r.registry.address);
  await r.registry.initialize(
    r.router.address,
    r.scanner.address,
    r.vaultImplementation.address
  );
  if (feeReceiver) {
    await r.registry.setFeeReceiver(feeReceiver);
  }
  return r;
};

const generateTokensSpecs = (owner, seed) =>
  objEntries(seed)
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0))
    .map((e) => ({
      name: `Token ${e.key}`,
      symbol: `TK${e.key}`,
      decimals: BigInt(e.value),
      amount: 1000000n * 10n ** e.value,
      owner: owner,
    }));

const twoTokenDeployment = async (owner, feeReceiver) => {
  const depl = await newDeployment(
    generateTokensSpecs(owner, { A: 18n, B: 12n }),
    feeReceiver
  );
  await depl.registry.createVault(
    depl.tokens.tka.address,
    depl.tokens.tkb.address
  );
  await depl.trackVaultAtIdx(0);
  return depl;
};

const ethTokenDeployment = async (owner, feeReceiver) => {
  const depl = await newDeployment(
    generateTokensSpecs(owner, { A: 18n, B: 12n }),
    feeReceiver
  );
  await depl.registry.createVault(depl.tokens.tka.address, depl.weth.address);
  return depl;
};

const vaultNewOrder = async (vault, token, price, amount, owner) => {
  await token.approve(vault.address, amount, { from: owner });
  const resp = await vault.newOrder(token.address, price, amount, owner, 0, {
    from: owner,
  });
  const logs = resp.logs.filter((e) => e.event == "OrderCreated");
  if (logs.length != 1) {
    throw new Error("invalid count of OrderCreated events");
  }
  if (logs[0].args.token != token.address) {
    throw new Error("token address mismatch");
  }
  if (logs[0].args.trader != owner) {
    throw new Error("order owner mismatch");
  }
  if (logs[0].args.price != price) {
    throw new Error("order price mismatch");
  }
  if (logs[0].args.amount != amount) {
    throw new Error("order amount mismatch");
  }
  return resp;
};

const vaultNewOrders = (vault, orders) =>
  orders.reduce(
    (ac, v) => ac.then(() => vaultNewOrder(vault, ...v)),
    Promise.resolve(undefined)
  );

const vaultTradeMaxPrice = async (
  vault,
  wantToken,
  gotToken,
  price,
  maxAmountIn,
  receiver
) => {
  await gotToken.approve(vault.address, maxAmountIn);
  return await vault.tradeAtMaxPrice(
    wantToken.address,
    price,
    maxAmountIn,
    receiver,
    0
  );
};

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";

// amount formatting and parsing
const formatAmount = (amount, decimals) => {
  if (amount === undefined) {
    return undefined;
  }
  decimals = Number(decimals);
  const isNegative = amount < 0;
  let a = String(BigInt(amount));
  if (isNegative) {
    a = a.slice(1);
  }
  if (a.length <= decimals) {
    var i = "";
    var d = a;
  } else {
    let idx = a.length - decimals;
    i = a.slice(0, idx);
    d = a.slice(idx);
  }
  if (i === "") {
    i = "0";
  }
  d = d.padStart(decimals, "0");
  while (d.endsWith("0")) {
    d = d.slice(0, -1);
  }
  return `${isNegative ? "-" : ""}${i}${d.length > 0 ? "." : ""}${d}`;
};

module.exports = {
  assertReason,
  deploy,
  toBigInt,
  objEntries,
  objFromEntries,
  objEqual,
  sendWithExtraGas,
  estimateGas,
  generateTokensSpecs,
  newDeployment,
  twoTokenDeployment,
  ethTokenDeployment,
  vaultNewOrder,
  vaultNewOrders,
  vaultTradeMaxPrice,
  ADDRESS_ZERO,
  formatAmount,
};
