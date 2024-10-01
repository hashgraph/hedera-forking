/*-
 *
 * Hedera Hardhat Plugin Example Project
 *
 * Copyright (C) 2024 Hedera Hashgraph, LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

require("@nomicfoundation/hardhat-toolbox-viem");
require("@nomicfoundation/hardhat-chai-matchers");
require("@hashgraph/hardhat-forking-plugin");
const { task } = require("hardhat/config");

// Import dotenv module to access variables stored in the .env file
require("dotenv").config();

/** @type import('@hashgraph/hardhat-forking-plugin').HeaderaHardhatConfig */
module.exports = {
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
      url: process.env.LOCAL_RPC_URL,
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
