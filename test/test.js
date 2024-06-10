const UBXSToken = artifacts.require("UBXSToken");
const StakingContract = artifacts.require("StakingContract");

contract('test for all', async accounts => {
    let token;
    let stakingContract;

    before(async () => {
        token = await UBXSToken.deployed();
        // stakingContract = await StakingContract.deployed();

        console.log(accounts);

        console.log("Token: ", token.address);
        // console.log("StakingContract: ", stakingContract.address);
    })

    it('distribution of token', async () => {

    })
})