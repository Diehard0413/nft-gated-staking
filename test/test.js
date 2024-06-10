const UBXSToken = artifacts.require("UBXSToken");
const UBXSStaking = artifacts.require("UBXSStaking");

contract('test for all', async accounts => {
    let token;
    let stakingContract;

    before(async () => {
        token = await UBXSToken.deployed();
        // stakingContract = await UBXSStaking.deployed();

        console.log(accounts);

        console.log("Token: ", token.address);
        // console.log("UBXSStaking: ", stakingContract.address);
    })

    it('distribution of token', async () => {

    })
})