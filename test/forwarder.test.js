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

const { expect } = require('chai');
const { HTSAddress } = require('@hashgraph/system-contracts-forking');

const { jsonRPCForwarder } = require('../src/forwarder');

class Provider {
    /**
     * @param {string} host
     */
    constructor(host) {
        this.host = host;
        this.id = 1;
    }

    /**
     * @param {string} method
     * @param {unknown[]} params
     */
    async request(method, params) {
        const id = this.id++;
        const body = { jsonrpc: '2.0', id, method, params };
        const response = await fetch(this.host, {
            method: 'POST',
            body: JSON.stringify(body),
        });
        const { jsonrpc, id: respId, result } = await response.json();

        expect(jsonrpc).to.be.equal('2.0');
        expect(respId).to.be.equal(id);
        return result;
    }
}

describe('::forwarder', function () {
    /** @type {Provider} */
    let provider;

    before(async function () {
        const forkUrl = /**@type{string}*/ (/**@type{unknown}*/ (undefined));
        const { host } = await jsonRPCForwarder(forkUrl, '', undefined, [
            '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        ]);
        provider = new Provider(host);
    });

    it('should return code for HTS emulation', async function () {
        const result = await provider.request('eth_getCode', [HTSAddress]);
        expect(result).to.have.length.greaterThan(4);
        expect(result.startsWith('0x')).to.be.true;
    });

    it('should return empty code for any Hardhat address', async function () {
        const result = await provider.request('eth_getCode', [
            '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        ]);
        expect(result).to.be.equal('0x');
    });

    it('should return no native token balance for any Hardhat address', async function () {
        const result = await provider.request('eth_getBalance', [
            '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        ]);
        expect(result).to.be.equal('0x0');
    });
});