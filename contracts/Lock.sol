// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


// File: contracts/libraries/TransferHelper.sol



pragma solidity >=0.6.0;

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
interface ISVT {
    function mint(address _to, uint256 _amount)external;
    function burn(address _to, uint256 _amount)external;
    
}

contract Lock  is Ownable{
    using SafeMath for uint256 ;

    struct lockInfo{
        uint256 amount;
        uint256 weight;
        uint256 lockStartTime;
        uint256 lockTime;
        uint256 svtAmount;
    }
    uint256[] public reward;
    uint256[] public startRewardTime;
    uint256[] public rewardTime;
    uint256 public intervalTime = 5;
    address public  sbd;
    uint256 public MONTH = 2592000;
    address public svt;
    address public srt;
    uint256 public oneMonth;
    uint256 public totalWeight;
    mapping(uint256 => uint256 ) public Weights;
    mapping(address => lockInfo[]) public userLockInfo;
    mapping(address => uint256[] ) public lastRewardBlock;
    mapping(address => uint256 ) public accSrtPerShare;
    mapping(address => uint256 ) public userWeight;
    mapping (address => uint256 ) public rewardDebt;



    constructor(address _sbd, address _svt,address _srt){
        sbd = _sbd;
        svt = _svt;
        srt = _srt;
        Weights[0] = 1;
        Weights[1] = 2;
        Weights[3] = 3;
        Weights[6] = 4;
        Weights[9] = 5;
        Weights[12] = 6;
        Weights[15] = 7;
        Weights[18] = 8;
        Weights[24] = 9;

    } 
    function deposit(uint256 _amount,uint256 _rewardTime) public  onlyOwner{
        require(_rewardTime > block.timestamp, "plz input reward time biggest than now");
        TransferHelper.safeTransferFrom(srt, msg.sender, address(this), _amount);
        rewardTime.push(_rewardTime);

        startRewardTime.push(block.timestamp);
    }
    function getRewardLength() public view returns(uint256) {
        return startRewardTime.length;
    }
    function lock(uint256 _date,uint256 _amount) public {
            require(
            _date == 0 ||
            _date == 1 ||
            _date == 3 ||
            _date == 6 ||
            _date == 9 ||
            _date == 12 ||
            _date == 15 ||
            _date == 18 ||
            _date == 24 
            );
        uint256 _lockTime = 0;
        uint256 _svtAmount = 0;
          updatePower();
        if(userWeight[msg.sender] > 0 ){
            uint256 pending = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).sub(rewardDebt[msg.sender]);
            TransferHelper.safeTransfer(sbd,msg.sender, pending);
        }
        rewardDebt[msg.sender] = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]);
            _lockTime = _date.mul(oneMonth);
            lockInfo memory _lockinfo = lockInfo({
                amount:_amount,
                weight:Weights[_date],
                lockStartTime:block.number,
                lockTime:_lockTime,
                 svtAmount:_amount.mul(Weights[_date])
                 });
            userLockInfo[msg.sender].push(_lockinfo);
            totalWeight = totalWeight.add(_amount.mul(Weights[_date]));
            userWeight[msg.sender] = userWeight[msg.sender].add(_amount.mul(Weights[_date]));
            ISVT(svt).mint(msg.sender, _svtAmount);
            TransferHelper.safeTransferFrom(sbd,msg.sender,address(this),_amount);
            
    }
    function getMultiplier(uint256 _from, uint256 _to, uint256 i) public view returns (uint256) {
        if (_from >= lastRewardBlock[msg.sender][i]) {
            return _to.sub(_from);
        } else if(_from < lastRewardBlock[msg.sender][i]){
            return _to.sub(lastRewardBlock[msg.sender][i]);
        }else{
            return 0;
        }
      
    }
       function updatePower() public {
        for(uint256 i = 0 ; i < lastRewardBlock[msg.sender].length; i++){

        if(block.number <= lastRewardBlock[msg.sender][i]) {
            return;
        }
        if(totalWeight == 0){
            lastRewardBlock[msg.sender][i] = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(lastRewardBlock[msg.sender][i], block.number, i);
        uint256 srtReward = multiplier.mul(getOneBlockReward(i));
        accSrtPerShare[msg.sender] = accSrtPerShare[msg.sender].add(srtReward.div(totalWeight));
        lastRewardBlock[msg.sender][i] = block.number;
        }

    }
    function getOneBlockReward(uint256 _rewardId) public view returns(uint256) {
        return reward[_rewardId].div(rewardTime[_rewardId].div(intervalTime));
    }
 
    function pendingSrt(address _user) public view returns(uint256 ) {
           uint256 total = 0;
        uint256 accSrtPerShareE = accSrtPerShare[_user];
        for(uint256 i = 0 ; i <lastRewardBlock[_user].length;i++ ){
        uint256 powerSupply = totalWeight;
        if (block.number > lastRewardBlock[_user][i] && powerSupply != 0) {
            uint256 multiplier = getMultiplier(lastRewardBlock[_user][i], block.number,i);
            uint256 srtReward = multiplier.mul(getOneBlockReward(i));
            accSrtPerShareE = accSrtPerShare[_user].add(srtReward.div(powerSupply));
            total = total.add(userWeight[_user].mul(accSrtPerShare[_user]).sub(rewardDebt[_user]));
        }
        }
       
        return total;
    }
    function getUserLockLength(address _user) public view returns(uint256 ){
        return userLockInfo[_user].length;
    } 

    function ClaimSrt() public {
    updatePower();
        if(userWeight[msg.sender] > 0 ){
            uint256 pending = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).sub(rewardDebt[msg.sender]);
            TransferHelper.safeTransfer(sbd,msg.sender, pending);
        }
        rewardDebt[msg.sender] = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]);
    }
    function withdraw(uint256 _amount) public {
        uint256 total = 0;
        uint256 per = 0;
            updatePower();
        if(userWeight[msg.sender] > 0 ){
            uint256 pending = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).sub(rewardDebt[msg.sender]);
            TransferHelper.safeTransfer(sbd,msg.sender, pending);
        }
        rewardDebt[msg.sender] = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]);
        for(uint256 i = 0; i < userLockInfo[msg.sender].length ; i++) {
            if(userLockInfo[msg.sender][i].amount ==0){
                continue;
            }
            per = userLockInfo[msg.sender][i].amount.mul(block.number.sub(userLockInfo[msg.sender][i].lockStartTime)).div(userLockInfo[msg.sender][i].lockTime);
            total= total.add(per);
            if(userLockInfo[msg.sender][i].amount > per){
            userLockInfo[msg.sender][i].amount = userLockInfo[msg.sender][i].amount.sub(per);
            }else{
                totalWeight = totalWeight.sub(userLockInfo[msg.sender][i].amount.mul(userLockInfo[msg.sender][i].weight));
                userLockInfo[msg.sender][i].amount  =0;

            }
            userLockInfo[msg.sender][i].lockStartTime = block.number;
            userLockInfo[msg.sender][i].svtAmount = userLockInfo[msg.sender][i].svtAmount.sub(per.mul(userLockInfo[msg.sender][i].weight));
            ISVT(svt).burn(msg.sender, per.mul(userLockInfo[msg.sender][i].weight));
            if(_amount == total){
            TransferHelper.safeTransfer(sbd,msg.sender, _amount);
            
            }
        }
    }
    
}
