// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

interface IStaking {
    function getNumberOfStakers() external view returns (uint256);
    function getNoOfChains() external view returns(uint256);
    function getGlobalStakedBuds() external view returns(uint256);
    function getlocalStakedBuds() external view returns(uint256);
    function getCurrentApr(uint256 localStakedBuds, uint256 globalStakedBuds) external view returns(uint256);
    function getBaseAPR() external view returns(uint256);
    function getCurrentRewardForAddress(address _address) external view returns(uint256);
    function getNextRewardTime() external view returns(uint256);
    function getChainLinkOracle() external view returns(address);
    function getChainLinkToken() external view returns(address);
    function getNewJobIdForOracle() external view returns(bytes32);
    function getZetaTokenAddress() external view returns(address);
    function getZetaConsunerAddress() external view returns(address);
    function getCurrentStakeForAddress(address _address) external view returns(uint256[2] memory stake);
    function finalizeRaid(address raider, bool isSuccess, bool isboosted, uint256 boosts) external;
} 

contract RaidHandler is VRFConsumerBaseV2, ConfirmedOwner{
    
    struct RequestStatus {
        bool fulfilled; 
        bool exists; 
        uint256[] randomWords;
    }

    struct Raid{
        address raider;
        bool isBoosted;
        uint256 stakers;
        uint256 local;
        uint256 global;
    }

    VRFCoordinatorV2Interface COORDINATOR;
    IStaking public _stakingContract;

    uint256[] public requestIds;
    Raid[] internal raiderQueue;
    bytes32 keyHash;

    uint32 callbackGasLimit = 2500000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint64 s_subscriptionId;
    uint256 public lastRequestId;

    mapping(uint256 => RequestStatus) public s_requests;
    mapping(address => uint256[]) public lastRaidBoost; 

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);


    constructor(
        address _vrfCons,
        uint64 subscriptionId,
        bytes32 _vrfKeyHash,
        address __stakingAddress
    )VRFConsumerBaseV2(_vrfCons) ConfirmedOwner(__stakingAddress){
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCons);
        s_subscriptionId = subscriptionId;
        keyHash = _vrfKeyHash;
        _stakingContract = IStaking(__stakingAddress);
    }

    function raidPool(uint256 tokenId, address _raider, uint256 noOfStakers, uint256 localBuds, uint256 globalBuds) external onlyOwner{
        if (tokenId != 0) {
            for (uint256 i = 0; i < lastRaidBoost[_raider].length; i++) {
                if (block.timestamp - lastRaidBoost[_raider][i] > 7 days) {
                    lastRaidBoost[_raider][i] = lastRaidBoost[_raider][lastRaidBoost[_raider].length-1];
                    lastRaidBoost[_raider].pop();
                }
            }
            if(lastRaidBoost[_raider].length >= 4) revert("Only 4 boost/week");
            lastRaidBoost[_raider].push(block.timestamp);
        }
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        raiderQueue.push(Raid({raider : _raider, isBoosted:tokenId != 0, stakers:noOfStakers, local:localBuds, global:globalBuds}));
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);

    }

    function fulfillRandomWords(uint256 _requestId,uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);

        Raid memory latestRaid = Raid({
            raider:raiderQueue[0].raider,
            isBoosted:raiderQueue[0].isBoosted,
            stakers:raiderQueue[0].stakers,
            local:raiderQueue[0].local,
            global:raiderQueue[0].global
        });

        for(uint256 i = 0; i < raiderQueue.length-1; i++){
            raiderQueue[i] = raiderQueue[i+1];
        }
        raiderQueue.pop();


        if(latestRaid.stakers == 0){
            _stakingContract.finalizeRaid(latestRaid.raider, false, latestRaid.isBoosted, lastRaidBoost[latestRaid.raider].length);
        }

        uint256 randomPercent = (_randomWords[0] % 100) + 1;

        uint256 globalGSPC = (latestRaid.global / 4) / latestRaid.stakers;
        uint256 localGSPC = latestRaid.local / latestRaid.stakers;

        if (localGSPC < globalGSPC) {
            if(calculateRaidSuccess(randomPercent, 20, latestRaid.raider, latestRaid.isBoosted)){
                _stakingContract.finalizeRaid(latestRaid.raider, true, latestRaid.isBoosted, lastRaidBoost[latestRaid.raider].length);
                return;
            }
            _stakingContract.finalizeRaid(latestRaid.raider, false, latestRaid.isBoosted, lastRaidBoost[latestRaid.raider].length);
            return;
        }

        if(calculateRaidSuccess(randomPercent, 15, latestRaid.raider, latestRaid.isBoosted)){
            _stakingContract.finalizeRaid(latestRaid.raider, true, latestRaid.isBoosted, lastRaidBoost[latestRaid.raider].length);
            return;
        }

        _stakingContract.finalizeRaid(latestRaid.raider, false,latestRaid.isBoosted, lastRaidBoost[latestRaid.raider].length);
        return;
    }

    function calculateRaidSuccess(uint256 randomPercent, uint256 factor, address raider, bool isBoosted) internal view returns(bool){
        if (randomPercent % factor == 0) {
            return true;
        }
        if (isBoosted) {
            if (lastRaidBoost[raider].length == 4) {
                factor = 12;
            } else if (lastRaidBoost[raider].length == 3) {
                factor = 10;
            } else if (lastRaidBoost[raider].length == 2) {
                factor = 8;
            } else {
                factor = 6;
            }
            if(randomPercent % factor == 0){
                return true;
            } 
        }
        return false;
    }

    function getRequestStatus(uint256 _requestId) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}
