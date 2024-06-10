// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UBXSStaking is ChainlinkClient, ERC721, Ownable {
    using Chainlink for Chainlink.Request;

    IERC20 public ubxsToken;
    uint256 public totalUBXS;
    uint256 public neededUBXS;
    uint256 public discountAmount = 100;
    uint256 public maxMaticDeposit;
    uint256 public nftCounter;
    address public oracle;
    bytes32 public jobId;
    uint256 public fee;
    string public apiUrl;

    struct Stake {
        address staker;
        uint256 maticAmount;
        uint256 claimableUBXS;
        uint256 stakeTime;
    }

    mapping(uint256 => Stake) public stakes;

    event MaticDeposited(address indexed user, uint256 amount, uint256 nftId);
    event UBXSWithdrawn(address indexed user, uint256 amount);
    event MaticWithdrawn(address indexed admin, uint256 amount);
    event UBXSToppedUp(address indexed admin, uint256 amount);

    constructor(
        address _ubxsToken,
        address _oracle,
        string memory _jobId,
        uint256 _fee,
        string memory _apiUrl,
        uint256 _maxMaticDeposit
    ) ERC721("StakedMaticNFT", "sMATIC") {
        ubxsToken = IERC20(_ubxsToken);
        oracle = _oracle;
        jobId = stringToBytes32(_jobId);
        fee = _fee;
        apiUrl = _apiUrl;
        maxMaticDeposit = _maxMaticDeposit;
        setChainlinkToken(LINK);
    }

    function depositMatic() external payable {
        require(msg.value > 0, "Must deposit Matic");
        require(address(this).balance <= maxMaticDeposit, "Max Matic deposit limit reached");

        uint256 nftId = nftCounter;
        _mint(msg.sender, nftId);
        nftCounter++;

        Stake memory newStake = Stake({
            staker: msg.sender,
            maticAmount: msg.value,
            claimableUBXS: 0,
            stakeTime: block.timestamp
        });

        stakes[nftId] = newStake;

        requestUBXSPrice(nftId, msg.value);
        emit MaticDeposited(msg.sender, msg.value, nftId);
    }

    function requestUBXSPrice(uint256 nftId, uint256 maticAmount) internal {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        req.add("get", apiUrl);
        req.add("path", "data.price");
        req.addInt("times", 10**18);
        req.add("sender", Strings.toString(uint256(uint160(msg.sender))));
        req.add("maticAmount", Strings.toString(maticAmount));
        req.add("nftId", Strings.toString(nftId));
        sendChainlinkRequestTo(oracle, req, fee);
    }

    function fulfill(bytes32 _requestId, uint256 ubxsPrice, address user, uint256 maticAmount, uint256 nftId) public recordChainlinkFulfillment(_requestId) {
        Stake storage stake = stakes[nftId];
        require(stake.staker == user, "Stake not found or invalid");

        uint256 claimableUBXS = maticAmount.mul(ubxsPrice).mul(1000 + discountAmount).div(1000).div(10**18);
        stake.claimableUBXS = claimableUBXS;
        totalUBXS += claimableUBXS;
        neededUBXS += claimableUBXS;
    }

    function withdrawUBXS(uint256 nftId) external {
        Stake storage stake = stakes[nftId];
        require(stake.staker == msg.sender, "Not the staker");
        require(block.timestamp >= stake.stakeTime + 30 days, "Cannot withdraw before 30 days");

        uint256 claimableUBXS = stake.claimableUBXS;
        require(claimableUBXS > 0, "No UBXS to withdraw");

        ubxsToken.transfer(msg.sender, claimableUBXS);
        totalUBXS -= claimableUBXS;
        stake.claimableUBXS = 0;

        emit UBXSWithdrawn(msg.sender, claimableUBXS);
    }

    function withdrawMatic() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
        emit MaticWithdrawn(msg.sender, balance);
    }

    function topUpUBXS(uint256 amount) external onlyOwner {
        ubxsToken.transferFrom(msg.sender, address(this), amount);
        neededUBXS = 0;
        emit UBXSToppedUp(msg.sender, amount);
    }

    function setMaxMaticDeposit(uint256 _maxMaticDeposit) external onlyOwner {
        maxMaticDeposit = _maxMaticDeposit;
    }

    function setDiscountAmount(uint256 _discountAmount) external onlyOwner {
        discountAmount = _discountAmount;
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function setJobId(string memory _jobId) external onlyOwner {
        jobId = stringToBytes32(_jobId);
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setApiUrl(string memory _apiUrl) external onlyOwner {
        apiUrl = _apiUrl;
    }

    function stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}