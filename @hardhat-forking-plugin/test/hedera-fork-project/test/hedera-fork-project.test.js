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
const fs = require('fs');
const sinon = require('sinon');
const { getProviderExtensions } = require('../../.lib');

const responses = require('./data/mirrornodeStubResponses.json');
const tokenAddress = '0x000000000000000000000000000000000047b52a';
const accountAddress = '0x292c4acf9ec49af888d4051eb4a4dc53694d1380';
const spenderAddress = '0x000000000000000000000000000000000043f832';

describe('hedera-fork-project', function () {
    /** @type {import('sinon').SinonStub} */
    let fetchStub;

    /** @type {import('ethers').Contract} */
    let ft;

    beforeEach(async () => {
        ft = await hre.ethers.getContractAt('IERC20', tokenAddress);
    });

    before(async () => {
        const bytecode = fs.readFileSync(__dirname + '/data/HIP719.bytecode').toString();
        await hre.network.provider.send('hardhat_setCode', [tokenAddress, bytecode]);
        fetchStub = sinon.stub(global, 'fetch');
        for (let url of Object.keys(responses)) {
            fetchStub.withArgs(url).resolves(new Response(JSON.stringify(responses[url])));
        }
    });

    after(() => {
        fetchStub.restore();
    });

    it('should have `HederaProvider` as a loaded extension', async function () {
        const extensions = getProviderExtensions(hre.network.provider).map(p => p.constructor.name);
        expect(extensions).to.include('HederaProvider');
    });

    it('should have `HederaProvider` set to fetch token data from testnet Mirror Node', async function () {
        const [provider] = getProviderExtensions(hre.network.provider)
            .filter(p => p.constructor.name === 'HederaProvider');
        expect(/**@type{import('../../../src/hedera-provider').HederaProvider}*/(provider).mirrorNode.url)
            .to.be.equal('https://testnet.mirrornode.hedera.com/api/v1/');
    });

    it('add sample transaction to the forked network', async function () {
        expect(await hre.network.provider.send('hardhat_mine', ['0x001'])).to.be.true;
    });

    it('show decimals', async function () {
        expect(await ft['decimals']()).to.be.equal(13n);
    });

    it('get name', async function () {
        expect(await ft['name']()).to.be.equal('Very long string, just to make sure that it exceeds 31 bytes and requires more than 1 storage slot.');
    });

    it('get symbol', async function () {
        expect(await ft['symbol']()).to.be.equal('SHRT');
    });

    it('get balance', async function () {
        expect(await ft['balanceOf'](accountAddress)).to.be.equal(9995n);
    });

    it('get allowance', async function () {
        expect(await ft['allowance'](accountAddress, spenderAddress)).to.be.equal(0n);
    });
});
