// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

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
    IERC20 sbd;
    address public svt;
    address public srt;
    uint256 public oneBlockReward; 
    uint256 public oneMonth;
    uint256[9] public date = [
        0,
        1,
        3,
        6,
        9,
        12,
        15,
        18,
        24

    ];
    uint256[9] public Weights =[1,2,3,4,5,6,7,8,9];
    mapping(address => lockInfo[]) public userLockInfo;

    constructor(IERC20 _sbd, address _svt,address _srt){
        sbd = _sbd;
        svt = _svt;
        srt = _srt;
        oneMonth = 576000;
    } 
    function deposit(uint256 _amount,uint256 _rewardTime) public  onlyOwner{
        IERC20(srt).transferFrom(msg.sender, address(this), _amount);
        oneBlockReward = _amount.div(_rewardTime);
    }
    function lock(uint256 _date,uint256 _amount) public {
        uint256 _lockTime = 0;
        uint256 _Weights = 0;
        uint256 _svtAmount = 0;
        for(uint256 i = 0 ; i < date.length ; i++){
            if(_date == date[i]){
            _Weights = Weights[i];
            _lockTime = _date.mul(oneMonth);
            _svtAmount = _amount.mul(Weights[i]);
            lockInfo memory _lockinfo = lockInfo({amount:_amount,weight:_Weights,lockStartTime:block.number,lockTime:_lockTime, svtAmount:_svtAmount});
            userLockInfo[msg.sender].push(_lockinfo);
            }
        }
        ISVT(svt).mint(msg.sender, _svtAmount);

    }
    
    function getUserCanClaim() public view returns(uint256 ) {
        uint256 total = 0;
        for(uint256 i =0 ; i< userLockInfo[msg.sender].length ; i++ ) {
            total= total.add(userLockInfo[msg.sender][i].amount.mul(block.number.sub(userLockInfo[msg.sender][i].lockStartTime)).div(userLockInfo[msg.sender][i].lockTime));
        }
        return total;
    }
    function getUserLockLength(address _user) public view returns(uint256 ){
        return userLockInfo[_user].length;
    } 
    function withdraw(uint256 _amount) public {
        require(getUserCanClaim() >= 0, "Insufficient withdrawal limit");
        uint256 total = 0;
        uint256 per = 0;
        
        for(uint256 i = 0; i < userLockInfo[msg.sender].length ; i++) {
            if(userLockInfo[msg.sender][i].amount ==0){
                continue;
            }
            per = userLockInfo[msg.sender][i].amount.mul(block.number.sub(userLockInfo[msg.sender][i].lockStartTime)).div(userLockInfo[msg.sender][i].lockTime);
            total= total.add(per);
            if(userLockInfo[msg.sender][i].amount > per){
            userLockInfo[msg.sender][i].amount = userLockInfo[msg.sender][i].amount.sub(per);
            }else{
                userLockInfo[msg.sender][i].amount  =0;
            }
            // lockInfo memory _lockinfo = lockInfo({amount:_amount,weight:_Weights,lockStartTime:block.number,lockTime:_lockTime, svtAmount:_svtAmount});
            userLockInfo[msg.sender][i].lockStartTime = block.number;
            userLockInfo[msg.sender][i].svtAmount = userLockInfo[msg.sender][i].svtAmount.sub(per.mul(userLockInfo[msg.sender][i].weight));
            ISVT(svt).burn(msg.sender, per.mul(userLockInfo[msg.sender][i].weight));
            if(_amount == total){
            sbd.transfer(msg.sender, _amount);
                
            }
        }
    }
    
}
