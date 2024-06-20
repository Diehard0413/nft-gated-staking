// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/SafeMath.sol";

contract UBXSStaking is ChainlinkClient, ERC721, ConfirmedOwner {
    using Chainlink for Chainlink.Request;
    using SafeMath for uint256;
    using Strings for uint256;

    IERC20 public ubxsToken;
    uint256 public totalUBXS;
    uint256 public discountAmount = 100;
    uint256 public maxMaticDeposit;
    uint256 public nftCounter;
    address public oracle;
    bytes32 public jobId;
    uint256 public fee;
    string public apiUrl;
    address public linkTokenAddress;

    struct Stake {
        uint256 nftId;
        uint256 maticAmount;
        uint256 claimableUBXS;
        uint256 stakeTime;
    }

    mapping(address => Stake) public stakes;

    event MaticDeposited(address indexed user, uint256 amount, uint256 nftId);
    event MaticWithdrawn(address indexed admin, uint256 amount);
    event LinkRescued(address indexed user, uint256 amount);
    event UBXSRescued(address indexed user, uint256 amount);
    event UBXSWithdrawn(address indexed user, uint256 amount);    
    event UBXSToppedUp(address indexed admin, uint256 amount);

    constructor (
        address _ubxsToken,
        address _oracle,
        string memory _jobId,
        uint256 _fee,
        string memory _apiUrl,
        uint256 _maxMaticDeposit,
        address _linkTokenAddress
    ) ERC721("StakedMaticNFT", "sMATIC") ConfirmedOwner(msg.sender) {
        ubxsToken = IERC20(_ubxsToken);
        oracle = _oracle;
        jobId = stringToBytes32(_jobId);
        fee = _fee;
        apiUrl = _apiUrl;
        maxMaticDeposit = _maxMaticDeposit;
        linkTokenAddress = _linkTokenAddress;
        _setChainlinkToken(_linkTokenAddress);
    }

    function depositMatic(string calldata pathUrl) external payable {
        require(stakes[msg.sender].stakeTime > 0, "Already deposited user");
        require(msg.value > 0, "Must deposit Matic");
        require(address(this).balance <= maxMaticDeposit, "Max Matic deposit limit reached");

        uint256 nftId = nftCounter;
        _mint(msg.sender, nftId);
        nftCounter++;

        Stake memory newStake = Stake({
            nftId: nftId,
            maticAmount: msg.value,
            claimableUBXS: 0,
            stakeTime: block.timestamp
        });

        stakes[msg.sender] = newStake;

        requestUBXSPrice(pathUrl);

        emit MaticDeposited(msg.sender, msg.value, nftId);
    }

    function requestUBXSPrice(string calldata pathUrl) internal {
        Chainlink.Request memory req = _buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        req._add("get", apiUrl);
        req._add("path", pathUrl);
        _sendChainlinkRequestTo(oracle, req, fee);
    }

    function fulfill(bytes32 _requestId, uint256 ubxsPrice, address user, uint256 maticAmount) public recordChainlinkFulfillment(_requestId) {
        Stake storage stake = stakes[user];
        require(stake.stakeTime > 0, "Stake not found or invalid");

        uint256 claimableUBXS = maticAmount.mul(ubxsPrice).mul(1000 + discountAmount).div(1000).div(10**18);
        stake.claimableUBXS = claimableUBXS;
        totalUBXS += claimableUBXS;
    }

    function withdrawUBXS() external {
        Stake storage stake = stakes[msg.sender];
        require(stake.stakeTime > 0, "Stake not found or invalid");
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

    function rescueUBXS() external onlyOwner {
        uint256 balance = ubxsToken.balanceOf(address(this));
        require(ubxsToken.transfer(msg.sender, balance), "Unable to transfer");

        emit UBXSRescued(msg.sender, balance);
    }

    function rescueLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkTokenAddress);
        uint256 balance = link.balanceOf(address(this));
        require(link.transfer(msg.sender, balance), "Unable to transfer");

        emit LinkRescued(msg.sender, balance);
    }

    function topUpUBXS(uint256 amount) external onlyOwner {
        ubxsToken.transferFrom(msg.sender, address(this), amount);

        emit UBXSToppedUp(msg.sender, amount);
    }

    function setMaxMaticDeposit(uint256 _maxMaticDeposit) external onlyOwner {
        maxMaticDeposit = _maxMaticDeposit;
    }

    function setDiscountAmount(uint256 _discountAmount) external onlyOwner {
        discountAmount = _discountAmount;
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
