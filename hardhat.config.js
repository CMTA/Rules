/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-foundry");
module.exports = {
  solidity: "0.8.30",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200
    },
    evmVersion:"prague"
  }
};
