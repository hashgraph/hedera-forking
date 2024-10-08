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
 *
 */

require('@nomicfoundation/hardhat-ethers');
require('@hashgraph/hardhat-forking-plugin');
const { projectTestConfig } = require('../.lib');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    ...projectTestConfig,
    solidity: {
        version: '0.8.24',
        settings: {
            // Override compiler version to compile `Cancun.sol`
            // https://github.com/NomicFoundation/hardhat/issues/4851#issuecomment-1986148049
            evmVersion: 'cancun',
        }
    },
    networks: {
        hardhat: {
            forking: {
                url: 'https://testnet.hashio.io/api',
            },
            // Custom `hardforkHistory` config to test is not overwritten by the plugin.
            chains: {
                296: {
                    hardforkHistory: {
                        'london': 1,
                    }
                }
            }
        }
    }
};
