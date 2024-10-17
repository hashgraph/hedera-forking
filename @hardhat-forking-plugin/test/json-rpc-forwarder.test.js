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
const path = require('path');
const { Worker } = require('worker_threads');

describe('::json-rpc-forwarder', function () {

    it('should return code for HTS emulation', async function () {
        const scriptPath = path.resolve(__dirname, '..', 'src', './json-rpc-forwarder');
        const port = await (new Promise(resolve => new Worker(scriptPath, {
            workerData: {}
        }).on('message', message => {
            if (message.listening) {
                resolve(message.port);
            }
        }).unref()));

        const body = { jsonrpc: '2.0', id: 1, method: 'eth_getCode', params: ['0x0000000000000000000000000000000000000167'] }
        const response = await fetch(`http://127.0.0.1:${port}`, { method: 'POST', body: JSON.stringify(body) });
        const { jsonrpc, id, result } = await response.json();

        expect(jsonrpc).to.be.equal('2.0');
        expect(id).to.be.equal(1);
        expect(result).to.have.length.greaterThan(4);
        expect(result.startsWith('0x')).to.be.true;
    });

});
