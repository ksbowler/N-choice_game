pragma solidity 0.8.18;
contract choices {
    address payable public owner;
    uint Onewei = 1 wei;
    uint D;
    uint Rp;
    uint Rg;
    uint Ra;
    uint256 random_number = 0;
    uint rn_bits = 0;
    uint M; 
    uint N; 
    uint log2N;
    
    constructor() payable{
        owner = payable(msg.sender);
    }

    mapping (address => bool) participants; 
    //address payable[] participants_vector; // 可変長 
    uint m = 0; 
    mapping (address => uint256) choice_value; 
    mapping (address => uint256) hash_value;
    //mapping (address => bool) isPaidDeposit;
    mapping (address => uint256) earn_money; //will delete
    //address payable[16] participants_vector_memory;
    mapping (uint256 => address payable) participants_mapping;
    uint Ts1; 
    uint Ts2; 
    uint Ts3; 
    uint Ts4; 
    uint Tv; 
    uint Tp;
    uint8 state = 255;
    bool isSetParameter = false;
    bool isEnoughParticipants = false;

    event ownerPreparedNCG(address indexed to);
    event startRecruitingParticipants(address indexed to);
    event startGenerateHashValuePhase(address indexed to);
    event startInputValuePhase(address indexed to);
    event startGetRewardPhase(address indexed to);
    event readyToGenerateRandomNumber(address indexed to);
    event generateHashValueDone(address indexed to);
    event inputValueDone(address indexed to);
    event stopNCG(address indexed to);

    function min(uint a, uint b) public pure returns (uint){
        if(a < b) return a;
        return b;
    }

    function max(uint a, uint b) public pure returns (uint){
        if(a < b) return b;
        return a;
    }
    
    
    function preparationOwner(uint _m, uint _Tv, uint _Tp) payable public{
        require(msg.sender == owner, "You are not owner");
        require(_m >= 2,"Small m");
        require(state >= 5, "NCG can not start now");
        //require(!isStartGame,"isStartGame is true"); //修正すべき
        // require(msg.value >= part*m,"msg.value is short");
        // require(dep >= part*(m-1)+point*max(m-1,n-1)+comp,"dep is not enough value");
        // require(part <= point*min(m-1,n-1),"part is too big");
        // require(point*max(m-1,n-1) <= part+dep,"part and dep is not enough");
        m = _m;
        M = 0;

        Tv = _Tv;
        Tp = _Tp;


        Ra = msg.value;
        D = uint(msg.value/m);

        isEnoughParticipants = false;
        state = 255;
        setState();
        emit ownerPreparedNCG(owner);
    }

    function setState() internal {
        if(state == 255){ //ゲーム終了時。この関数が呼ばれるのは、Ownerが準備をした時くらい
            Ts1 = block.timestamp;
            state = 1; //参加者募集フェーズ
            emit startRecruitingParticipants(owner);
            return;
        } else if (state == 1){
            //本当に参加者募集フェーズかどうか
            uint bt = block.timestamp;
            if(Ts1 + Tp >= bt) {
                //参加者募集フェーズ
                return;
            }
            //参加者募集フェーズではない
            state = 2; //値入力１フェーズ
            if(isEnoughParticipants){
                Ts2 = block.timestamp;
                emit startGenerateHashValuePhase(owner);
                return;
            }
            //人が集まっていない
            notEnoughParticipants();
            return;
        } else if(state == 2) {
            //本当に値入力１フェーズかどうか
            uint bt = block.timestamp;
            if(Ts2 + Tv >= bt){
                //値入力１フェーズ
                return;
            }
            state = 3; //値入力２フェーズ
            Ts3 = block.timestamp;
            emit startInputValuePhase(owner);
            return;

        } else if(state == 3) {
            //本当に値入力２フェーズかどうか
            uint bt = block.timestamp;
            if(Ts3 + Tv >= bt){
                //値入力２フェーズ
                return;
            }
            state = 4; //報酬受け取りや値生成
            Ts4 = block.timestamp;
            emit readyToGenerateRandomNumber(owner);
            return;

        } else if(state == 4){
            //state = 255;
            return;
        } else if(state == 5) {
            return;
        }
        require(false,"Unexpectable state");
    }

    function getState() external returns (bytes32) {
        setState();
        if(state == 1) return "Recruiting participants";
        else if(state == 2) return "generateHashValue";
        else if(state == 3) return "inputValue";
        else if (state == 4) return "Reward and Create number";
        else if (state == 5) return "Finish the game";
        else if (state == 255) return "Not start game.";
        else return "error";
    }

    function getState2() public view returns (bytes32) { //Will delete
        if(state == 255){ 
            return "Not start game."; 
        } else if (state == 1){
            //本当に参加者募集フェーズかどうか
            if(Ts1 + Tp >= block.timestamp) {
                //参加者募集フェーズ
                return "Recruiting participants";
            }
            //参加者募集フェーズではない
            return "generateHashValue";
        } else if(state == 2) {
            //本当に値入力１フェーズかどうか
            if(Ts2 + Tv >= block.timestamp){
                //値入力１フェーズ
                return "generateHashValue";
            }
            return "inputValue";

        } else if(state == 3) {
            //本当に値入力２フェーズかどうか
            if(Ts3 + Tv >= block.timestamp){
                //値入力２フェーズ
                return "inputValue";
            }
            return "Reward and Create number";

        } else if(state == 4){
            //state = 255;
            return "Reward and Create number";
        } else if(state == 5) {
            return "Finish the game";
        }
        require(false,"Unexpectable state");
    }

    function getEarnMoney() public view returns(uint256){
        require(participants[msg.sender] || msg.sender == owner,"You are not participants and owner");
        return earn_money[msg.sender];
    }

    function getSize(uint x) public returns (uint) {
        for(uint i=1; i<=300; i++){
            if(x >> i == 0){
                return i;
            }
        }
    }

    function setParameter() internal {
        //参加ノード数が確定している
        //参加報酬が確定
        Rp = uint(Ra/M);

        //選択肢数が確定
        uint M_size = getSize(M-1);
        N = 1 << M_size;
        log2N = M_size;

        //NCG得点単価が確定
        Rg = uint((D + Rp)/max(N-1,M-1));
        require(D+Rp >= Rg*max(N-1,M-1), "Error: big Rg");
        require(Rg*min(N-1,M-1) > Rp, "Error: small Rg");
        // for(uint i=0;i<M;i++){
        //     participants_vector_memory[i] = participants_vector[i];
        // }
        
    }

    function getParameters(uint op) public view returns (uint){
        if(op == 1) return M;
        if(op == 2) return D;
        if(op == 3) return N;
        if(op == 4) return Ra;
        if(op == 5) return Rp;
        if(op == 6) return Rg;
        if(op == 7) return Rg*max(N-1,M-1);
        if(op == 8) return Rg*min(N-1,M-1);
        if(op == 9) return log2N;
        if(op == 10) return Ts1;
        if(op == 11) return Ts2;
        if(op == 12) return Ts3;
        if(op == 13) return Ts4;
        if(op == 14) return Tv;
        if(op == 15) return Tp;
        if(op == 16) return block.timestamp;

    }

    function ownerSetParameter() public {
        require(msg.sender == owner,"Only owner can set parameters");
        require(!isSetParameter,"Parameters is already set");
        setState();
        if(state >= 2) setParameter();
    }
    
    function notEnoughParticipants() internal {
        //参加者が十分に集まらなかった場合
        for(uint i=0;i<M;i++){
            //デポジットの返金
            participants_mapping[i].send(D);
        }
        resetParameter();
        require(M == 0,"resetPara failed 2");
        emit stopNCG(owner);
        state = 5;
    }

    function participantReception() payable public {
        require(msg.sender != owner,"You are owner");
        require(!participants[msg.sender],"You are participants");

        require(msg.value >= D,"You did not pay deposit enough value"); //デポジット支払

        //参加者募集フェーズかどうか
        setState();
        require(state == 1, "Now is not recruiting participants.");
        
        address payable participant = payable(msg.sender);
        participants[participant] = true;
        participants_mapping[M] = payable(msg.sender);
        //participants_vector.push(participant);
        choice_value[participant] = N;
        M++;
        if (M >= m) isEnoughParticipants = true;
    }

    function generateHashValue(uint256 hashValue) public {
        require(participants[msg.sender],"You are not participants");
        //値入力１フェーズ
        setState();
        require(state == 2, "Now is not generateHashValue time");
        if(!isSetParameter){
            setParameter();
            isSetParameter = true;
        }
        hash_value[msg.sender] = hashValue;
        emit generateHashValueDone(msg.sender);
    }

    function inputValue(uint256 value) public {
        require(participants[msg.sender],"You are not participants");
        //値入力２フェーズ
        setState();
        require(state == 3, "Now is not inputValue time");
        uint256 hashValue = hash(value);
        require(hashValue == hash_value[msg.sender],"The hash value of your input does not match one in advance");
        choice_value[msg.sender] = value%N;
        emit inputValueDone(msg.sender);
    }

    
    function finishGame() public payable{
        require(participants[msg.sender] || msg.sender == owner,"You are not participants and owner");
        //報酬受け取りや値生成フェーズ
        setState();
        require(state == 4,"You can not finish Game now");
        
        
        //address payable dealer = participants_vector[0];
        address payable dealer = participants_mapping[0];


        //address payable dealer = owner;
        uint cv = choice_value[dealer];
        //uint cv = 8;
        if(cv == N) {
            for(uint i=1;i<M;i++){
                //address payable player = participants_vector[i];
                //address payable player = owner;
                address payable player = participants_mapping[i];
                if(choice_value[player] < N){
                    earn_money[player] = D+Rp+Rg;
                    player.send(D+Rp+Rg); // sendじゃないと止まってしまう可能性あり
                }
            }
        } else {
            int point = 0;
            for(uint i=1;i<M;i++){
                //address payable player = participants_vector[i];
                address payable player = participants_mapping[i];
                //address payable player = owner;
                if(choice_value[player] == N){
                    point += int(N-1);
                } else if(cv == choice_value[player]){
                    point += int(N-1);
                    earn_money[player] = D+Rp-Rg*(N-1);
                    player.send(uint256(D+Rp-Rg*(N-1)));
                } else {
                    point--;
                    earn_money[player] = D+Rp+Rg;
                    player.send(uint256(D+Rp+Rg));
                }
            }
            earn_money[dealer] = uint256(int(D)+int(Rp)+int(Rg)*point);
            dealer.send(uint256(int(D)+int(Rp)+int(Rg)*point));
        }

        for(uint i=0;i<M;i++){
            address payable player = participants_mapping[i];
            //address payable player = owner;
            if (choice_value[player] < N) {
                random_number *= N;
                random_number += choice_value[player];
                rn_bits += log2N;
                if(rn_bits >= 256) emit readyToGenerateRandomNumber(owner);
            }
        }
        state = 5;

        resetParameter();
        require(M == 0,"resetPara failed 1");
    }
    
    function hash(uint256 inp) public pure returns (uint256){
        bytes memory tmp2 = abi.encodePacked(inp);
        bytes32 tmp3 = sha256(tmp2);
        return uint256(tmp3);
    }

    function generateRandomNumber() public returns (uint256){
        require(rn_bits >= 256,"rn_bits is not 256");
        require(msg.sender == owner,"You are not owner");
        rn_bits = 0;
        uint256 ret = hash(random_number);
        random_number = 0;
        return ret;
    }
    
    function resetParameter() public {
        for(uint i=0;i<M;i++){
            address payable player = participants_mapping[i];
            participants[player] = false;
            choice_value[player] = N;
        }
        // for(uint i=M-1;i>=0;i--){
        //     delete participants_vector[i];
        // }
        M = 0;
        state = 5;
    }
}