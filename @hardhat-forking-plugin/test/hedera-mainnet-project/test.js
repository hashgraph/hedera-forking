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

const { strict: assert } = require('assert');
const { expect } = require('chai');
const { JsonRpcProvider } = require('ethers');
const hre = require('hardhat');

describe('hedera-mainnet-project', function () {
    it('should configure `forking` with mainnet values', async function () {
        const { forking } = hre.config.networks.hardhat;
        expect(forking?.chainId).to.be.equal(295);
        expect(forking?.mirrorNodeUrl).to.be.equal(
            'https://mainnet-public.mirrornode.hedera.com/api/v1/'
        );
        expect(forking?.workerPort).to.be.equal(1236);
    });

    it('should have loaded the JSON-RPC Forwarder', async function () {
        // This is needed to ensure JSON-RPC Forwarder is listening
        await hre.jsonRPCForwarder;
        const { forking } = hre.config.networks.hardhat;

        assert(forking !== undefined);
        assert(forking.workerPort !== undefined);
        assert(forking.chainId !== undefined);

        const provider = new JsonRpcProvider(`http://127.0.0.1:${forking.workerPort}`);
        const network = await provider.getNetwork();

        expect(network.chainId).to.be.equal(BigInt(forking.chainId));
    });
});
