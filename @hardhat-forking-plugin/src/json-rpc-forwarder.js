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
const log = require('util').debuglog('hedera-forking-rpc');
const { workerData } = require('worker_threads');

const { MirrorNodeClient } = require('./mirror-node-client');
const { getHtsCode, getHtsStorageAt } = require('../..');
const { HTSAddress } = require('../../utils');

const { forkingUrl, mirrorNodeUrl, port } = workerData;
const mirrorNodeClient = new MirrorNodeClient(mirrorNodeUrl);

log('Creating JSON-RPC Relay Forwarder server on :%d, forking url=%s mirror node url=%s', port, forkingUrl, mirrorNodeUrl);

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
    eth_getCode: async ([address, _blockNumber]) => {
        if (address === HTSAddress) {
            log('loading HTS Code at addres %s', address);
            return getHtsCode();
        }
        return null;
    },

    /** @type {EthHandler} */
    eth_getStorageAt: async ([address, slot, _blockNumber], requestIdPrefix) => {
        assert(typeof address === 'string');
        assert(typeof slot === 'string');
        // @ts-ignore
        return await getHtsStorageAt(address, slot, mirrorNodeClient, { trace: log }, requestIdPrefix);
    },
};

const server = http.createServer(function (req, res) {
    assert(req.url === '/', 'Only root / url is supported');
    assert(req.method === 'POST', 'Only POST allowed');

    // https://nodejs.org/en/learn/modules/anatomy-of-an-http-transaction
    /** @type {Uint8Array[]} */
    let chunks = [];
    req.on('data', chunk => {
        chunks.push(chunk);
    }).on('end', async () => {
        const body = Buffer.concat(chunks).toString();
        const { jsonrpc, id, method, params } = JSON.parse(body);
        log('request', method, params);

        assert(jsonrpc === '2.0', 'Only JSON-RPC 2.0');

        const handler = eth[/**@type{keyof typeof eth}*/(method)];
        const response = await async function () {
            if (handler !== undefined) {
                const reqId = `[Request ID: ${id}]`;
                const result = await handler(params, reqId);
                if (result !== null) {
                    return JSON.stringify({ jsonrpc, id, result });
                }
            }
            const result = await fetch(forkingUrl, { method: 'POST', body });
            return await result.text();
        }();

        res.setHeader('Content-Type', 'application/json');
        res.writeHead(200);
        res.end(response);
        res.end('');
    });
});

server.listen(port);
