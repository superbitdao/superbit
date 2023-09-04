// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISVT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract Lock  is Ownable{

    IERC20 sbd;
    address public svt;
    mapping (address => bool) public allowAddr;

    constructor(IERC20 _sbd, address _svt){
        sbd = _sbd;
        svt = _svt;
    }

    function setAllowAddr(address _addr, bool _set) public onlyOwner {
        allowAddr[_addr] = _set;
    }
    function withdraw(uint256 _amount) public {

        sbd.transfer(msg.sender, _amount);
        ISVT(svt)._burnExternal(msg.sender, _amount);
    }
    
}
