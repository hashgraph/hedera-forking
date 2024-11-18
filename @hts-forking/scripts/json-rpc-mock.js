#!/usr/bin/env node --watch

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

// When in `watch` mode,
// changes in the watched files cause the Node.js process to restart.
// See https://nodejs.org/docs/v20.17.0/api/cli.html#--watch for more information.

const { strict: assert } = require('assert');
const http = require('http');

const {
    getHtsCode,
    getHtsStorageAt,
    HTSAddress,
    getHIP719Code,
} = require('@hashgraph/hts-forking');
const { ZERO_HEX_32_BYTE } = require('../src/utils');
const { tokens } = require('../test/data');

/** ANSI colors functions to avoid any external dependency. */
const c = {
    dim: (/**@type{unknown}*/ text) => `\x1b[2m${text}\x1b[0m`,
    green: (/**@type{unknown}*/ text) => `\x1b[32m${text}\x1b[0m`,
    yellow: (/**@type{unknown}*/ text) => `\x1b[33m${text}\x1b[0m`,
    blue: (/**@type{unknown}*/ text) => `\x1b[34m${text}\x1b[0m`,
    magenta: (/**@type{unknown}*/ text) => `\x1b[35m${text}\x1b[0m`,
    cyan: (/**@type{unknown}*/ text) => `\x1b[36m${text}\x1b[0m`,
};

/**
 * Determines whether `address` should be treated as a HIP-719 token proxy contract.
 *
 * This is done by checking whether `address` is one of the Token addresses configured in the mock data.
 * The mock data can be found under `test/data/`.
 *
 * @param {string} address
 * @returns {boolean}
 */
const isHIP719Contract = address =>
    Object.values(tokens)
        .map(({ address }) => address.toLowerCase())
        .includes(address.toLowerCase());

/**
 * Function signature for `eth_*` and `net_*` method handlers.
 * The `params` argument comes from the JSON-RPC request,
 * so it must to be declared as `unknown[]`.
 * Therefore, each method handler should validate each element of `params` they use.
 *
 * @typedef {(params: unknown[], reqId: string) => Promise<unknown>} EthHandler
 */

/**
 * Mock values taken from `testnet`.
 *
 * https://docs.infura.io/api/networks/ethereum/json-rpc-methods
 * Official Ethereum JSON-RPC spec can be found at https://ethereum.github.io/execution-apis/api-documentation/.
 */
