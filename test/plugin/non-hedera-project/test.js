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

const hre = require('hardhat');
const { expect } = require('chai');

describe('non-hedera-project', function () {
    it('should leave `forking` config untouched', async function () {
        expect(hre.config.networks.hardhat.forking).to.be.undefined;
    });

    it('should not activate JSON-RPC Forwarder', async function () {
        expect(hre.jsonRPCForwarder).to.be.undefined;
    });

    it('should load Hedera hardfork history even on non-Hedera projects', async function () {
        const { chains } = /** @type{import('hardhat/types').HardhatNetworkConfig} */ (
            hre.network.config
        );
        expect(chains.get(295)).to.be.deep.equal({
            hardforkHistory: new Map().set('shanghai', 0),
        });
        expect(chains.get(296)).to.be.deep.equal({
            hardforkHistory: new Map().set('shanghai', 0),
        });
        expect(chains.get(297)).to.be.deep.equal({
            hardforkHistory: new Map().set('shanghai', 0),
        });
    });
});
