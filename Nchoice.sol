pragma solidity ^0.8.12;
contract choices {
    address payable public owner;
    uint Onewei = 1 wei;
    uint deposit;
    uint partReward;
    uint pointReward;
    uint compensation;
    uint256 random_number = 0;
    uint rn_bits = 0;
    uint M; 
    uint N; 
    uint log2N;
    bool lastIsCreate = false;
    

    
    constructor() {
        owner = payable(msg.sender);
    }
    


    mapping (address => bool) participants; 
    address payable[] participants_vector = new address payable[](16) ; 
    uint participant_number = 0; 
    mapping (address => uint256) choice_value; 
    mapping (address => uint256) hash_value;
    mapping (address => bool) isPaidDeposit;
    uint startTime = 0; 
    uint votingTime; 
    bool isStartGame = false;

    function min(uint a, uint b) public pure returns (uint){
        if(a < b) return a;
        return b;
    }

    function max(uint a, uint b) public pure returns (uint){
        if(a < b) return b;
        return a;
    }
    
    
    function preparationOwner(uint n, uint m, uint log, uint dep, uint part, uint comp, uint point, uint vot) payable public{
        require(msg.sender == owner, "You are not owner");
        require(log & (log-1) == 0, "Invalid log");
        require(n >= 2 && m >= 2,"Small n or m");
        require(m & (m-1) == 0,"Invalid m");
        require(2**log == n,"invalid log or n");
        require(!isStartGame,"isStartGame is true");
        require(msg.value >= part*m,"msg.value is short");
        require(dep >= part*(m-1)+point*max(m-1,n-1)+comp,"dep is not enough value");
        require(part <= point*min(m-1,n-1),"part is too big");
        require(point*max(m-1,n-1) <= part+dep,"part and dep is not enough");
        N = n;
        M = m;
        log2N = log;
        deposit = dep*Onewei;
        partReward = part*Onewei;
        pointReward = point*Onewei;
        compensation = comp*Onewei;
        votingTime = vot;

        isStartGame = true;
    }


    function returnState() public view returns(bytes32) {
        if(isStartGame) {
            if(participant_number < M) return "Recruiting participants";
            else {
                if(startTime == 0) return "Before startGame";
                else if(startTime <= block.timestamp && block.timestamp < startTime+votingTime) return "inputHashValue";
                else if(startTime+votingTime <= block.timestamp && block.timestamp <= startTime+votingTime*2) return "inputValue";
                else if(startTime+votingTime*2 <= block.timestamp) return "Reward and Create number";
                else return "error";
            }
        } else {
            return "Not start game.";
        }
    }

    
    function participantReception() payable public {
        require(isStartGame,"isStartGame is false");
        require(msg.sender != owner,"You are not owner");
        require(participant_number < M,"participant_number is more than M");
        require(!participants[msg.sender],"You are participants");

        require(msg.value >= deposit,"You did not pay deposit enough value"); //デポジット支払
        
        address payable participant = payable(msg.sender);
        participants[participant] = true;
        participants_vector[participant_number] = participant;
        participant_number++;
    }


    function startGame() public {
        require(startTime == 0,"startTime is not 0");
        require(msg.sender == owner || participants[msg.sender],"You are not participants and owner");
        require(participant_number == M,"participants_number is not M");
        for(uint i=0;i<M;i++){
            choice_value[participants_vector[i]] = N;
        }
        startTime = block.timestamp;
    }

    function inputHashValue(uint256 hashValue) public {
        require(participants[msg.sender],"You are not participants");
        require(startTime <= block.timestamp && block.timestamp < startTime+votingTime,"Now is not inputHashValue time");
        hash_value[msg.sender] = hashValue;
    }

    function inputValue(uint256 value) public {
        require(participants[msg.sender],"You are not participants");
        require(startTime+votingTime <= block.timestamp && block.timestamp <= startTime+votingTime*2,"Now is not inputValue time");
        uint256 hashValue = hash(value);
        require(hashValue == hash_value[msg.sender],"The hash value of your input does not match one in advance");
        choice_value[msg.sender] = value%N;
    }

    
    function finishGame() public {
        require(participants[msg.sender] || msg.sender == owner,"You are not participants and owner");
        require(startTime != 0,"startTime is 0");
        require(startTime+votingTime*2 <= block.timestamp,"You can not finish Game now");
        uint cv = choice_value[participants_vector[0]];
        bool isCreateRandomNumber = true;
        if(cv == N) {
            isCreateRandomNumber = false;
            for(uint i=1;i<M;i++){
                if(choice_value[participants_vector[i]] < N){
                    participants_vector[i].transfer(deposit+partReward+pointReward);
                }
            }
        } else {
            int point = 0;
            for(uint i=1;i<M;i++){
                if(choice_value[participants_vector[i]] == N){
                    isCreateRandomNumber = false;
                    point += int(N-1);
                } else if(cv == choice_value[participants_vector[i]]){
                    point += int(N-1);
                    participants_vector[i].transfer(uint256(deposit+partReward-pointReward*(N-1)));
                } else {
                    point--;
                    participants_vector[i].transfer(uint256(deposit+partReward+pointReward));
                }
            }
            participants_vector[0].transfer(uint256(int(deposit)+int(partReward)+int(pointReward)*point));
        }

        if(isCreateRandomNumber){
            for(uint i=0;i<M;i++){
                random_number *= N;
                random_number += choice_value[participants_vector[i]];
                rn_bits += log2N;
            }
            lastIsCreate = true;
        } else {
            lastIsCreate = false;
            owner.transfer(compensation);
        }
        resetParameter();
        require(startTime == 0 && participant_number == 0 && !isStartGame,"resetPara failed 1");
        for(uint i=0;i<M;i++){
            require(!participants[participants_vector[i]],"could not false participants");
            require(choice_value[participants_vector[i]] == N,"could not be N choice_value");
        }
    }
    
    function hash(uint256 inp) private pure returns (uint256){
        bytes memory tmp = toBytes(inp);
        bytes32 tmp2 = sha256(tmp);
        return uint256(tmp2);
    }

    function toBytes(uint256 x) private pure returns (bytes memory b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    
    function resetRandomParameter() private {
        random_number = 0;
        rn_bits = 0;
    }

    function generateRandomNumber() public view returns (uint256){
        require(rn_bits == 256,"rn_bits is not 256");
        require(msg.sender == owner,"You are not owner");
        return hash(random_number);
    }
    
    function resetParameter() private {
        participant_number = 0;
        isStartGame = false;
        startTime = 0;
        for(uint i=0;i<M;i++){
            participants[participants_vector[i]] = false;
            choice_value[participants_vector[i]] = N;
        }
    }
}