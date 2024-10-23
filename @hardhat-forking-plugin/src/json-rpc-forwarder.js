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
const http = require('http');
const { workerData, parentPort } = require('worker_threads');
const debug = require('util').debuglog('hedera-forking-rpc');
const c = require('ansi-colors');

const { MirrorNodeClient } = require('./mirror-node-client');
const { getHtsCode, getHtsStorageAt } = require('../../@hts-forking/src');
const { HTSAddress } = require('../../@hts-forking/src/utils');

/** @type {import('hardhat/types').HardhatNetworkForkingConfig} */
const { url, blockNumber, mirrorNodeUrl, workerPort, hardhatAddresses = [] } = workerData;
assert(mirrorNodeUrl !== undefined);
const mirrorNodeClient = new MirrorNodeClient(mirrorNodeUrl, blockNumber);

debug(c.yellow('Starting JSON-RPC Relay Forwarder server on :%d, forking url=%s blockNumber=%d mirror node url=%s'), workerPort, url, blockNumber, mirrorNodeUrl);

/**
 * Function signature for `eth_*` method handlers.
 * The `params` argument comes from the JSON-RPC request,
 * so it must to be declared as `unknown[]`.
 * Therefore, each method handler should validate each element of `params` they use.
 * 
 * When this handler returns `null`
 * it means the original call needs to be **forwarded** to the remote JSON-RPC Relay.
 *
 * @typedef {(params: unknown[], requestIdPrefix: string) => Promise<unknown | null>} EthHandler
 */

/**
 * 
 */
const eth = {

    /** @type {EthHandler} */
    eth_getBalance: async ([address, _blockNumber]) => {
        assert(typeof address === 'string');
        if (hardhatAddresses.includes(address.toLowerCase())) {
            return '0x0';
        }
        return null;
    },

    /** @type {EthHandler} */
    eth_getCode: async ([address, _blockNumber]) => {
        assert(typeof address === 'string');
        if (hardhatAddresses.includes(address.toLowerCase())) {
            return '0x';
        }
        if (address === HTSAddress) {
            debug('loading HTS Code at addres %s', address);
            return getHtsCode();
        }
        return null;
    },

    /** @type {EthHandler} */
    eth_getStorageAt: async ([address, slot, _blockNumber], requestIdPrefix) => {
        assert(typeof address === 'string');
        assert(typeof slot === 'string');
        // @ts-ignore
        return await getHtsStorageAt(address, slot, mirrorNodeClient, { trace: debug }, requestIdPrefix);
    },
};

const server = http.createServer(function (req, res) {
    assert(req.url === '/', 'Only root / url is supported');
    assert(req.method === 'POST', 'Only POST allowed');

    // https://nodejs.org/en/learn/modules/anatomy-of-an-http-transaction
    /** @type {Uint8Array[]} */
    const chunks = [];
    req.on('data', chunk => {
        chunks.push(chunk);
    }).on('end', async () => {
        const body = Buffer.concat(chunks).toString();
        const { jsonrpc, id, method, params } = JSON.parse(body);
        assert(jsonrpc === '2.0', 'Only JSON-RPC 2.0 allowed');

        const response = await async function () {
            const handler = eth[/**@type{keyof typeof eth}*/(method)];
            if (handler !== undefined) {
                const reqId = `[Request ID: ${id}]`;
                const result = await handler(params, reqId);
                if (result !== null) {
                    debug(c.dim('non-forwarded request'), c.dim(id), c.blue(method), params);
                    return JSON.stringify({ jsonrpc, id, result });
                }
            }
            debug('fetch request', c.dim(id), c.blue(method), params);
            const result = await fetch(url, { method: 'POST', body });

            if (method === 'eth_getBlockByNumber') {
                const json = await result.json();
                for (const tx of json.result.transactions) {
                    tx.accessList = [];
                }
                return JSON.stringify(json);
            }

            return await result.text();
        }();

        res.setHeader('Content-Type', 'application/json');
        res.writeHead(200);
        res.end(response);
        res.end('');
    });
});

server.listen(workerPort, () => {
    const address = server.address();
    assert(address !== null);
    assert(typeof address === 'object');

    parentPort?.postMessage({
        listening: true,
        ...address,
    });
    debug(`JSON-RPC Relay Forwarder server listening on port ${address.port}`);
});
