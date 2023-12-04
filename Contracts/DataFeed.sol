// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Support/ChainlinkClientUp.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IStaking {
    function fetchData( uint256 _globalStakedBudsCount) external;
} 

contract DataFeed is Initializable, UUPSUpgradeable, ChainlinkClient, OwnableUpgradeable {
    using Chainlink for Chainlink.Request;

    uint256 public volume;
    bytes32 private jobId;
    uint256 private fee;
    string private totalStakedEndpoint;
    IStaking public _staking;

    event RequestVolume(bytes32 indexed requestId, uint256 volume);

    modifier onlyStakingContract {
        require(msg.sender == address(_staking));
        _;
    }

    function initialize(
        address _chainToken, 
        address _oracleAddres,
        address stakingAddress
    ) public initializer{
        setChainlinkToken(_chainToken);
        setChainlinkOracle(_oracleAddres);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; 
        totalStakedEndpoint = "https://ljo49t3ibj.execute-api.eu-west-3.amazonaws.com/dev/totalStakedBudsAcrossAllChains";
        _staking = IStaking(stakingAddress);
        __Ownable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}


    function requestVolumeData() public onlyStakingContract returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId,address(this),this.fulfill.selector);

        req.add("get",totalStakedEndpoint);
        req.add("path", "totalStakedBudsAcrossAllChains"); 

        int256 timesAmount = 1;
        req.addInt("times", timesAmount);

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    function fulfill(
        bytes32 _requestId,
        uint256 _globalStakedBudsCount
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestVolume(_requestId, _globalStakedBudsCount);
        _staking.fetchData(_globalStakedBudsCount);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
