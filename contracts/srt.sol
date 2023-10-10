pragma solidity =0.8.18;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract srt is ERC20{
    constructor()ERC20("SRT","SRT"){
        _mint(msg.sender, 1000000000000*10**18);
    }
}