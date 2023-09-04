pragma solidity ^0.8.0;

interface ISVT {
    function _mintExternal(address _to, uint256 _amount)external ;
    function _burnExternal(address _to, uint256 _amount) external;
}

