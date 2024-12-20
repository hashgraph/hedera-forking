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

require('@hashgraph/system-contracts-forking/plugin');

module.exports = {
    /**
     * Shared config for Hardhat test projects.
     *
     * @type import('hardhat/config').HardhatUserConfig
     */
    projectTestConfig: {
        mocha: {
            timeout: 30000,
        },
        solidity: '0.8.9',
        paths: {
            tests: '.',
            sources: '.',
        },
    },
};
