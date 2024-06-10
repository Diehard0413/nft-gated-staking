const UBXSToken = artifacts.require("UBXSToken");
const StakingContract = artifacts.require("StakingContract");

module.exports = async (deployer) => {
    await deployer.deploy(UBXSToken, "UBXSToken", "UBXS");
    const token = await UBXSToken.deployed();
    console.log("UBXSToken", token.address);

    // await deployer.deploy(StakingContract, ...);
    // const stakingContract = await UBXSStaking.deployed();
    // console.log("UBXSStaking", stakingContract.address);
};