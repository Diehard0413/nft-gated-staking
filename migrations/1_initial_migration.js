const UBXSToken = artifacts.require("UBXSToken");
const UBXSStaking = artifacts.require("UBXSStaking");

module.exports = async (deployer) => {
    await deployer.deploy(UBXSToken, "UBXSToken", "UBXS");
    const token = await UBXSToken.deployed();
    console.log("UBXSToken", token.address);

    const ubxsTokenAddress = "YOUR_UBXS_TOKEN_ADDRESS";
    const oracleAddress = "YOUR_CHAINLINK_ORACLE_ADDRESS";
    const jobId = "YOUR_CHAINLINK_JOB_ID";
    const fee = "YOUR_CHAINLINK_FEE";
    const apiUrl = "YOUR_API_URL";
    const maxMaticDeposit = "YOUR_MAX_MATIC_DEPOSIT";
    const linkTokenAddress = "YOUR_LINK_TOKEN_ADDRESS";
  
    await deployer.deploy(UBXSStaking, ubxsTokenAddress, oracleAddress, jobId, fee, apiUrl, maxMaticDeposit, linkTokenAddress);
    const stakingContract = await UBXSStaking.deployed();
    console.log("UBXSStaking", stakingContract.address);
};