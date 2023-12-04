// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import '@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol';
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiverUpgradable} from "../Support/CCIPReceiverUpgradable.sol";
import '../Interfaces/IFarmer.sol';
import '../Interfaces/IBudsToken.sol';
import '../Interfaces/IBoosters.sol';
import '../Support/ChainlinkClientUp.sol';


interface IRaidHandler {
    function raidPool(uint256 tokenId, address raider, uint256 numOfStakers, uint256 localBuds, uint256 globalBuds) external;
}

interface IDataFeed {
    function requestVolumeData() external returns (bytes32 requestId);
}

contract Staking is  UUPSUpgradeable, AutomationCompatible, IERC721Receiver, CCIPReceiverUpgradable, OwnableUpgradeable{

    using Chainlink for Chainlink.Request;

    struct Stake {
        address owner;
        uint256 timeStamp;
        uint256 budsAmount;
        uint256 farmerTokenId;
    }
    
    IBudsToken public _budsToken;
    IFarmer public _farmerToken;
    IFarmer public _narcToken;
    IBoosters public _stonerToken;
    IBoosters public _informantToken;
    IDataFeed public _dataFeed;
    IRouterClient public router;

    uint256 public baseAPR;//
    uint256 public globalStakedBudsCount;
    uint256 public localStakedBudsCount;
    uint256 public noOfChains;//
    uint256 private previousRewardCalculated;
    uint256 private previousFundedTimestamp;
    uint256 public totalStakedFarmers;
    uint256 private fee;
    
    address[] public stakerAddresses;

    bytes32 private CROSS_CHAIN_RAID_MESSAGE;
    bytes32 private CROSS_CHAIN_STAKE_MESSAGE;

    address public raidHandler;
    

    mapping(address => Stake) public stakeRecord;
    mapping(address => uint256[]) public boosts;
    mapping(address => uint256) public rewards;
    mapping(uint64 => bool) public allowlistedDestinationChains;
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(address => bool) public allowlistedSenders;

    uint256 public raidFees;
    address payable public treasuryWallet;

    event Staked(address indexed owner, uint256 tokenId, uint256 budsAmount, uint256 timeStamp, uint256 localStakedBudsCount, uint256 latestAPR);
    event UnStaked(address owner, uint256 tokenId, uint256 budsAmount, uint256 timeStamp, uint256 localStakedBudsCount, uint256 latestAPR);
    event RewardsCalculated(uint256 timeStamp, uint256 rewardsDisbursed);
    event RequestVolume(bytes32 indexed requestId, uint256 globalStakedBudsCount);
    event Raided(address indexed raider, bool isSuccess, bool isBoosted, uint256 boostsUsedInLastSevenDays);


    function initialize() public initializer{
        noOfChains=5;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector])
            revert("Invalid destination");
        _;
    }

    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert("Invalid source");
        if (!allowlistedSenders[_sender]) revert("Sender not allowed");
        _;
    }

    function allowlistDestinationChain(
        uint64 _destinationChainSelector,
        bool allowed
    ) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    function allowlistSourceChain(
        uint64 _sourceChainSelector,
        bool allowed
    ) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    function allowlistSender(address _sender, bool allowed) external onlyOwner {
        allowlistedSenders[_sender] = allowed;
    }


    function setRaidFees(uint256 _raidFees) external onlyOwner{
        raidFees = _raidFees;
    }

//----------------------------------------------GETTER - SETTERS--------------------------------------------------//
    function getCurrentApr(uint256 localStakedBuds, uint256 globalStakedBuds) public view returns(uint256){
        if(localStakedBuds == 0) return baseAPR;

        localStakedBuds = localStakedBuds*1 ether;
        globalStakedBuds = globalStakedBuds*1 ether;

        uint256 globalStakedAVG = globalStakedBuds/noOfChains;
        uint256 adjustmentFactor;
        uint256 calculatedAPR;

        localStakedBuds = localStakedBuds/100; 
        adjustmentFactor = uint256(globalStakedAVG/localStakedBuds);
        calculatedAPR = (baseAPR*adjustmentFactor)/100;
    
        if (calculatedAPR < 10) return 10 * 100; 
        if(calculatedAPR > 200) return 200*100;

        return uint256(calculatedAPR) * 100; 
    }

    function getGlobalStakedBuds() public view returns(uint256){
        return globalStakedBudsCount;
    }

    function getNoOfChains() public view returns(uint256){
        return noOfChains;
    }

    function getlocalStakedBuds() public view returns(uint256){
        return localStakedBudsCount;
    }

    function getNumberOfStakers() public view returns(uint256){
        return stakerAddresses.length;
    }

    function getNextRewardTime() public view returns(uint256){
        return (previousRewardCalculated + 1 days) - block.timestamp/ 1 hours;
    }

    function getCurrentStakeForAddress(address _address) public view returns(uint256[2] memory stake){
        return [stakeRecord[_address].budsAmount, stakeRecord[_address].farmerTokenId];
    }

    function setNoOfChains(uint256 chains) external onlyOwner {
        noOfChains = chains;
    }

    function setRaidHandler(address _address) external onlyOwner{
        raidHandler = _address;
    }

    function setDataFeed(address __dataFeed) external onlyOwner{
        _dataFeed = IDataFeed(__dataFeed);
    }

    function setTreasury(address payable newAddress) external onlyOwner{
        treasuryWallet = newAddress;
    }

