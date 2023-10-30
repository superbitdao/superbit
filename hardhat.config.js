
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
      chainId: 97,
      url: `https://bsc-testnet.blockpi.network/v1/rpc/public`,
      accounts: [`01eb2f1c5a85791109046cb239d24cd190abbca0fd9c3d2e92e4f1a351ccbe2e`],
    },
  },
};
