require("@nomicfoundation/hardhat-toolbox-viem");
require("@nomicfoundation/hardhat-chai-matchers");
require("@hashgraph/hardhat-forking-plugin");
const { task } = require("hardhat/config");

// Import dotenv module to access variables stored in the .env file
require("dotenv").config();

task("show-balance", async (taskArgs) => {
  const showBalance = require("./scripts/showBalance");
  return showBalance(taskArgs.contractAddress, taskArgs.accountAddress);
});

task("show-name", async (taskArgs) => {
  const showName = require("./scripts/showName");
  return showName(taskArgs.contractAddress);
});

task("show-symbol", async (taskArgs) => {
  const showSymbol = require("./scripts/showSymbol");
  return showSymbol(taskArgs.contractAddress);
});

task("show-decimals", async (taskArgs) => {
  const showDecimals = require("./scripts/showDecimals");
  return showDecimals(taskArgs.contractAddress);
});

task("mine-block", async () => {
  const mineBlock = require("./scripts/mineBlock");
  return mineBlock();
});


task("show-allowance", async (taskArgs) => {
  const showAllowance = require("./scripts/showAllowance");
  return showAllowance(taskArgs.contractAddress, taskArgs.accountAddress, taskArgs.spenderAddress);
});

/** @type import('arianejasuwienas-hardhat-hedera').HeaderaHardhatConfig */
module.exports = {
  hedera: {
    mirrornode: 'https://testnet.mirrornode.hedera.com/api/v1/'
  },
  mocha: {
    timeout: 3600000
  },
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 500
      }
    }
  },
  // This specifies network configurations used when running Hardhat tasks
  defaultNetwork: "local",
  networks: {
    local: {
      // Your Hedera Local Node address pulled from the .env file
      url: process.env.LOCAL_NODE_ENDPOINT,
      // Conditionally assign accounts when private key value is present
      accounts: process.env.LOCAL_NODE_OPERATOR_PRIVATE_KEY ? [process.env.LOCAL_NODE_OPERATOR_PRIVATE_KEY] : []
    },
    testnet: {
      // HashIO testnet endpoint
      url: 'https://testnet.hashio.io/api',
      // Conditionally assign accounts when private key value is present
      accounts: process.env.TESTNET_OPERATOR_PRIVATE_KEY ? [process.env.TESTNET_OPERATOR_PRIVATE_KEY] : []
    },

    /**
     * Uncomment the following to add a mainnet network configuration
     */
    mainnet: {
      // HashIO mainnet endpoint
      url: 'https://mainnet.hashio.io/api',
      // Conditionally assign accounts when private key value is present
      accounts: process.env.MAINNET_OPERATOR_PRIVATE_KEY ? [process.env.MAINNET_OPERATOR_PRIVATE_KEY] : []
    },

    /**
     * Uncomment the following to add a previewnet network configuration
     */
    previewnet: {
      // HashIO previewnet endpoint
      url:'https://previewnet.hashio.io/api',
      // Conditionally assign accounts when private key value is present
      accounts: process.env.PREVIEWNET_OPERATOR_PRIVATE_KEY ? [process.env.PREVIEWNET_OPERATOR_PRIVATE_KEY] : []
    }
  }
};
