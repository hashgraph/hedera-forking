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
const fs = require('fs');
const sinon = require('sinon');
const { JsonRpcProvider } = require('ethers');
const hre = require('hardhat');

/**
 * @typedef {Object} MirrorNodeResponse
 * @property {string} url - The URL of the API endpoint.
 * @property {string} response - The JSON-encoded string of the response for the URL.
 */

/**
 * @type {MirrorNodeResponse[]}
 */
const responses = require('./data/mirrornodeStubResponses.json');
const tokenAddress = '0x000000000000000000000000000000000047b52a';
const accountAddress = '0x292c4acf9ec49af888d4051eb4a4dc53694d1380';
const spenderAddress = '0x000000000000000000000000000000000043f832';

describe('hedera-fork-project', function () {
    /** @type {import('sinon').SinonStub} */
    let fetchStub;

    /** @type {import('ethers').Contract} */
    let ft;

    before(async () => {
        const bytecode = fs.readFileSync(__dirname + '/data/HIP719.bytecode').toString();
        await hre.network.provider.send('hardhat_setCode', [tokenAddress, bytecode]);
    });

    beforeEach(async () => {
        ft = await hre.ethers.getContractAt('IERC20', tokenAddress);
        fetchStub = sinon.stub(global, 'fetch');
        for (let { url, response } of responses) {
            fetchStub.withArgs(url).resolves(new Response(response));
        }
    });

    afterEach(() => {
        fetchStub.restore();
    });

    it('should have loaded the JSON-RPC Forwarder', async function () {
        const forking = hre.userConfig.networks?.hardhat?.forking;

        assert(forking !== undefined);
        assert('workerPort' in forking);
        assert('chainId' in forking);
        assert(typeof forking.chainId === 'number');

        const provider = new JsonRpcProvider(`http://127.0.0.1:${forking.workerPort}`);
        const network = await provider.getNetwork();

        assert(network.chainId === BigInt(forking.chainId));
    });

    it('show decimals', async function () {
        assert(await ft['decimals']() === 13n);
    });

    it('get name', async function () {
        assert(await ft['name']() === 'Very long string, just to make sure that it exceeds 31 bytes and requires more than 1 storage slot.');
    });

    it('get symbol', async function () {
        assert(await ft['symbol']() === 'SHRT');
    });

    it('get balance', async function () {
        assert(await ft['balanceOf'](accountAddress) === 9995n);
    });

    it('get allowance', async function () {
        assert(await ft['allowance'](accountAddress, spenderAddress) === 0n);
    });

    it('should get correct value when non-HTS address is called', async function () {
        const contract = await hre.ethers.deployContract('One');
        const result = await contract['getOne']();
        assert(result === 1n);
    });
});
