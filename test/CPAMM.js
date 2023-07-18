const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AMM_CPAMM", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployCPAMM() {
    const ONE_GWEI = 1_000_000_000;

    const lockedAmount = ONE_GWEI;

    // Contracts are deployed using the first signer/account by default
    const [owner, account1, account2] = await ethers.getSigners();
    const supply1 = 10000;
    const supply2 = 20000;
    const supplyUsers = 5000;

    const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
    const token1 = await GovernanceToken.deploy(
      ethers.parseEther(supply1.toString())
    );
    await token1
      .connect(owner)
      .mint(account1.address, ethers.parseEther(supplyUsers.toString()));

    const UtilityToken = await ethers.getContractFactory("UtilityToken");
    const token2 = await UtilityToken.deploy(
      ethers.parseEther(supply2.toString())
    );
    await token2
      .connect(owner)
      .mint(account2.address, ethers.parseEther(supplyUsers.toString()));

    const CPAMM = await ethers.getContractFactory("CPAMM");
    const cpamm = await CPAMM.deploy(token1.target, token2.target);

    console.log(`\tGovernance Token deployed to: ${token1.target}`);
    console.log(`\tUtility Token deployed to: ${token2.target}`);
    console.log(`\tCPAMM deployed to: ${cpamm.target}`);
    console.log(`\tDeployer: ${owner.address}`);

    return { cpamm, token1, token2, owner, account1, account2 };
  }

  describe("Constant Product AMM", function () {
    let contract;
    let owner, account1, account2;
    let token1, token2;
    let supply1, supply2;

    before(async () => {
      const deployedInfo = await loadFixture(deployCPAMM);
      contract = deployedInfo.cpamm;
      token1 = deployedInfo.token1;
      token2 = deployedInfo.token2;
      owner = deployedInfo.owner;
      account1 = deployedInfo.account1;
      account2 = deployedInfo.account2;
      supply1 = await token1.balanceOf(owner.address);
      supply2 = await token2.balanceOf(owner.address);
    });

    it("Should test to add liquidity in the pool.", async function () {
      await token1.connect(owner).approve(contract.target, supply1);
      await token2.connect(owner).approve(contract.target, supply2);

      await contract.addLiquidity(supply1, supply2);

      expect(await token1.balanceOf(contract.target)).to.be.equal(supply1);
      expect(await token2.balanceOf(contract.target)).to.be.equal(supply2);

      const inToken1 = 100;
      const outToken2 = await contract.getSwapRate(token1.target, inToken1);
      expect(outToken2).to.be.equal(inToken1 * 2 - (3 * inToken1) / 100);
    });

    it("Should test to swap tokens in the pool.", async function () {
      const inToken1 = ethers.parseEther("1000");

      await token1.connect(account1).approve(contract.target, inToken1);
      await contract.connect(account1).swap(token1.target, inToken1);

      expect(await token1.balanceOf(contract.target)).to.be.equal(
        supply1 + inToken1
      );
    });

    it("Should test to get swap rates of the pool.", async function () {
      const inToken1 = 100;
      const outToken2 = await contract.getSwapRate(token1.target, inToken1);
      console.log(`\tin:${inToken1} => out:${outToken2.toString()}`);
    });

    it("Should test error cases of the pool.", async function () {
      await expect(contract.swap(ethers.ZeroAddress, 100)).to.revertedWith(
        "invalid token"
      );

      await expect(contract.swap(token1.target, 0)).to.revertedWith(
        "amount in = 0"
      );

      await expect(contract.addLiquidity(100, 100)).to.revertedWith(
        "x / y != dx / dy"
      );

      await expect(contract.addLiquidity(0, 0)).to.revertedWith("shares = 0");
    });
  });
});
