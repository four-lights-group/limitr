const { assertReason, twoTokenDeployment } = require("./util");

contract("LimitrVault", (accounts) => {
  const initialVaultFee = 2000000000000000n;

  it("only allow the admin to set the fee", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    assert.isTrue((await vault.feePercentage()) == initialVaultFee);
    const newFeePercentage = 1000000000000000n;
    try {
      await vault.setFeePercentage(newFeePercentage, { from: accounts[1] });
      assert.isTrue(false);
    } catch (err) {
      assertReason.onlyForTheAdmin(err);
    }
    const resp = await vault.setFeePercentage(newFeePercentage);
    assert.isTrue((await vault.feePercentage()) == newFeePercentage);
    const logs = resp.logs.filter((e) => e.event == "NewFeePercentage");
    assert.isTrue(logs.length == 1);
    assert.isTrue(logs[0].args.oldFeePercentage == initialVaultFee);
    assert.isTrue(logs[0].args.newFeePercentage == newFeePercentage);
  });

  it("the fee can only decrease", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    const newFeePercentage = 5000000000000000n;
    try {
      await vault.setFeePercentage(newFeePercentage);
      assert.isTrue(false);
    } catch (err) {
      assertReason.canOnlySetASmallerFee(err);
    }
  });

  it("feeOf, feeFor and withoutFee returns the correct values", async () => {
    const depl = await twoTokenDeployment(accounts[0]);
    const vault = await depl.vaultAtIdx(0);
    const feeOf = (v, feePercentage) => (v * feePercentage) / 10n ** 18n;
    const feeFor = (v, feePercentage) =>
      (v * feePercentage) / (10n ** 18n - feePercentage);
    const withoutFee = (v, feePercentage) => v - feeOf(v, feePercentage);
    const withFee = (v, feePercentage) => v + feeFor(v, feePercentage);
    const v = 10n ** (await depl.tokens.tka.decimals());
    assert.isTrue((await vault.feeOf(v)) == feeOf(v, initialVaultFee));
    assert.isTrue((await vault.feeFor(v)) == feeFor(v, initialVaultFee));
    assert.isTrue(
      (await vault.withoutFee(v)) == withoutFee(v, initialVaultFee)
    );
    assert.isTrue((await vault.withFee(v)) == withFee(v, initialVaultFee));
  });
});
