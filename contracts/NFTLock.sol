//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
contract NFTLock is Ownable{ 
    using SafeMath for uint256;
    struct lockInfo{
        address user;
        address nft;
        uint256 power;
        uint256 startTime;
        uint256 lockTime;
        uint256 startTimeBlock;
        uint256 lockTimeBlock;
    }
    uint256 public reward;
    uint256 public rewardTime;
    uint256 public blockTime;
    address public srt;
    address public supNft;
    address public bigNft;
    address public smallNft;
    uint256 public totalPower;
    mapping(address  => uint256 ) public power;
    mapping(address => lockInfo[]) public userLockInfos;
    
    constructor(address _srt,address _supNft, address _bigNft, address _smallNft) {
        power[_supNft] = 10;
        power[_bigNft] = 3;
        power[_smallNft] = 1;
        srt = _srt;
        supNft = _supNft;
        bigNft = _bigNft;
        smallNft = _smallNft;
    }
    function setSrt(address _srt) public onlyOwner {
        srt = _srt;
    }
    function setPower(address _node, uint256 _power) public onlyOwner{
        power[_node] = _power;
    }
    function deposit(uint256 _amount,uint256 _rewardTime) public onlyOwner {
        IERC20(srt).transferFrom (msg.sender,address(this),_amount);
        reward = _amount;
        rewardTime = _rewardTime;
    }
    function lockNft(uint256 _nft,uint256 _tokenId,uint256 _lockTime) public {
        uint256 lockTimeBlock = _lockTime.div(45).div(10);
        if(_nft == 1) {
            require(IERC721(smallNft).balanceOf(msg.sender) != 0,"You do not have a small node NFT");
            IERC721(smallNft).transferFrom(msg.sender, address(this),_tokenId);
            lockInfo memory _info = lockInfo({
                user: msg.sender,
                nft:smallNft,
                power: power[smallNft],
                startTime: block.timestamp,
                lockTime:_lockTime,
                startTimeBlock:block.number,
                lockTimeBlock:lockTimeBlock
            });
            userLockInfos[msg.sender].push(_info);
            totalPower = totalPower.add(power[smallNft]);
        }else if(_nft == 2) {
            require(IERC721(bigNft).balanceOf(msg.sender) != 0,"You do not have a small node NFT");
            IERC721(bigNft).transferFrom(msg.sender, address(this),_tokenId);
               lockInfo memory _info = lockInfo({
                user: msg.sender,
                nft : bigNft,
                power: power[bigNft],
                startTime: block.timestamp,
                lockTime:_lockTime,
                startTimeBlock:block.number,
                lockTimeBlock:lockTimeBlock
            });
            userLockInfos[msg.sender].push(_info);
            totalPower = totalPower.add(power[bigNft]);

        }else if(_nft ==3){
            require(IERC721(supNft).balanceOf(msg.sender) != 0,"You do not have a small node NFT");
            IERC721(supNft).transferFrom(msg.sender, address(this),_tokenId);
               lockInfo memory _info = lockInfo({
                user: msg.sender,
                nft:supNft,
                power: power[supNft],
                startTime: block.timestamp,
                lockTime:_lockTime,
                startTimeBlock:block.number,
                lockTimeBlock:lockTimeBlock
            });
            userLockInfos[msg.sender].push(_info);
            totalPower = totalPower.add(power[supNft]);

        }else {
            revert("input error");
        }
    }
    function getUserLockInfosLength(address _user) public view returns(uint256 ){
        return userLockInfos[_user].length;
    }
    function getOneBlockReward() public view returns(uint256) {
        return reward.div(rewardTime.mul(45).div(10));
    }
    function getUserCanClaim(address _user) public view returns(uint256){
        uint256 total = 0;
        for(uint256 i =0 ; i< userLockInfos[_user].length ;i++){
            if(userLockInfos[_user][i].lockTimeBlock == block.number){
                continue;
            }
            total = total.add(getOneBlockReward().mul(block.number.sub(userLockInfos[msg.sender][i].startTimeBlock)).mul(userLockInfos[msg.sender][i].power.div(totalPower)));
        }
        return total;
    }
    function ClaimSrt(uint256 _amount) public {
        require(getUserCanClaim(msg.sender) >= _amount && getContractSrtBalance()>= _amount);
        uint256 total = 0;
        for(uint256 i = 0 ; i < userLockInfos[msg.sender].length ;i ++){
              if(userLockInfos[msg.sender][i].lockTimeBlock == block.number){
                continue;
            }
            total = total.add(getOneBlockReward().mul(block.number.sub(userLockInfos[msg.sender][i].startTimeBlock)).mul(userLockInfos[msg.sender][i].power));
            userLockInfos[msg.sender][i].startTimeBlock = block.number;
        }
        
        IERC20(srt).transfer(msg.sender, _amount);
    }
    function ClaimNft(uint256 _nftClass , uint256 _tokenId ) public {
        if(_nftClass == 1){
            require(IERC721(smallNft).balanceOf(address(this)) != 0 ," do not have a small node NFT");
            for(uint256 i =0 ; i< userLockInfos[msg.sender].length; i++){
                require(userLockInfos[msg.sender][i].user == msg.sender&& smallNft == userLockInfos[msg.sender][i].nft);
            } 
            IERC721(smallNft).safeTransferFrom(address(this),msg.sender,_tokenId);
            totalPower = totalPower.sub(power[smallNft]);


        }else if(_nftClass == 2) {
     require(IERC721(bigNft).balanceOf(address(this)) != 0 ," do not have a small node NFT");
            for(uint256 i =0 ; i< userLockInfos[msg.sender].length; i++){
                require(userLockInfos[msg.sender][i].user == msg.sender && bigNft == userLockInfos[msg.sender][i].nft);
            }
            IERC721(bigNft).safeTransferFrom(address(this),msg.sender,_tokenId);
            totalPower = totalPower.sub(power[bigNft]);

        }else if(_nftClass == 3){ 
     require(IERC721(supNft).balanceOf(address(this)) != 0 ," do not have a small node NFT");
            for(uint256 i =0 ; i< userLockInfos[msg.sender].length; i++){
                require(userLockInfos[msg.sender][i].user == msg.sender && supNft == userLockInfos[msg.sender][i].nft);
            }
            IERC721(supNft).safeTransferFrom(address(this),msg.sender,_tokenId);
            totalPower = totalPower.sub(power[supNft]);

        }
    }
    
    function getContractSrtBalance() public view returns(uint256) {
        return IERC20(srt).balanceOf(address(this));
    }
}