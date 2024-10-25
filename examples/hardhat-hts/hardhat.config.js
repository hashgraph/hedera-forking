/*-
 * Hedera Hardhat Forking Plugin
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
 */

require('@nomicfoundation/hardhat-toolbox');
require('@hashgraph/hardhat-forking-plugin');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: '0.8.27',
  networks: {
    hardhat: {
      forking: {
        url: 'https://mainnet.hashio.io/api',
        // This allows Hardhat to enable JSON-RPC's response cache.
        // Forking from a block is not fully integrated yet into HTS emulation.
        blockNumber: 70531900,
        chainId: 295,
        workerPort: 1235,
      },
    },
  },
};
