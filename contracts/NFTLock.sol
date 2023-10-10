//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
contract NFTLock is Ownable,ReentrancyGuard{ 
    using SafeMath for uint256;
    struct lockInfo{
        address user;
        address nft;
        uint256 power;
        uint256 startTimeBlock;
        uint256 lockTimeBlock;
    }
    uint256[] public reward;
    uint256[] public rewardTime;
    uint256[] public startRewardTime;
    uint public intervalTime = 5;
    uint256 public MONTH = 2592000;
    uint256 public blockTime;
    address public srt;
    address public supNft;
    address public bigNft;
    address public smallNft;
    uint256 public totalPower;
    mapping(address  => uint256 ) public power;
    mapping(address => lockInfo[]) public userLockInfos;
    mapping(address => uint256 ) public userTotalLock;
    
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
        reward .push(_amount) ;
        rewardTime.push(_rewardTime) ;
        startRewardTime.push(block.number);
    }
    function lockNft(uint256 _nft,uint256 _tokenId,uint256 _lockTime) public nonReentrant{
        require(_nft<= 3 ,'input error');
        require(
            _lockTime == 0||
            _lockTime == MONTH ||
            _lockTime == MONTH.mul(3) ||
            _lockTime == MONTH.mul(6) ||
            _lockTime == MONTH.mul(9) ||
            _lockTime == MONTH.mul(12) ||
            _lockTime == MONTH.mul(15) ||
            _lockTime == MONTH.mul(18) ||
            _lockTime == MONTH.mul(24) 
                            );
        uint256 _lockTimeBlock = _lockTime.div(intervalTime);
        if(_nft == 1) {
            require(IERC721(smallNft).balanceOf(msg.sender) != 0,"You do not have a small node NFT");
            IERC721(smallNft).transferFrom(msg.sender, address(this),_tokenId);
            lockInfo memory _info = lockInfo({
                user: msg.sender,
                nft:smallNft,
                power: power[smallNft],
                startTimeBlock:block.number,
                lockTimeBlock:_lockTimeBlock
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
                startTimeBlock:block.number,
                lockTimeBlock:_lockTimeBlock
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
                startTimeBlock:block.number,
                lockTimeBlock:_lockTimeBlock
            });
            userLockInfos[msg.sender].push(_info);
            totalPower = totalPower.add(power[supNft]);


        }else {
            revert("input error");
        }
        userTotalLock[msg.sender] = userTotalLock[msg.sender].add(1);

    }
    function getUserLockInfosLength(address _user) public view returns(uint256 ){
        return userLockInfos[_user].length;
    }
    function getOneBlockReward(uint256 _rewardId) public view returns(uint256) {
        return reward[_rewardId].div(rewardTime[_rewardId].div(intervalTime));
    }
    function getUserCanClaim(address _user) public view returns(uint256){
        uint256 total = 0;
        
        for(uint256 i =0 ; i< userLockInfos[_user].length ;i++){
            if(userLockInfos[_user][i].lockTimeBlock == block.number ){
                continue;
            }
            for(uint256 j = 0 ; j <rewardTime.length ;j++ ){
                if(userLockInfos[_user][i].startTimeBlock <= rewardTime[j]){
                continue;

                }
            total = total.add((block.number.sub(userLockInfos[_user][i].startTimeBlock)).mul(getOneBlockReward(j)));

            }
        }
        return total;
    }
    function ClaimSrt(uint256 _amount) public nonReentrant {
        require(getUserCanClaim(msg.sender) >= _amount && getContractSrtBalance()>= _amount);
        uint256 total = 0;
        address _user = msg.sender;
        uint256 buffer = 0;
        for(uint256 i = 0 ; i < userLockInfos[msg.sender].length ;i ++){
              if(userLockInfos[msg.sender][i].lockTimeBlock == block.number){
                continue;
            }
            for(uint256 j = 0; j < rewardTime.length; j++){
            total = total.add(1);

            }
            userLockInfos[msg.sender][i].startTimeBlock = block.number;

            if(total >= _amount) {
                buffer = total.sub(_amount);

        IERC20(srt).transfer(msg.sender, _amount);
        break;
        }
        }
      
    }
    function withdrawNft(uint256 _nftClass , uint256 _tokenId ) public  nonReentrant{
        if(_nftClass == 1){
            require(IERC721(smallNft).balanceOf(address(this)) != 0 ," do not have a small node NFT");
            for(uint256 i =0 ; i < userLockInfos[msg.sender].length; i++){
                require(userLockInfos[msg.sender][i].user == msg.sender&& smallNft == userLockInfos[msg.sender][i].nft);
            } 
            IERC721(smallNft).safeTransferFrom(address(this),msg.sender,_tokenId);
            totalPower = totalPower.sub(power[smallNft]);

        }else if(_nftClass == 2) {
     require(IERC721(bigNft).balanceOf(address(this)) != 0 ," do not have a big node NFT");
            for(uint256 i =0 ; i< userLockInfos[msg.sender].length; i++){
                require(userLockInfos[msg.sender][i].user == msg.sender && bigNft == userLockInfos[msg.sender][i].nft);
            }
            IERC721(bigNft).safeTransferFrom(address(this),msg.sender,_tokenId);
            totalPower = totalPower.sub(power[bigNft]);

        }else if(_nftClass == 3){ 
     require(IERC721(supNft).balanceOf(address(this)) != 0 ," do not have a sup node NFT");
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