// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SimpleRandao{

    //STRUCTS
    struct Participant {
        uint256   secret;
        bytes32   commitment;
        bool      rewardable;
    }

    struct Observer {
        bool rewardable;
    }

    struct Round {
        uint32    startTime;
        uint32    commitStartTime;
        uint32    revealStartTime;
        uint256   random;
        uint256   bounty;
        bool      finished;
        bool      generatedValidRNG;
        
        Participant [] participants;
        Observer [] observers;

        mapping (address => uint) addrToParticipantIndex;
        mapping (uint => address) participantIndexToAddress;
        mapping (address => uint) addrToObserverIndex;
        mapping (uint => address) observerIndexToAddress;
    }
    

    //GLOBAL VARIABLES 
    address private owner;
    uint256 private roundCount;
    Round[] private rounds;
    bool private payment;

    uint32 private registerPhaseDuration = 10 seconds;
    uint32 private commitPhaseDuration = 10 seconds;
    uint32 private revealPhaseDuration = 10 seconds;
    uint32 private cooldownTime = 30 seconds;
    uint32 private minimumParticipants = 1;
    uint32 private minimumCommits = 1;
    uint32 private minimumRevealers = 1;
    
    uint256 private observerFee = 0 ether;
    uint256 private participantFee = 0 ether;
    uint256 private newRoundFee = 0 ether; //must be greater or equal than participantFee

    uint16 private currentPhase;


    //CONSTRUCTOR
    constructor() {
        owner = payable(msg.sender);
        }


    //EVENTS
    event phaseChangedTo(string currentPhase);
    event paymentDistributed(address receiver, uint value);
    event newRandomValueGenerated();


    //MODIFIERS
    modifier update(){
        updateRoundStatus();
        require(true);
        _;
    }

    modifier validPhase(uint8 [5] memory _validPhases){
        bool result = false;
        uint8 valid = _validPhases[currentPhase];
        if (valid == 1){result = true;}
        require (result);
        _;
    }

    modifier validUser(uint8 _privilegeLevel){
        uint16 clearance = 0;
        if (owner == msg.sender) {clearance=3;}
        if (roundCount>0 && clearance == 0) {
            Round storage currentRound = rounds[roundCount-1]; 
            uint pIndex = currentRound.addrToParticipantIndex[msg.sender];
            uint oIndex = currentRound.addrToObserverIndex[msg.sender];
            if (currentRound.participants[pIndex-1].rewardable && pIndex>0) {clearance=2;}
            else if (currentRound.observers[oIndex-1].rewardable && oIndex>0) {clearance=1;}
        }
        require (clearance >= _privilegeLevel);
        _;
    }

    modifier notRegistered() {
        require(roundCount>0);
        Round storage currentRound = rounds[roundCount-1];
        require (currentRound.addrToParticipantIndex[msg.sender] == 0 && currentRound.addrToObserverIndex[msg.sender] == 0);
        _;
    }

    modifier privatePaymentOnly(){
        require(payment);
        payment = false;
        _;
    }


     //AUXILIAR METHODS 
    function strCurrentPhase() private view returns (string memory ) {
        if (currentPhase == 0) {return "standby";}
        if (currentPhase == 1) {return "register";}
        if (currentPhase == 2) {return "commit";}
        if (currentPhase == 3) {return "reveal";}
        if (currentPhase == 4) {return "finished";}
        else {return "invalid";}
    }

    function validateSecret(uint256 _secret, bytes32 _commit) private pure returns (bool) {
        return (keccak256(abi.encode(_secret)) == _commit);
    }


    function generateRandom() private {
        Round storage currentRound = rounds[roundCount-1];
        uint256 [] memory secrets = new uint256 [] (currentRound.participants.length) ;
        for (uint i = 0; i < currentRound.participants.length; i++){
            if (currentRound.participants[i].rewardable){
                secrets[i] = (currentRound.participants[i].secret);
                }
        }
        currentRound.random = uint256(keccak256(abi.encodePacked(secrets)));
        currentRound.generatedValidRNG = true;
        emit newRandomValueGenerated();
        distributeBounty();
    }

    function distributeBounty() private{
        Round storage currentRound = rounds[roundCount-1];
        //uint256 balance = currentRound.bounty; //For more complex bounty distributions
        if (currentRound.generatedValidRNG == false && observerFee > 0){
            for (uint i = 0; i < currentRound.observers.length; i++){
                if (currentRound.observers[i].rewardable){
                    address payable dest = payable(currentRound.observerIndexToAddress[i+1]);  
                    payment = true;
                    sendViaCall(dest,observerFee);
                }
            }
        }
        if (participantFee == 0) {return;}
        for (uint i = 0; i < currentRound.participants.length; i++){
                if (currentRound.participants[i].rewardable){
                    address payable dest = payable(currentRound.participantIndexToAddress[i+1]);  
                    payment = true;
                    sendViaCall(dest,participantFee);
                }
            }
    }

    function sendViaCall(address payable _to, uint _value) public payable privatePaymentOnly {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent,) = _to.call{value: _value}("");
        require(sent, "Failed to send Ether");
        emit paymentDistributed(_to, _value);
    }


    //PROTOCOL UPDATE FUNCTIONS
    function updateRoundStatus() public {   
        if (currentPhase == 1) {updateRegisterPhase();}
        if (currentPhase == 2) {updateCommitPhase();}
        if (currentPhase == 3) {updateRevealPhase();}
        if (currentPhase == 4) {updateFinishingPhase();}
    }

    function updateRegisterPhase() private {
        Round storage currentRound = rounds[roundCount-1];
        if (uint32(block.timestamp) - currentRound.startTime >= registerPhaseDuration){
            if (currentRound.participants.length < minimumParticipants){
                currentPhase = 0;
                currentRound.finished = true;
                distributeBounty();
                //NOT ENOUGH PARTICIPANTS
            }
            else {
                currentPhase++;
                emit phaseChangedTo(strCurrentPhase());
            }
            
        } 
    }

    function updateCommitPhase() private {
        Round storage currentRound = rounds[roundCount-1];
        if (uint32(block.timestamp) - currentRound.commitStartTime >= commitPhaseDuration){
            uint commiters = 0;
            for (uint i = 0; i < currentRound.participants.length; i++){
                if (currentRound.participants[i].commitment != 0){commiters++;}
                else {currentRound.participants[i].rewardable = false;}
            }
            if (commiters < minimumCommits){
                currentPhase = 0;
                currentRound.finished = true;
                distributeBounty();
                //NOT ENOUGH COMMITS
            }
            else {
                currentPhase++;
                emit phaseChangedTo(strCurrentPhase());
            }
            
        } 
    }

    function updateRevealPhase() private {
        Round storage currentRound = rounds[roundCount-1];
        if (uint32(block.timestamp) - currentRound.revealStartTime >= revealPhaseDuration){
            uint revealers = 0;
            for (uint i = 0; i < currentRound.participants.length; i++){
                if (currentRound.participants[i].secret != 0){revealers++;}
                else {currentRound.participants[i].rewardable = false;}
            }
            if (revealers < minimumRevealers){
                currentPhase = 0;
                currentRound.finished = true;
                distributeBounty();
                //NOT ENOUGH REVEALERS
            }
            else {
                generateRandom();
                currentPhase++;
                emit phaseChangedTo(strCurrentPhase());
                
            }
            
        } 
    }

    function updateFinishingPhase() private {
        Round storage currentRound = rounds[roundCount-1];
        if (uint32(block.timestamp) - currentRound.revealStartTime >= revealPhaseDuration + cooldownTime){
            currentPhase=0;
            currentRound.finished = true;
            emit phaseChangedTo(strCurrentPhase());
            }
    }


    //MAIN METHODS 
    function startRound() update() validPhase([1,0,0,0,0]) public payable {
        require(msg.value == newRoundFee);
        Round storage newRound = rounds.push();
        roundCount++;
        newRound.startTime = uint32(block.timestamp);
        newRound.commitStartTime = newRound.startTime + registerPhaseDuration; 
        newRound.revealStartTime = newRound.commitStartTime + commitPhaseDuration;
        newRound.bounty = newRoundFee;
        newRound.participants.push(Participant(0,0,true));
        newRound.addrToParticipantIndex[msg.sender] = 1;
        newRound.participantIndexToAddress[1] = msg.sender;
        currentPhase = 1;
        emit phaseChangedTo(strCurrentPhase());
    }

    function registerObserver() update() validPhase([0,1,1,1,0]) notRegistered public payable {
        require(msg.value == observerFee);
        Round storage currentRound = rounds[roundCount-1];
        currentRound.observers.push(Observer(true));
        currentRound.addrToObserverIndex[msg.sender] = currentRound.observers.length;
        currentRound.observerIndexToAddress[currentRound.observers.length] = msg.sender;
        currentRound.bounty = currentRound.bounty + observerFee;
    }

    function registerParticipant() update() validPhase([0,1,0,0,0]) notRegistered public payable {
        require(msg.value == participantFee);
        Round storage currentRound = rounds[roundCount-1];
        currentRound.participants.push(Participant(0,0,true));
        currentRound.addrToParticipantIndex[msg.sender] = currentRound.participants.length;
        currentRound.participantIndexToAddress[currentRound.participants.length] = msg.sender;
        currentRound.bounty = currentRound.bounty + participantFee;
    }

    function commit(bytes32 _commit) update() validPhase([0,0,1,0,0]) validUser(2) public {
        Round storage currentRound = rounds[roundCount-1];
        uint senderIndex = currentRound.addrToParticipantIndex[msg.sender] - 1;
        currentRound.participants[senderIndex].commitment = _commit;
    }

    function reveal(uint256 _secret) update() validPhase([0,0,0,1,0]) public validUser(2) {
        Round storage currentRound = rounds[roundCount-1];
        uint senderIndex = currentRound.addrToParticipantIndex[msg.sender] - 1;
        Participant storage part = currentRound.participants[senderIndex];
        part.secret = _secret;
        if (part.rewardable==false){return;}
        if (validateSecret(part.secret,part.commitment) == false){
            part.rewardable = false;
        }
    }


    //EXTERNAL VIEWS
    function get_observerFee() external view returns (uint256) {return observerFee;}

    function get_participantFee() external view returns (uint256) {return participantFee;}

    function get_newRoundFee() external view returns (uint256) {return newRoundFee;}

    function get_currentPhase() external view returns (uint16) {return currentPhase;}

    function get_registerPhaseDuration() external view returns (uint32) {return registerPhaseDuration;}

    function get_commitPhaseDuration() external view returns (uint32) {return commitPhaseDuration;}

    function get_revealPhaseDuration() external view returns (uint32) {return revealPhaseDuration;}

    function get_cooldownTime() external view returns (uint32) {return cooldownTime;}

    function getRandom() validPhase([0,0,0,0,1]) validUser(1) external view returns (uint) {
        if (roundCount > 0) {
            Round storage currentRound = rounds[roundCount-1];
            if (currentRound.generatedValidRNG) {return currentRound.random;}
        }
        return 0;
    }

    function getLastValidRandom() validPhase([1,1,1,1,0]) validUser(0) external view returns (uint) {
        for (uint i = roundCount-1; i >= 0; i--){
            if (rounds[i].generatedValidRNG) {return rounds[i].random;}
        }
        return 0;
    }


    //OWNER ONLY, SET PROTOCOL PARAMETERS
    function set_registerPhaseDuration(uint32 _registerPhaseDuration) public validPhase([1,0,0,0,1]) validUser(3) {registerPhaseDuration = _registerPhaseDuration;}

    function set_commitPhaseDuration(uint32 _commitPhaseDuration) public validPhase([1,0,0,0,1]) validUser(3) {commitPhaseDuration = _commitPhaseDuration;}

    function set_revealPhaseDuration(uint32 _revealPhaseDuration) public validPhase([1,0,0,0,1]) validUser(3) {revealPhaseDuration = _revealPhaseDuration;}

    function set_cooldownTime(uint32 _cooldownTime) public validPhase([1,0,0,0,1]) validUser(3) {cooldownTime = _cooldownTime;}

    function set_minimumParticipants(uint32 _minimumParticipants) public validPhase([1,0,0,0,1]) validUser(3) {minimumParticipants = _minimumParticipants;}

    function set_minimumCommits(uint32 _minimumCommits) public validPhase([1,0,0,0,1]) validUser(3) {minimumCommits = _minimumCommits;}

    function set_minimumRevealers(uint32 _minimumRevealers) public validPhase([1,0,0,0,1]) validUser(3) {minimumRevealers = _minimumRevealers;}

    function set_observerFee(uint32 _observerFee) public validPhase([1,0,0,0,1]) validUser(3) {observerFee = _observerFee;}

    function set_participantFee(uint32 _participantFee) public validPhase([1,0,0,0,1]) validUser(3) {participantFee = _participantFee;}

    function set_newRoundFee(uint32 _newRoundFee) public validPhase([1,0,0,0,1]) validUser(3) { newRoundFee = _newRoundFee;}

}