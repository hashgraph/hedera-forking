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

const path = require('path');
const { spawn } = require('child_process');
const { Worker } = require('worker_threads');
const ethers = require('ethers');

const IERC20 = require('../../out/IERC20.sol/IERC20.json');

/**
 * @returns {Promise<string>}
 */
function jsonRpcMock() {
    return new Promise(resolve => {
        const scriptPath = path.resolve(__dirname, '../scripts/json-rpc-mock');
        const worker = new Worker(scriptPath);
        worker.on('error', err => console.log(err));
        worker.on('exit', code => console.log(`JSON-RPC Mock Worker exited with code ${code}`));
        worker.on('message', message => {
            if (message.listening) {
                resolve(`localhost:${message.port}`);
            }
        });
        worker.unref();
    });
}

/**
 *
 * @param {*} forkUrl
 * @returns {Promise<string>}
 */
function anvil(forkUrl = 'localhost:7546') {
    const args = ['--port=0', `--fork-url=${forkUrl}`, '--no-storage-caching'];
    return new Promise((resolve, reject) => {
        const child = spawn('anvil', args, {
            detached: true,
            stdio: ['ignore', 'pipe', 'pipe'],
        });
        child.stdout.on('data', data => {
            /** @type {string} */
            const message = data.toString();
            const match = message.match(/^Listening on (.+:\d+)$/m);
            if (match !== null) {
                const host = match[1];
                child.stderr.unpipe();
                child.stderr.destroy();
                child.stdout.unpipe();
                child.stdout.destroy();
                resolve(host);
            }
        });
        child.stderr.on('data', err => {
            reject(err.toString());
        });

        process.on('exit', () => {
            const result = child.kill();
            console.log('terminated', result);
        });

        child.unref();
    });
}

describe.skip('::anvil', function () {
    /**@type {ethers.JsonRpcProvider} */
    let mockProvider;

    /**@type {ethers.JsonRpcProvider} */
    let anvilProvider;

    before(async function () {
        const mockHost = await jsonRpcMock();
        const anvilHost = await anvil(mockHost);
        console.log('Anvil listening on', anvilHost);

        // Disable batch requests because `json-rpc-mock` does not support them
        mockProvider = new ethers.JsonRpcProvider(`http://${mockHost}`, undefined, {
            batchMaxCount: 1,
        });
        anvilProvider = new ethers.JsonRpcProvider(`http://${anvilHost}`);

        const n = await anvilProvider.getNetwork();
        console.log(n.chainId);
    });

    it('Assigns initial balance', async function () {
        const usdc = new ethers.Contract(
            '0x0000000000000000000000000000000000068cDa',
            IERC20.abi,
            anvilProvider
        );
        const name = await usdc['name']();
        const symbol = await usdc['symbol']();
        const decimals = await usdc['decimals']();
        console.log(name, symbol, decimals);
        const a = await mockProvider.send('test_getMirrorNodeRequests', []);
        console.log(a);
    });
});
