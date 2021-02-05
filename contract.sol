pragma solidity >=0.4.22 <0.6.0;

contract TronChain {
    struct Capitalpool {
        uint16 period;
        uint256 pool;
        uint256 poolSurplus;
        uint256 insurance;
    }
    
    
    struct Investment {
        address owner;
        uint16 period;
        uint256 amount;
        uint256 outAmount;
        bool out;
        uint created_at;
    }
    
    struct User {
        uint8 investmentNums;
        uint256 investmentAmount;
        address parent;
        uint32  recommend;
        address[] parentUser;
        mapping(uint32 => address[]) sonList;
    }
    
    struct Income {
        uint staticAmount;
        uint manageAmount;
        uint bestAmount;
        uint totalAmount;
    }
    
    struct Management {
        uint16 algebra;
        address source;
        uint created_at;
    }
    
    struct Best {
        address owner;
        uint16 number;
        uint amount;
        uint created_at;
    }
   
    struct Recommend {
        address owner;
        address referee;
        uint created_at;
    }
    
    enum WithdrawType { Static, Manager, Best, Reward}
    struct WithdrawRecord {
       WithdrawType types;
       uint amount;
       uint created_at;
    }
    
    struct Withdraw {
        uint staticAmount;
        uint managerAmount;
        uint bestAmount;
        uint rewardAmount;
    }
    
    struct iuserMap {
        mapping(address => User) users;                                 
        mapping(uint => address) keys;
        uint size;
    }
    
    uint16 period;                                                     
    
    uint32 public investmentId;                                                
    mapping(uint32 => Investment) public investments;                          
    mapping(address => uint32[]) userInvestments;                       
    
    uint32 public recommendId;                                                 
    mapping(uint32 => Recommend) public recommends;                            
    
    uint8 rate = 100;
    uint8 poolRate = 72;
    uint8 insuranceRate = 15;
    uint8 outRate = 3;
    
    uint256 investmentMin = 10_000_000;                                 
    
    address chairperson;                                                
    
    mapping(uint16 => Capitalpool) capitalpools;                        
    mapping(address => Management[]) managements;                      
    mapping(address => Income) incomes;                                 
    mapping(address => WithdrawRecord[]) withdrawRecords;              
    mapping(address => Withdraw) withdraws;                            
    
    iuserMap userMap;
    
    address[] snapParentUser;                                           
    address[] snapSonUser;                                              
    mapping(uint32 => address[]) snapSonUserBase;                      
    
    uint8 maxLevel = 50;                                                
    
    uint8 managerOpenCondition = 3;                                   
    
    uint public bestTime;                                                   
    mapping (address => uint16) public bestMapping;
    address[] public bestArray;
    

    constructor(uint16 _num, uint _bestTime) public {
        chairperson = msg.sender;
        period = _num;
        capitalpools[_num].period = period;
        bestTime = _bestTime;
    }
    

    function deposit(address _superior) public payable returns (bool) {
        if (msg.value < investmentMin) revert('Minimum deposit');
        
        User storage _user = userMap.users[msg.sender];
        uint32[] storage _userInvestments = userInvestments[msg.sender];
        
        if (_superior != address(0x0) && _user.parent == address(0x0) && _user.investmentNums == 0) {
            if(userMap.users[_superior].investmentNums > 0){
                _user.parent = _superior;
                userMap.users[_superior].recommend += 1;

                recommendId += 1;
                recommends[recommendId].owner = _superior;
                recommends[recommendId].referee = msg.sender;
                recommends[recommendId].created_at = now;
            }
        }
        
        if (_user.investmentNums > 0) {
            if (investments[_userInvestments[_userInvestments.length - 1]].out == false) {
                revert('Can re-invest after being out');
            } else {
                uint _lastAmount = investments[_userInvestments[_userInvestments.length - 1]].amount;
                if (msg.value < (_lastAmount * 10 * 15) / 100) {
                    revert('The reinvestment amount must be more than');
                }
            }
        }
        userMap.size++;
        userMap.keys[userMap.size] = msg.sender;
        _user.investmentNums += 1;
        _user.investmentAmount += msg.value;
        investmentId += 1;
        Investment storage sender = investments[investmentId];
        _userInvestments.push(investmentId);
        uint256 amount = msg.value;
        sender.owner = msg.sender;
        sender.period = period;
        sender.amount = amount;
        sender.outAmount = amount * outRate;
        sender.created_at = now;
        Capitalpool storage capital = capitalpools[period];
        capital.pool += amount * poolRate / rate;
        capital.poolSurplus += amount * poolRate / rate;
        capital.insurance += amount * insuranceRate / rate;
        snapParentUser.length = 0;
        this.findParent(msg.sender, 0);
        _user.parentUser = snapParentUser;
        if(snapParentUser.length > 0) {
            for (uint _key = 0; _key < snapParentUser.length; _key++) {
                address _address  = snapParentUser[_key];
                address[] memory _addressList = new address[](1);
                _addressList[0] = snapParentUser[_key];
                this.updateSon(_addressList, 0);
                for(uint8 _key2 = 0; _key2 < maxLevel; _key2++) {
                    if(snapSonUserBase[_key2].length == 0) break;
                    userMap.users[_address].sonList[_key2] = snapSonUserBase[_key2];
                }
                for(uint8 _key2 = 0; _key2 < maxLevel; _key2++) {
                    if(snapSonUserBase[_key2].length == 0) break;
                    delete snapSonUserBase[_key2];
                }
            }
        }
        this.bestRecommend();
        return true;
    }
    
    function capitalData() public view returns (uint16, uint256, uint256, uint256) {
        Capitalpool storage capital = capitalpools[period];
        return (capital.period, capital.pool, capital.insurance, capital.poolSurplus);
    }
    
    function myDeposit() public view returns (uint16, uint256, uint256, bool, address) {
        uint32[] storage _userInvestments = userInvestments[msg.sender];
        Investment storage sender = investments[_userInvestments[_userInvestments.length - 1]];
        return (sender.period, sender.amount, sender.outAmount, sender.out, sender.owner);
    }
    
    function user() public view returns (uint16, uint256, uint32, address, address[] memory, address[] memory) {
        User storage _user = userMap.users[msg.sender];
        return (_user.investmentNums, _user.investmentAmount, _user.recommend, _user.parent, _user.parentUser, _user.sonList[0]);
    }
    
    function myIncome() public view returns(uint) {
        Income storage income = incomes[msg.sender];
        return (income.bestAmount);
    }
    
    function getStaticIncome() public view returns (uint) {
        return this.calcStaticIncome(msg.sender, true);
    }
    
    function totalUser() public view returns (uint) {
        return userMap.size;
    }
    
    function calcStaticIncome(address _address, bool minus) public view returns (uint) {
        uint32[] storage _userInvestments = userInvestments[_address];
        Investment storage sender = investments[_userInvestments[_userInvestments.length - 1]];
        uint income = 0;
        if(sender.amount <= 0) {
            return income;
        }
        uint dayIncome = (sender.amount * 10 * 2) / 1000;
        uint diff = now - sender.created_at;
        uint day = diff / 1 days;
        if (day > 0) {
            income += dayIncome * day;
        }
        uint secone = diff - (1 days * day);
        uint times = secone / 5;
        income += times * (dayIncome / 1 days * 5);
        
        income = income > sender.amount  ? sender.amount : income;
        
        if (minus) {
            Withdraw storage withdraw = withdraws[_address];
            income = income - withdraw.staticAmount;
            if (income < 0) income = 0;
        }
        return income;
    }
    
    function findParent(address _address, uint32 _level) public {
        User storage _user = userMap.users[_address];
        uint16 keyIndex = 1;
        while(keyIndex <= userMap.size && _level <= maxLevel) {
            address _key = userMap.keys[keyIndex];
            if (_key == _user.parent) {
                snapParentUser.push(_key);
                this.findParent(_key, _level + 1);
                break;
            }
            keyIndex++;
        }
    }
    
    function updateSon(address[] memory _addressList, uint32 _level) public {
        if(_level > maxLevel) return;
        for (uint8 _keyIndex = 0; _keyIndex < _addressList.length; _keyIndex++) {
            this.findSon(_addressList[_keyIndex]);
        }
        if(snapSonUser.length > 0) {
            snapSonUserBase[_level] = snapSonUser;
            snapSonUser.length = 0;
            this.updateSon(snapSonUser, _level + 1);
        }
    }
    
    function findSon(address _address) public {
        uint16 keyIndex = 1;
        while(keyIndex <= userMap.size) {
            address _key = userMap.keys[keyIndex];
            User memory _user = userMap.users[_key];
            if (_user.parent == _address) {
                snapSonUser.push(_key);
            }
            keyIndex++;
        }
    }
    
    function getLastet() public view returns(address[] memory, uint256[] memory) {
        address[] memory addressArray = new address[](investmentId >= 200 ? 200 : investmentId);
        uint[] memory amountArray =  new uint[](investmentId >= 200 ? 200 : investmentId);
        uint8 a = 0;
        for (uint32 i = investmentId; i > 0; i--) {
            addressArray[a] = investments[i].owner;
            amountArray[a] = investments[i].amount;
            a++;
        }
        return (addressArray,amountArray);
    }
    
    function bestRecommend() public {
        if((now - bestTime) >= 1 days) {
            uint day = (now - bestTime) / 1 days;
            uint lastTime = bestTime + (day * 1 days);
            for (uint32 _i = 0; _i < bestArray.length; _i++) {
                bestMapping[bestArray[_i]] = 0;
            }
            bestArray.length = 0;
            for (uint32 _i = recommendId; _i >= 1; _i--) {
                if(recommends[_i].created_at <= lastTime && recommends[_i].created_at >= bestTime) {
                    bestMapping[recommends[_i].owner] = bestMapping[recommends[_i].owner] + 1;
                    bool _have = false;
                    for (uint32 _a = 0; _a < bestArray.length; _a++) {
                        if(bestArray[_a] == recommends[_i].owner){
                            _have = true;
                        }
                    }
                    if (!_have) {
                        bestArray.push(recommends[_i].owner);
                    }
                } else {
                  break;  
                }
            }
            if (bestArray.length > 0) {
                uint max = bestArray.length - 1;
                for (uint16 j = 0; j < max; j++) {
                    bool done = true;
                    for (uint16 i = 0; i < max - j; i++) {
                      if (bestMapping[bestArray[i]] > bestMapping[bestArray[i + 1]]) {
                        address temp = bestArray[i];
                        bestArray[i] = bestArray[i + 1];
                        bestArray[i + 1] = temp;
                        done = false;
                      }
                    }
                    if (done) {
                      break;
                    }
                }
                uint _bestAmount = 0;
                for (uint32 _i = investmentId; _i >= 1; _i--) {
                    if (investments[_i].created_at <= lastTime && investments[_i].created_at >= bestTime) {
                        _bestAmount += (investments[_i].amount * 3) / 100;
                    } else {
                        break;
                    }
                }
                if (bestArray.length >= 1) {
                    Income storage income = incomes[bestArray[bestArray.length - 1]];
                    income.bestAmount += (_bestAmount * 3) / 10;
                }
                if (bestArray.length >= 2) {
                    Income storage income = incomes[bestArray[bestArray.length - 2]];
                    income.bestAmount += (_bestAmount * 25) / 100;
                }
                if (bestArray.length >= 3) {
                    Income storage income = incomes[bestArray[bestArray.length - 3]];
                    income.bestAmount += (_bestAmount * 20) / 100;
                }
                if (bestArray.length >= 4) {
                    Income storage income = incomes[bestArray[bestArray.length - 4]];
                    income.bestAmount += (_bestAmount * 15) / 100;
                }
                if (bestArray.length >= 5) {
                    Income storage income = incomes[bestArray[bestArray.length - 5]];
                    income.bestAmount += (_bestAmount * 10) / 100;
                }
            }
            bestTime = lastTime;
        }
    }
    
    function calcManagementIncome(address _address) public view returns (uint) {
        uint totalIncome = 0;
        for (uint8 i = 0; i < maxLevel; i++) {
            address[] memory _memory = userMap.users[_address].sonList[i];
            if(_memory.length == 0) break;
            for (uint8 a = 0; a < _memory.length; a++) {
                uint income = this.calcStaticIncome(_memory[a], false);
                if (income <= 0) continue;
                if (i == 0) {
                    // 15%
                    totalIncome += (income * 10 * 15) / 1000;
                } else if (i == 1) {
                    // 10%
                    totalIncome += (income * 10 * 10) / 1000;
                } else if (i == 2) {
                    // 6%
                    totalIncome += (income * 10 * 6) / 1000;
                } else if (i == 3) {
                    // 3%
                    totalIncome += (income * 10 * 3) / 1000;
                } else {
                    // 1%
                    totalIncome += (income * 10 * 1) / 1000;
                }
            }
        }
        Withdraw storage withdraw = withdraws[_address];
        totalIncome = totalIncome - withdraw.managerAmount;
        if (totalIncome < 0) totalIncome = 0;
        return totalIncome;
    }
    
    function withdrawIncome() public payable returns (bool) {
        Capitalpool storage capital = capitalpools[period];
        
        uint withdrawAmount = 0;
        
        uint32[] storage _userInvestments = userInvestments[msg.sender];
        Investment storage sender = investments[_userInvestments[_userInvestments.length - 1]];
        if(sender.amount <= 0) revert('You have not yet deposited');
        
        uint staticAmount = this.calcStaticIncome(msg.sender, true);
        uint managerAmount = this.calcManagementIncome(msg.sender);
        if (staticAmount + managerAmount <= 0) revert('No cashable income');
        
        uint totalAmount = staticAmount + managerAmount;
        
        uint staticMentioned = 0;
        uint managerMentioed = 0;
        WithdrawRecord[] memory records = withdrawRecords[msg.sender];
        for (uint i = records.length - 1; i >= 0; i--) {
            if (records[i].created_at < sender.created_at) {
                break;
            }
            if (records[i].types == WithdrawType.Static) {
                staticMentioned += records[i].amount;
            } else if (records[i].types == WithdrawType.Manager) {
                managerMentioed += records[i].amount;
            }
        }
        if ((staticMentioned + managerMentioed + totalAmount) >= sender.outAmount) {
            sender.out = true;
            withdrawAmount = sender.outAmount - (staticMentioned + managerMentioed + totalAmount);
            managerAmount = sender.amount * 2 - (managerMentioed + managerAmount);
        } else {
            withdrawAmount = totalAmount;
        }
        
        this.bestRecommend();
        
        if (capital.poolSurplus < withdrawAmount) {
            return false;
        } else {
            Income storage income = incomes[msg.sender];
            income.staticAmount += staticAmount;
            income.manageAmount += managerAmount;
            income.totalAmount += totalAmount;
            
            Withdraw storage withdraw = withdraws[msg.sender];
            withdraw.staticAmount += staticAmount;
            withdraw.managerAmount += managerAmount;
            
            WithdrawRecord  memory staticRecord;
            staticRecord.types = WithdrawType.Static;
            staticRecord.amount = staticAmount;
            staticRecord.created_at = now;
            withdrawRecords[msg.sender].push(staticRecord);
            
            WithdrawRecord  memory managerRecord;
            managerRecord.types = WithdrawType.Manager;
            managerRecord.amount = managerAmount;
            managerRecord.created_at = now;
            withdrawRecords[msg.sender].push(managerRecord);
            
            capital.poolSurplus -= withdrawAmount;
            
            msg.sender.transfer(withdrawAmount);
        }
        
        return true;
    }
}
