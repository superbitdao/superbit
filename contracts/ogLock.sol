//	SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
interface ISVT{
    function mint(address _to, uint256 _amount)external;
    function burn(address _to, uint256 _amount) external;
}
contract ogLock is Ownable {

using SafeMath for uint256;
    struct LockInfo{
        address user;
        uint256 amount;
        uint256 lockBlock;
        uint256 startTime;
    }
    IERC20 sbd;
    
    address public  svt;
    uint256 public oneYear;
    mapping(address => bool) public allowAddr;
    mapping(address => LockInfo[]) public userLockInfos;
constructor (){
        oneYear = 31536000;

}
    function setAllowAddr(address _addr, bool _set) public onlyOwner {
         allowAddr[_addr] = _set;
    }
    function lock(address _user,uint256 _svtAmount) external {
        require(allowAddr[msg.sender]);
            LockInfo memory _lockInfo = LockInfo({
            user:_user,
            amount:_svtAmount,
            lockBlock:block.number,
            startTime:block.timestamp
        });
        userLockInfos[msg.sender].push(_lockInfo);

    }
        function getUserCanClaim(address _user) public view returns(uint256) {
        uint256 total = 0;
        for(uint256 i = 0 ; i<getUserLockLength(_user);i++){
            total = total.add(userLockInfos[_user][i].amount.mul(block.number.sub(userLockInfos[_user][i].lockBlock)).div(oneYear));
        }
        return total;
    }
    function Claim(uint256 amount) public  {
        require(getUserCanClaim(msg.sender) >= amount && getContractSbdBalance() >= amount);
        uint256 totalTransfer = 0;
        for(uint256 i = 0 ; i<getUserLockLength(msg.sender);i++){
            if(userLockInfos[msg.sender][i].amount == 0 ){
                continue;
            }
            uint256 claimAmount =  userLockInfos[msg.sender][i].amount.mul(block.number.sub(userLockInfos[msg.sender][i].lockBlock)).div(oneYear);
            totalTransfer = totalTransfer.add(claimAmount);
             userLockInfos[msg.sender][i].amount = userLockInfos[msg.sender][i].amount.sub(claimAmount);
            userLockInfos[msg.sender][i].lockBlock = block.number;
         
        }
         if(totalTransfer >= amount){
                sbd.transfer(msg.sender, amount);
                ISVT(svt).burn(msg.sender,amount);
        }else{
            revert();
        }
    }
    function getContractSbdBalance() public view returns(uint256) {
        return sbd.balanceOf(address(this));
    }
    function getUserLockLength(address _user) public view returns(uint256) {
        return userLockInfos[_user].length;
    } 
}