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
    }
    uint256[] public reward;
    uint256[] public rewardTime;
    uint256[] public startRewardTime;

    uint public intervalTime = 5;
    uint256 public blockTime;
    address public srt;
    address public supNft;
    address public bigNft;
    address public smallNft;
    uint256 public totalPower;
    uint256 public SupNftAmount;
    uint256 public BigNftAmount;

    uint256 public SmallNftAmount;
    mapping(address => uint256) public  userSupNftAmount;
    mapping(address => uint256) public userBigNftAmount;
    mapping(address =>uint256) public userSmallNftAmount;
    mapping(address => uint256[] ) public lastRewardBlock;
    mapping(address => uint256 ) public accSrtPerShare;
    mapping(address => uint256 ) public userPower;
    mapping(address => uint256 ) public rewardDebt;
    mapping(address => uint256 ) public nftPower;
    mapping(address => lockInfo[]) public userLockInfos;
    mapping(address => uint256 ) public userTotalLock;
    event lockRecord(address user, string  nft, uint256 tokenId, uint256 power);
    event unLockRecord(address user, string nft, uint256 tokenId, uint256 power);
    event claimSrtRecord(address user, uint256 amount);
    constructor(address _srt,address _supNft, address _bigNft, address _smallNft) {
        nftPower[_supNft] = 10;
        nftPower[_bigNft] = 3;
        nftPower[_smallNft] = 1;
        srt = _srt;
        supNft = _supNft;
        bigNft = _bigNft;
        smallNft = _smallNft;
    }
    function setSrt(address _srt) public onlyOwner {
        srt = _srt;
    }
    function setPower(address _node, uint256 _power) public onlyOwner{
        nftPower[_node] = _power;
    }
    function deposit(uint256 _amount,uint256 _rewardTime) public onlyOwner {
        IERC20(srt).transferFrom (msg.sender,address(this),_amount);
        reward .push(_amount);
        rewardTime.push(_rewardTime);
        startRewardTime.push(block.timestamp);
    }
    function backToken(address _token, uint256 _amount) public onlyOwner{
        IERC20(_token).transfer(msg.sender, _amount);
    }
    function getRewardLength() public view returns(uint256 ){
        return reward.length;
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
        if(totalPower == 0){
            lastRewardBlock[msg.sender][i] = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(lastRewardBlock[msg.sender][i], block.number, i);
        uint256 srtReward = multiplier.mul(getOneBlockReward(i));
        accSrtPerShare[msg.sender] = accSrtPerShare[msg.sender].add(srtReward.div(totalPower));
        lastRewardBlock[msg.sender][i] = block.number;
        }

    }
    function lockNft(uint256 _nft,uint256 _tokenId) public nonReentrant{
        require(_nft<= 3 ,'input error');
    
        updatePower();
        if(userPower[msg.sender] > 0 ){
            uint256 pending = userPower[msg.sender].mul(accSrtPerShare[msg.sender]).sub(rewardDebt[msg.sender]);
            safeSrtTransfer(msg.sender, pending);
        }
        rewardDebt[msg.sender] = userPower[msg.sender].mul(accSrtPerShare[msg.sender]);
        if(_nft == 1) {
            require(IERC721(smallNft).balanceOf(msg.sender) != 0,"You do not have a small node NFT");
            IERC721(smallNft).transferFrom(msg.sender, address(this),_tokenId);
            lockInfo memory _info = lockInfo({
                user: msg.sender,
                nft:smallNft,
                power: nftPower[smallNft],
                startTimeBlock:block.number
            });
            userLockInfos[msg.sender].push(_info);
            userPower[msg.sender] = userPower[msg.sender].add(nftPower[smallNft]);
            userSmallNftAmount[msg.sender] = userSmallNftAmount[msg.sender].add(1);
            SmallNftAmount = SmallNftAmount.add(1);
            totalPower = totalPower.add(nftPower[smallNft]);
            emit lockRecord(msg.sender, "SMALL_Node_NFT",_tokenId, nftPower[smallNft]);
        }else if(_nft == 2) {
            require(IERC721(bigNft).balanceOf(msg.sender) != 0,"You do not have a small node NFT");
            IERC721(bigNft).transferFrom(msg.sender, address(this),_tokenId);
            lockInfo memory _info = lockInfo({
                user: msg.sender,
                nft : bigNft,
                power: nftPower[bigNft],
                startTimeBlock:block.number
            });
            userLockInfos[msg.sender].push(_info);
            userPower[msg.sender] = userPower[msg.sender].add(nftPower[bigNft]);
            userBigNftAmount[msg.sender] = userBigNftAmount[msg.sender].add(1);
            BigNftAmount = BigNftAmount.add(1);
            totalPower = totalPower.add(nftPower[bigNft]);
            emit lockRecord(msg.sender, "BIG_NODE_NFT",_tokenId, nftPower[bigNft]);

        }else if(_nft ==3){
            require(IERC721(supNft).balanceOf(msg.sender) != 0,"You do not have a small node NFT");
            IERC721(supNft).transferFrom(msg.sender, address(this),_tokenId);
            lockInfo memory _info = lockInfo({
                user: msg.sender,
                nft:supNft,
                power: nftPower[supNft],
                startTimeBlock:block.number
            });
            userLockInfos[msg.sender].push(_info);
            totalPower = totalPower.add(nftPower[supNft]);
            userSupNftAmount[msg.sender] = userSupNftAmount[msg.sender].add(1);
            userPower[msg.sender] = userPower[msg.sender].add(nftPower[supNft]);
            SupNftAmount = SupNftAmount.add(1);
            emit lockRecord(msg.sender, "SUP_NODE_NFT",_tokenId, nftPower[supNft]);


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
 
    function pendingSrt(address _user) external view returns (uint256) {
        uint256 total = 0;
        uint256 accSrtPerShareE = accSrtPerShare[_user];
        for(uint256 i = 0 ; i <lastRewardBlock[_user].length;i++ ){
        uint256 powerSupply = totalPower;
        if (block.number > lastRewardBlock[_user][i] && powerSupply != 0) {
            uint256 multiplier = getMultiplier(lastRewardBlock[_user][i], block.number,i);
            uint256 srtReward = multiplier.mul(getOneBlockReward(i));
            accSrtPerShareE = accSrtPerShare[_user].add(srtReward.div(powerSupply));
            total = total.add(userPower[_user].mul(accSrtPerShare[_user]).sub(rewardDebt[_user]));
        }
        }
       
        return total;
    }
    function ClaimSrt() public nonReentrant {
          updatePower();
            uint256 pending = userPower[msg.sender].mul(accSrtPerShare[msg.sender]).sub(rewardDebt[msg.sender]);
            safeSrtTransfer(msg.sender, pending);
            rewardDebt[msg.sender] = userPower[msg.sender].mul(accSrtPerShare[msg.sender]);
        emit claimSrtRecord(msg.sender, pending);
    }
    function withdrawNft(uint256 _nftClass , uint256 _tokenId ) public  nonReentrant{
        updatePower();
            uint256 pending = userPower[msg.sender].mul(accSrtPerShare[msg.sender]).sub(rewardDebt[msg.sender]);
            safeSrtTransfer(msg.sender, pending);
            rewardDebt[msg.sender] = userPower[msg.sender].mul(accSrtPerShare[msg.sender]);

        if(_nftClass == 1){
            require(IERC721(smallNft).balanceOf(address(this)) != 0 ," do not have a small node NFT");
            for(uint256 i =0 ; i < userLockInfos[msg.sender].length; i++){
                require(userLockInfos[msg.sender][i].user == msg.sender&& smallNft == userLockInfos[msg.sender][i].nft);
            } 
            IERC721(smallNft).safeTransferFrom(address(this),msg.sender,_tokenId);
            totalPower = totalPower.sub(nftPower[smallNft]);
            userPower[msg.sender] = userPower[msg.sender].sub(nftPower[smallNft]);
            userSmallNftAmount[msg.sender] = userSmallNftAmount[msg.sender].sub(1);
            SmallNftAmount=SmallNftAmount.sub(1);
            emit unLockRecord(msg.sender, "SMALL_NODE_NFT",_tokenId, nftPower[smallNft]);
        }else if(_nftClass == 2) {
     require(IERC721(bigNft).balanceOf(address(this)) != 0 ," do not have a big node NFT");
            for(uint256 i =0 ; i< userLockInfos[msg.sender].length; i++){
                require(userLockInfos[msg.sender][i].user == msg.sender && bigNft == userLockInfos[msg.sender][i].nft);
            }
            IERC721(bigNft).safeTransferFrom(address(this),msg.sender,_tokenId);
            totalPower = totalPower.sub(nftPower[bigNft]);
            userPower[msg.sender] = userPower[msg.sender].sub(nftPower[bigNft]);
            userBigNftAmount[msg.sender] = userBigNftAmount[msg.sender].sub(1);
            BigNftAmount = BigNftAmount.sub(1);
            emit unLockRecord(msg.sender, "BIG_NODE_NFT",_tokenId, nftPower[bigNft]);

        }else if(_nftClass == 3){ 
     require(IERC721(supNft).balanceOf(address(this)) != 0 ," do not have a sup node NFT");
            for(uint256 i =0 ; i< userLockInfos[msg.sender].length; i++){
                require(userLockInfos[msg.sender][i].user == msg.sender && supNft == userLockInfos[msg.sender][i].nft);
            }
            IERC721(supNft).safeTransferFrom(address(this),msg.sender,_tokenId);
            totalPower = totalPower.sub(nftPower[supNft]);
            userPower[msg.sender] = userPower[msg.sender].sub(nftPower[supNft]);
            userSupNftAmount[msg.sender] = userSupNftAmount[msg.sender].sub(1);
            SupNftAmount = SupNftAmount.sub(1);
            emit unLockRecord(msg.sender, "SUP_NODE_NFT",_tokenId, nftPower[supNft]);

        }
    }
    function safeSrtTransfer(address _to, uint256 _amount) internal {
        uint256 srtBal = IERC20(srt).balanceOf(address(this));
          if (_amount > srtBal) {
            IERC20(srt).transfer(_to, srtBal);
        } else {
            IERC20(srt).transfer(_to, _amount);
        }
    }
    function getContractSrtBalance() public view returns(uint256) {
        return IERC20(srt).balanceOf(address(this));
    }
}