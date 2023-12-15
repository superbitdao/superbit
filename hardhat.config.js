
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity:{
    compilers:[
      {version:"0.6.12",},
      {version: "0.8.18"}
    ]
  },
  networks: {
    bscTest: {
      chainId: 56,
      url: `https://bsc.blockpi.network/v1/rpc/public`,

    },
    
  },
};
