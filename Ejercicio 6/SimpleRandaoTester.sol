// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract SimpleRandaoInterface {

    function get_observerFee() virtual external view returns (uint256);

    function get_participantFee() virtual external view returns (uint256); 

    function get_newRoundFee() virtual external view returns (uint256);

    function get_currentPhase() virtual external view returns (uint16);

    function get_registerPhaseDuration() virtual external view returns (uint32); 

    function get_commitPhaseDuration() virtual external view returns (uint32);

    function get_revealPhaseDuration() virtual external view returns (uint32);

    function get_cooldownTime() virtual external view returns (uint32);

    function getRandom() virtual external view returns (uint);

    function getLastValidRandom() virtual external view returns (uint);

    function startRound() virtual public payable;

    function registerObserver() virtual public payable;

    function registerParticipant() virtual public payable;

    function commit(bytes32 _commit) virtual public;

    function reveal(uint256 _secret) virtual public;

    function updateRoundStatus() virtual public; 
}


contract SimpleRandaoTester{

    //Global Variables
    SimpleRandaoInterface simpleRandaoContract;
    address owner;
    uint32 private registerPhaseDuration = 10 seconds;
    uint32 private commitPhaseDuration = 10 seconds;
    uint32 private revealPhaseDuration = 10 seconds;
    uint32 private cooldownTime = 5 seconds;
    uint32 private minimumParticipants = 2;
    uint32 private minimumCommits = 2;
    uint32 private minimumRevealers = 2;
    uint256 private observerFee = 0.01 ether;
    uint256 private participantFee = 1 ether;
    uint256 private newRoundFee = 2 ether;
    uint16 private currentPhase;
    address private default_address = 0x20d7F8779F9f151E0DdA34C497782aF44dE2Fd2B; //ALWAYS UPDATE THIS

    uint256 private _secret_;
    bytes32 private _commit_;

    //MODIFIERS
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }


    //SINCRONIZE VALUES WITH THE REAL CONTRACT
    function update_globals() private {
        registerPhaseDuration = simpleRandaoContract.get_registerPhaseDuration();
        commitPhaseDuration = simpleRandaoContract.get_commitPhaseDuration();
        revealPhaseDuration = simpleRandaoContract.get_revealPhaseDuration();
        cooldownTime = simpleRandaoContract.get_cooldownTime();
        observerFee = simpleRandaoContract.get_observerFee();
        participantFee = simpleRandaoContract.get_participantFee();
        newRoundFee = simpleRandaoContract.get_newRoundFee();
    }

    function update_phase() private {
        currentPhase = simpleRandaoContract.get_currentPhase();
    }


    //LOCAL VERSIONS OF SIMPLE RANDAO METHODS
    function updateRoundStatus() public {simpleRandaoContract.updateRoundStatus();}
    
    function get_currentPhase() public view returns (uint16) {return simpleRandaoContract.get_currentPhase();}

    function getRandom() public view returns (uint256){return simpleRandaoContract.getRandom();}

    function getLastRandom() public view returns (uint256){return simpleRandaoContract.getLastValidRandom();}

    function startRound() public payable {simpleRandaoContract.startRound();}

    function registerObserver() public payable {simpleRandaoContract.registerObserver();}

    function registerParticipant() public payable {simpleRandaoContract.registerParticipant();}

    function commit(bytes32 _commit) public {simpleRandaoContract.commit(_commit);}

    function reveal(uint256 _secret) public {simpleRandaoContract.reveal(_secret);}


    //UPDATING THE ADDRESS OF THE CONTRACT
    function setSimpleRandaoContractAddress(address _address) private onlyOwner {
        simpleRandaoContract = SimpleRandaoInterface(_address);
    }


    //CONSTRUCTOR
    constructor ()
    {
        owner = msg.sender;
        simpleRandaoContract = SimpleRandaoInterface(default_address);
        update_globals();
        _secret_ = getRandomSecret();
        _commit_ = getValidCommit(_secret_);
    }

 
    //AUXILIAR METHODS
    function getRandomSecret() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp,msg.sender)));
    }

    function getValidCommit(uint _secret) private pure returns (bytes32) {
        return keccak256(abi.encode(_secret));
    }


    //TESTER METHODS
    function honestCommit() public  {
        simpleRandaoContract.commit(_commit_);
    }

    function honestReveal() public  {
        simpleRandaoContract.reveal(_secret_);
    }

    function dishonestReveal() public  {
        simpleRandaoContract.reveal(_secret_ + 1);
    }
}