const eth = {
    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/net_version
     *
     * @type {EthHandler}
     */
    net_version: async () => parseInt('0x12b').toString(),

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_chainid
     *
     * @type {EthHandler}
     */
    eth_chainId: async () => '0x12b',

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_blocknumber
     *
     * @type {EthHandler}
     */
    eth_blockNumber: async () => '0x811364',

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_gasprice
     *
     * @type {EthHandler}
     */
    eth_gasPrice: async () => '0x1802ba9f400',

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_feehistory
     *
     * @type {EthHandler}
     */
    eth_feeHistory: async () => ({
        'baseFeePerGas': ['0x192cc091400', '0x192cc091400'],
        'gasUsedRatio': [0.5],
        'oldestBlock': '0x8e1376',
        'reward': [['0x0']],
    }),

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getblockbynumber
     *
     * @type {EthHandler}
     */
    eth_getBlockByNumber: async ([blockNumber, _transactionDetails]) =>
        require(`./mock/eth_getBlockByNumber_${blockNumber}.json`),

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_gettransactioncount
     *
     * @type {EthHandler}
     */
    eth_getTransactionCount: async ([_address, _blockNumber]) => '0x0',

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getcode
     *
     * @type {EthHandler}
     */
    eth_getCode: async ([address, _blockNumber]) =>
        address === HTSAddress
            ? getHtsCode()
            : typeof address === 'string' && isHIP719Contract(address)
              ? getHIP719Code(address)
              : '0x',

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getbalance
     *
     * @type {EthHandler}
     */
    eth_getBalance: async ([_address, _blockNumber]) => '0x0',

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getstorageat
     *
     * @type {EthHandler}
     */
    eth_getStorageAt: async ([address, slot, _blockNumber], reqId) => {
        /**
         * Loads and returns the module indicated by `path` if exists.
         * The `path` is relative to `test/data/`.
         * In case the module does not exist, it returns `defaultValue`.
         *
         * @template T
         * @param {string} path of the module relative to `test/data/`.
         * @param {T} defaultValue The value to return when `path`.
         * @returns {T} The loaded module indicated by `path` if exists. Otherwise `defaultValue`.
         */
        const requireOrDefault = (path, defaultValue) => {
            try {
                return require(`../test/data/${path}`);
            } catch (err) {
                assert(err instanceof Error);
                // https://nodejs.org/api/errors.html#module_not_found
                if (/**@type {{code?: string}}*/ (err).code === 'MODULE_NOT_FOUND')
                    return defaultValue;
                throw err;
            }
        };

        /** @type {import('@hashgraph/hts-forking').IMirrorNodeClient} */
        const mirrorNodeClient = {
            async getTokenById(tokenId) {
                if (tokens[tokenId] === undefined) return null;
                return require(`../test/data/${tokens[tokenId].symbol}/getToken.json`);
            },
            async getAccount(idOrAliasOrEvmAddress) {
                // id in the format "shard.realm.number"
                const idRegex = /^\d+\.\d+\.\d+$/;
                if (idRegex.test(idOrAliasOrEvmAddress)) {
                    return requireOrDefault(`getAccount_${idOrAliasOrEvmAddress}.json`, null);
                } else {
                    return requireOrDefault(
                        `getAccount_0x${idOrAliasOrEvmAddress.toLowerCase()}.json`,
                        null
                    );
                }
            },
            async getBalanceOfToken(tokenId, accountId) {
                const noBalance = { balances: [] };
                if (tokens[tokenId] === undefined) return noBalance;
                return requireOrDefault(
                    `${tokens[tokenId].symbol}/getBalanceOfToken_${accountId}.json`,
                    noBalance
                );
            },
            async getAllowanceForToken(accountId, tokenId, spenderId) {
                const noAllowance = { allowances: [] };
                if (tokens[tokenId] === undefined) return noAllowance;
                return requireOrDefault(
                    `${tokens[tokenId].symbol}/getAllowanceForToken_${accountId}_${spenderId}.json`,
                    noAllowance
                );
            },
        };

        assert(typeof address === 'string');
        assert(typeof slot === 'string');
        const trace = (/**@type{unknown}*/ msg) => console.debug(c.cyan('[TRACE]'), c.dim(msg));
        const value = await getHtsStorageAt(address, slot, mirrorNodeClient, { trace }, reqId);
        return value ?? ZERO_HEX_32_BYTE;
    },
};

console.log(
    c.cyan('[INFO]'),
    'Tokens mock configuration loaded from',
    c.yellow('./test/data/'),
    tokens
);

const port = process.env['PORT'] ?? 7546;
console.info(
    c.yellow('[HINT]'),
    `Remember to disable Foundry's storage cache using the \`${c.yellow('--no-storage-caching')}\` flag`
);
console.info(
    c.yellow('[HINT]'),
    c.dim('>'),
    `forge test --fork-url http://localhost:${port} --no-storage-caching`
);
console.info(
    c.yellow('[HINT]'),
    c.dim('>'),
    'https://book.getfoundry.sh/reference/forge/forge-test#description'
);
console.info(
    c.cyan('[INFO]'),
    '\u{1F680}',
    c.magenta('JSON-RPC Mock Server'),
    `running on http://localhost:${c.yellow(port)}`
);

http.createServer(function (req, res) {
    /**
     * @param {string} str
     * @param {number} max
     * @returns {string}
     */
    const truncate = (str, max = 92) =>
        str.length > max
            ? c.green(str.slice(0, 92)) + c.yellow(`[${str.length - max} more bytes..]`)
            : c.green(str);

    assert(req.url === '/', 'Only root / url is supported');
    assert(req.method === 'POST', 'Only POST allowed');

    // https://nodejs.org/en/learn/modules/anatomy-of-an-http-transaction
    /** @type {Uint8Array[]} */
    const chunks = [];
    req.on('data', chunk => {
        chunks.push(chunk);
    }).on('end', async () => {
        const body = Buffer.concat(chunks).toString();
        console.info(c.cyan('[INFO]'), body);
        const { jsonrpc, id, method, params } = JSON.parse(body);

        assert(jsonrpc === '2.0', 'Only JSON-RPC 2.0');

        const handler = eth[/**@type{keyof typeof eth}*/ (method)];
        assert(handler !== undefined, `Method not supported: ${method}`);
        const reqId = `[Req ID: ${id}]`;
        const result = await handler(params, reqId);
        const response = JSON.stringify({ jsonrpc, id, result });
        console.log(c.cyan('[INFO]'), c.blue(reqId + ' result'), truncate(JSON.stringify(result)));

        res.setHeader('Content-Type', 'application/json');
        res.writeHead(200);
        res.end(response);
    });
}).listen(port);