//--------------------------------------------------STAKING FUNCTION-----------------------------------------------//

    function addStake(uint256 _budsAmount, uint256 _farmerTokenId) public {
        if(_budsAmount == 0 && _farmerTokenId == 0) revert();
        if (_farmerTokenId != 0 && _farmerToken.ownerOf(_farmerTokenId) != msg.sender) revert("NYN");

        Stake memory stk;

        if(stakeRecord[msg.sender].owner != address(0)){
            stk = stakeRecord[msg.sender];
            if(stk.farmerTokenId != 0 && _farmerTokenId != 0){
                revert("ASN");
            }
            delete stakeRecord[msg.sender];
        }else{
            stk = Stake({
                owner: msg.sender,
                timeStamp: block.timestamp,
                budsAmount: 0,
                farmerTokenId: 0
            });
            stakerAddresses.push(msg.sender);
        }

        stk.budsAmount += _budsAmount;
        localStakedBudsCount += (_budsAmount/1 ether);
        globalStakedBudsCount += (_budsAmount/1 ether);
        stk.farmerTokenId = _farmerTokenId;
        stakeRecord[msg.sender] = stk;

        if(_farmerTokenId != 0){
            totalStakedFarmers+=1;
            _farmerToken.safeTransferFrom(msg.sender,address(this),_farmerTokenId);  
        }

        if(_budsAmount != 0){
            _budsToken.transferFrom(msg.sender, address(this), _budsAmount);
        } 
        emit Staked(msg.sender, _farmerTokenId, stk.budsAmount, block.timestamp, localStakedBudsCount, getCurrentApr(localStakedBudsCount, globalStakedBudsCount)); 
    }

    function unStakeBuds(uint256 _budsAmount) public {
        if(stakeRecord[msg.sender].budsAmount < _budsAmount) revert("nes");
        Stake storage stk = stakeRecord[msg.sender];
        stk.budsAmount -= _budsAmount;

        if (stk.budsAmount == 0 && stk.farmerTokenId == 0){
            for (uint256 i = 0; i < stakerAddresses.length; i++) {
                if (msg.sender == stakerAddresses[i]) {
                    stakerAddresses[i] = stakerAddresses[stakerAddresses.length - 1];
                    stakerAddresses.pop();
                    break;
                }
            }
            delete stakeRecord[msg.sender];
        }

        localStakedBudsCount -= (_budsAmount/1 ether);
        globalStakedBudsCount -= (_budsAmount/1 ether);
        uint256 payOut = _budsAmount+rewards[msg.sender];
        rewards[msg.sender] = 0;
        _budsToken.transfer(msg.sender, payOut);

        emit UnStaked(msg.sender, 0, _budsAmount, block.timestamp, localStakedBudsCount, getCurrentApr(localStakedBudsCount, globalStakedBudsCount));
    }

    function unStakeFarmer() public {
        if(stakeRecord[msg.sender].farmerTokenId == 0) revert();
        Stake storage stk = stakeRecord[msg.sender];
        uint256 tokenIdToSend = stk.farmerTokenId;
        stk.farmerTokenId = 0;

        totalStakedFarmers-=1;

        if (stk.farmerTokenId == 0 && stk.budsAmount == 0){
            for(uint256 i = 0; i < stakerAddresses.length; i++){
                if(stakerAddresses[i] == msg.sender){
                    stakerAddresses[i] = stakerAddresses[stakerAddresses.length - 1];
                    stakerAddresses.pop();
                    break;
                }
            }
            delete stakeRecord[msg.sender];
        }

        _farmerToken.safeTransferFrom(address(this), msg.sender, tokenIdToSend);

        emit UnStaked(msg.sender, tokenIdToSend, 0, block.timestamp, localStakedBudsCount, getCurrentApr(localStakedBudsCount, globalStakedBudsCount));
    }

    function distributeRaidingRewards(address to, uint256 rewardAmount) internal{
        globalStakedBudsCount -= (rewardAmount/1 ether);
        localStakedBudsCount -= (rewardAmount/1 ether);
        _budsToken.burn((rewardAmount / 100));
        _budsToken.transfer(to, rewardAmount - ((rewardAmount / 100)));
    }

    function raid(uint256 tokenId) public payable{
        require(_narcToken.balanceOf(msg.sender) != 0, "For narcs");
        require(msg.value >= raidFees,"NEF");
        treasuryWallet.transfer(msg.value);
        IRaidHandler(raidHandler).raidPool(tokenId, msg.sender, stakerAddresses.length, localStakedBudsCount, globalStakedBudsCount);
        if(tokenId != 0){
            require(_informantToken.ownerOf(tokenId) == msg.sender);
            _informantToken.burn(tokenId);
        }
    }

    function finalizeRaid(address raider, bool isSuccess, bool isboosted, uint256 _boosts) external{
        require(msg.sender == raidHandler, "CSF");
        if(isSuccess){
            distributeRaidingRewards(raider,_budsToken.balanceOf(address(this))/1000);
            emit Raided(raider,true,isboosted, _boosts);
            return;
        }
        emit Raided(raider,false,isboosted, _boosts);
    }

    //-----------------------------------------------CROSS CHAIN MESSAGE---------------------------------------//

    function crossChainRaid(uint64 chainSelector, uint256 tokenId) external payable onlyAllowlistedDestinationChain(chainSelector) {
        require(_narcToken.balanceOf(msg.sender) != 0, "For narcs");
        if(tokenId != 0){
            require(_informantToken.ownerOf(tokenId) == msg.sender, "Iti");
            _informantToken.burn(tokenId);
        }

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            address(this),
            abi.encode(CROSS_CHAIN_RAID_MESSAGE, 0, tokenId, msg.sender),
            address(0)
        );   

        IRouterClient ccipRouter = IRouterClient(this.getRouter());

        uint256 fees = ccipRouter.getFee(chainSelector, evm2AnyMessage);

        if (msg.value - raidFees < fees)
            revert("not enough fees");

        treasuryWallet.transfer(msg.value-fees);
        
        bytes32 messageId = router.ccipSend{value: fees}(
            chainSelector,
            evm2AnyMessage
        );
    }

    function crossChainStake(uint256 _budsAmount, uint256 _farmerTokenId, uint64 chainSelector) external payable onlyAllowlistedDestinationChain(chainSelector){
        if(_budsAmount == 0 && _farmerTokenId == 0) revert("NDP");
        if (_farmerTokenId != 0 && _farmerToken.ownerOf(_farmerTokenId) != msg.sender) revert("Not your NFT");

        if(_budsAmount != 0){
            _budsToken.burnFrom(msg.sender, _budsAmount);
            globalStakedBudsCount += (_budsAmount/1 ether);
        } 
        if(_farmerTokenId != 0){
            require(_farmerToken.ownerOf(_farmerTokenId) == msg.sender, "Iti");
            _farmerToken.burn(_farmerTokenId);
        }

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            address(this),
            abi.encode(CROSS_CHAIN_STAKE_MESSAGE, _budsAmount, _farmerTokenId, msg.sender),
            address(0)
        );  

        IRouterClient ccipRouter = IRouterClient(this.getRouter());

        uint256 fees = ccipRouter.getFee(chainSelector, evm2AnyMessage);

        if (fees > msg.value)
            revert("not enough fees");
        
        bytes32 messageId = router.ccipSend{value: msg.value}(
            chainSelector,
            evm2AnyMessage
        );

    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        (bytes32 messageType, uint256 budsAmount, uint256 tokenId, address sender) = abi.decode(any2EvmMessage.data, (bytes32, uint256, uint256, address));

        if(messageType == CROSS_CHAIN_STAKE_MESSAGE){
            _onCrossChainStake(tokenId, sender, budsAmount);
        }else if(messageType == CROSS_CHAIN_RAID_MESSAGE){
            IRaidHandler(raidHandler).raidPool(tokenId, sender, stakerAddresses.length, localStakedBudsCount,globalStakedBudsCount);
        }else{
            revert("Invalid msg");
        }
    }


    function _onCrossChainStake(uint256 tokenId, address sender, uint256 _budsAmount) internal{
        if(_budsAmount == 0 && tokenId == 0) revert();
        Stake memory stk;
        if(stakeRecord[sender].owner != address(0)){
            stk = stakeRecord[sender];
            if(stk.farmerTokenId != 0 && tokenId != 0){
                revert("ASN");
            }
            delete stakeRecord[sender];
        }else{
            stk = Stake({
                owner: sender,
                timeStamp: block.timestamp,
                budsAmount: 0,
                farmerTokenId: 0
            });
            stakerAddresses.push(sender);
        }
        stk.budsAmount += _budsAmount;
        localStakedBudsCount += (_budsAmount/1 ether);
        globalStakedBudsCount += (_budsAmount/1 ether);
        stk.farmerTokenId = tokenId;
        stakeRecord[sender] = stk;

        if (tokenId != 0){
            totalStakedFarmers+=1;
            _farmerToken.mintTokenId(address(this),tokenId);
        }

        if(_budsAmount != 0){
            _budsToken.mint(address(this), _budsAmount);
        }
        emit Staked(sender, tokenId, stk.budsAmount, block.timestamp, localStakedBudsCount, getCurrentApr(localStakedBudsCount, globalStakedBudsCount)); 
    }

    function _buildCCIPMessage(
        address _receiver,
        bytes memory _dataToSend,
        address _feeTokenAddress
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver),
                data: _dataToSend, 
                tokenAmounts: new Client.EVMTokenAmount[](0), 
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: 2500_000, strict: false})
                ),
                feeToken: _feeTokenAddress
            });
    }

    function getFeesForCCTX(uint256 _budsAmount, uint256 _farmerTokenId, uint64 _destinationChainSelector) external view returns(uint256){
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            address(this),
            abi.encode(CROSS_CHAIN_STAKE_MESSAGE, _budsAmount, _farmerTokenId, msg.sender),
            address(0)
        );  
        IRouterClient ccipRouter = IRouterClient(this.getRouter());
        uint256 fees = ccipRouter.getFee(_destinationChainSelector, evm2AnyMessage);
        return fees;
    }

    //----------------------------------------------FETCHING OFFCHAIN DATA------------------------------------------// 

    function reqData() internal {
        bytes32 ret = _dataFeed.requestVolumeData();
    }

    function fetchData( uint256 _globalStakedBudsCount) external {
        require(msg.sender == address(_dataFeed));
        globalStakedBudsCount = _globalStakedBudsCount;
    }

    //----------------------------------------------CHAINLINK-UPKEEP------------------------------------------------//

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = false;
        if(block.timestamp - previousRewardCalculated >= 24 hours || block.timestamp - previousFundedTimestamp >= 2 weeks){
            upkeepNeeded = true;
        }
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if(block.timestamp - previousRewardCalculated < 24 hours) revert();
        if(block.timestamp - previousRewardCalculated >= 1 days){
            uint256 rewardsDisbursed = 0;
            previousRewardCalculated = block.timestamp;
            for(uint256 i = 0; i < stakerAddresses.length; i++){
                if(stakeRecord[stakerAddresses[i]].budsAmount > 0){
                    uint256 budsBalance = stakeRecord[stakerAddresses[i]].budsAmount;
                    uint256 reward = (budsBalance/100)*(getCurrentApr(localStakedBudsCount, globalStakedBudsCount)/100);
                    reward = reward/365;
                    rewards[stakerAddresses[i]] += reward;
                    rewardsDisbursed += reward;
                }
            }
            emit RewardsCalculated(block.timestamp, rewardsDisbursed);
            reqData();
        }
        if(block.timestamp - previousFundedTimestamp >= 1 weeks){
            previousFundedTimestamp = block.timestamp;
            _budsToken.mint(address(this),_budsToken.totalSupply()/100);
        }
    }

    //----------------------------------------------ERC721-RECEIVER----------------------------------------------------//

    function onERC721Received(address operator,address from,uint256 tokenId,bytes calldata data) public override returns (bytes4) {
        return this.onERC721Received.selector;
    }

}