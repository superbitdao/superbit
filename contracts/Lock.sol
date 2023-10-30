// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
interface ISVT {
    function mint(address _to, uint256 _amount)external;
    function burn(address _to, uint256 _amount)external;
    
}

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
    uint256 lockSbdLimit;
    address public  sbd;
    uint256 public MONTH = 2592000;
    uint public day = 86400;
    address public svt;
    address public srt;
    uint256 public totalWeight;
    lockInfo[] public allLockInfo;
    mapping(uint256 => uint256 ) public Weights;
    mapping(address => lockInfo[]) public userLockInfo;
    mapping(address => uint256) public lastRewardBlock;
    mapping(address => uint256 ) public accSrtPerShare;
    mapping(address => uint256 ) public userWeight;
    mapping (address => uint256 ) public rewardDebt;
    event lockRecord(address user, uint256 lockAmount, uint256 period, uint256 weight, uint256 receiveSVT);
    event withdrawRecord(address user, uint256 unLockAmount,uint256 period,uint256 weight , uint256 burnSVT);
    event claimSrtRecord(address user, uint256 srtAmount);
    event adminDeposit(address admin,address token, uint256 amount);
    event adminWithdraw(address admin,address token, uint256 amount);

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
        require(_rewardTime > 0, "plz input reward time biggest than now");
        uint256 currentTime = block.timestamp;
        reward.push(_amount);
        rewardTime.push(_rewardTime.mul(day));
        startRewardTime.push(currentTime);
        TransferHelper.safeTransferFrom(srt, msg.sender, address(this), _amount);
        emit adminDeposit(msg.sender, srt,_amount);
    }
    function backToken(address _token, uint256 _amount) public onlyOwner {
        uint256 contractSbdAmount = IERC20(sbd).balanceOf(address(this));
        uint256 limitAmount = 0;
        require(IERC20(_token).balanceOf(address(this)) >= _amount,"Insufficient balance of withdrawn tokens");
        if(_token == sbd){
            limitAmount = contractSbdAmount.sub(lockSbdLimit);
            require(_amount <= limitAmount, "Withdrawal exceeds limit");
            TransferHelper.safeTransfer(_token , msg.sender, _amount);
            return;
        }
        TransferHelper.safeTransfer(_token , msg.sender, _amount);
        emit adminWithdraw(msg.sender, _token, _amount);
    }
    function getEndRewardTime(uint256 _rewardId) public view returns(uint256) {
        return startRewardTime[_rewardId].add(rewardTime[_rewardId]);
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
        uint256 _svtAmount = _amount.mul(Weights[_date]);
          updatePower(msg.sender);
        if(userWeight[msg.sender] > 0 ){
            uint256 pending = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).div(1e12).sub(rewardDebt[msg.sender]);
            TransferHelper.safeTransfer(srt,msg.sender, pending);
        }
        rewardDebt[msg.sender] = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).div(1e12);
            _lockTime = _date.mul(MONTH);
            lockInfo memory _lockinfo = lockInfo({
                amount:_amount,
                weight:Weights[_date],
                lockStartTime:block.timestamp,
                lockTime:_lockTime,
                 svtAmount:_svtAmount
                 });
            allLockInfo.push(_lockinfo);
            userLockInfo[msg.sender].push(_lockinfo);
            totalWeight = totalWeight.add(_amount.mul(Weights[_date]));
            userWeight[msg.sender] = userWeight[msg.sender].add(_amount.mul(Weights[_date]));
            ISVT(svt).mint(msg.sender, _svtAmount);
            lockSbdLimit = lockSbdLimit.add(_amount);
            TransferHelper.safeTransferFrom(sbd,msg.sender,address(this),_amount);
            emit lockRecord(msg.sender, _amount,_lockTime,Weights[_date],_svtAmount );
    }
    function getMultiplier(uint256 _from, uint256 _to ) public pure returns (uint256) {
        if (_to > _from) {
            return _to.sub(_from);
        } 
      else{
            return 0;
        }
      
    }
       function updatePower(address _user) public {

        for(uint256 i = 0; i<reward.length;i++){

        if(block.number <= lastRewardBlock[_user]) {
            return;
        }
        if(totalWeight == 0 || lastRewardBlock[_user] == 0){
            lastRewardBlock[_user] = block.number;
            return;
        }
     
        uint256 multiplier = getMultiplier(lastRewardBlock[_user], block.number);
        uint256 srtReward = multiplier.mul(getOneBlockReward(i));
        accSrtPerShare[_user] = accSrtPerShare[_user].add(srtReward.mul(1e12).div(totalWeight));
    }
        lastRewardBlock[_user] = block.number;

    }
    function getOneBlockReward(uint256 _rewardId) public view returns(uint256) {
        uint256 endTime = startRewardTime[_rewardId].add(rewardTime[_rewardId]) ;
        if(block.timestamp > endTime){
            return 0;
        }
        return reward[_rewardId].div(rewardTime[_rewardId].div(intervalTime));
    }
 
    function pendingSrt(address _user) public view returns(uint256) {
        if(accSrtPerShare[_user] == 0){
            return 0;
        }
        uint256 accSrtPerShareE = accSrtPerShare[_user];
        uint256 powerSupply = totalWeight;
        uint256 weight = userWeight[_user];
        uint256 debet = rewardDebt[_user];

        for(uint256 i = 0 ; i <reward.length;i++ ){
        if (block.number > lastRewardBlock[_user] && powerSupply !=0 ) {
            uint256 multiplier = getMultiplier(lastRewardBlock[_user], block.number);
            uint256 srtReward = multiplier.mul(getOneBlockReward(i));
            accSrtPerShareE = accSrtPerShareE.add(srtReward.mul(1e12).div(powerSupply));
        }
        }
        return  weight.mul(accSrtPerShareE).div(1e12).sub(debet);
    }
    function getUserLockLength(address _user) public view returns(uint256 ){
        return userLockInfo[_user].length;
    } 
    function getAllLockLength() public view returns(uint256){
        return allLockInfo.length;
    }
    function ClaimSrt() public {
    updatePower(msg.sender);
        if(userWeight[msg.sender] > 0 ){
            uint256 pending = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).div(1e12).sub(rewardDebt[msg.sender]);
            TransferHelper.safeTransfer(srt,msg.sender, pending);
            emit claimSrtRecord(msg.sender,pending );
        }
        rewardDebt[msg.sender] = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).div(1e12);

    }
    function canClaimSbd(address _user) public view returns(uint256 ){
        uint256 total = 0;
        for(uint256 i = 0; i < userLockInfo[_user].length ; i++) {
           if(userLockInfo[_user][i].amount ==0){
                continue;
            }
            if(userLockInfo[_user][i].lockTime + userLockInfo[_user][i].lockStartTime < block.timestamp){
                total = total.add(userLockInfo[_user][i].amount);
            }
        }
        return total;
    }
    function withdraw(uint256 _id) public {
        lockInfo storage user = userLockInfo[msg.sender][_id];

        uint256 withdrawTime = 0;
        uint256 withdrawAmount = 0;
        uint256 burnAmount = 0;

        burnAmount = user.amount.mul(user.weight);
        withdrawAmount = user.amount;
        withdrawTime =  user.lockStartTime.add(user.lockTime) ;
            updatePower(msg.sender);
            uint256 pending = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).div(1e12).sub(rewardDebt[msg.sender]);
            TransferHelper.safeTransfer(srt,msg.sender, pending);
            rewardDebt[msg.sender] = userWeight[msg.sender].mul(accSrtPerShare[msg.sender]).div(1e12);
            if(user.amount ==0){
                revert("Missing withdrawal amount");
            }
            if(withdrawTime <= block.timestamp){
                user.amount =0;
                ISVT(svt).burn(msg.sender,burnAmount);
                userWeight[msg.sender] = userWeight[msg.sender].sub(burnAmount);
                totalWeight = totalWeight.sub(burnAmount);
                TransferHelper.safeTransfer(sbd,msg.sender, withdrawAmount);
                emit withdrawRecord(msg.sender,withdrawAmount,user.lockTime,user.weight,burnAmount );

            }
    }
    
}
