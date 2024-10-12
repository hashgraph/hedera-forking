#!/usr/bin/env node --watch

// When in `watch` mode,
// changes in the watched files cause the Node.js process to restart. 
// See https://nodejs.org/docs/v20.17.0/api/cli.html#--watch for more information.

const { strict: assert } = require('assert');
const http = require('http');
const { readFileSync } = require('fs');

const { getHtsCode, getHtsStorageAt } = require('@hashgraph/hedera-forking');
const { HTSAddress, ZERO_HEX_32_BYTE } = require('../utils');
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
 * Returns the token proxy contract bytecode for the given `address`.
 * Based on the proxy contract defined by https://hips.hedera.com/hip/hip-719.
 * For reference, you can see the
 * [`hedera-services`](https://github.com/hashgraph/hedera-services/blob/fbac99e75c27bf9c70ebc78c5de94a9109ab1851/hedera-node/hedera-smart-contract-service-impl/src/main/java/com/hedera/node/app/service/contract/impl/state/DispatchingEvmFrameState.java#L96)
 * implementation.
 * 
 * The **template** bytecode can also be obtained using the `eth_getCode` JSON-RPC method with an HTS token.
 * For example, for `USDC` https://hashscan.io/testnet/token/0.0.429274
 * 
 * ```sh
 * cast code --rpc-url https://testnet.hashio.io/api 0x0000000000000000000000000000000000068cDa
 * ```
 * 
 * > The template bytecode is loaded from `test/lib/HIP719.bytecode`
 * > so it can be shared with Solidity tests.
 * 
 * @param {string} address The token contract `address` to replace.
 * @returns {string} The bytecode for token proxy contract with the replaced `address`.
 */
const getHIP719Code = function () {
    const hip719BytecodePath = './test/lib/HIP719.bytecode';
    console.info(c.cyan('[INFO]'), 'Load HIP719 template bytecode from', c.yellow(hip719BytecodePath));
    const templateBytecode = readFileSync(hip719BytecodePath, 'utf8');
    return (/**@type{string}*/address) => {
        assert(address.startsWith('0x'), `address must start with \`0x\` prefix: ${address}`);
        assert(address.length === 2 + 40, `address must be a valid Ethereum address: ${address}`);
        return templateBytecode.replace('fefefefefefefefefefefefefefefefefefefefe', address.slice(2));
    };
}();

/**
 * Determines whether `address` should be treated as a HIP-719 token proxy contract.
 * 
 * This is done by checking whether `address` is one of the Token addresses configured in the mock data.
 * The mock data can be found under `test/data/`.
 * 
 * @param {string} address 
 * @returns {boolean}
 */
const isHIP719Contract = address => Object
    .values(tokens)
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
        "baseFeePerGas": [
          "0x192cc091400",
          "0x192cc091400"
        ],
        "gasUsedRatio": [
          0.5
        ],
        "oldestBlock": "0x8e1376",
        "reward": [
          [
            "0x0"
          ]
        ]
      }),

    /**
     * https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getblockbynumber
     * 
     * @type {EthHandler}
     */
    eth_getBlockByNumber: async ([blockNumber, _transactionDetails]) => require(`./mock/eth_getBlockByNumber_${blockNumber}.json`),

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
                if ((/**@type {{code?: string}}*/(err)).code === 'MODULE_NOT_FOUND')
                    return defaultValue;
                throw err;
            }
        };

        /** @type {import('@hashgraph/hedera-forking').IMirrorNodeClient} */
        const mirrorNodeClient = {
            async getTokenById(tokenId) {
                if (tokens[tokenId] === undefined)
                    return null;
                return require(`../test/data/${tokens[tokenId].symbol}/getToken.json`);
            },
            async getAccount(idOrAliasOrEvmAddress) {
                return requireOrDefault(`getAccount_0x${idOrAliasOrEvmAddress.toLowerCase()}.json`, null);
            },
            async getBalanceOfToken(tokenId, accountId) {
                const noBalance = { balances: [] };
                if (tokens[tokenId] === undefined)
                    return noBalance;
                return requireOrDefault(`${tokens[tokenId].symbol}/getBalanceOfToken_${accountId}.json`, noBalance);
            },
            async getAllowanceForToken(accountId, tokenId, spenderId) {
                const noAllowance = { allowances: [] };
                if (tokens[tokenId] === undefined)
                    return noAllowance;
                return requireOrDefault(`${tokens[tokenId].symbol}/getAllowanceForToken_${accountId}_${spenderId}.json`, noAllowance);
            }
        };

        assert(typeof address === 'string');
        assert(typeof slot === 'string');
        const trace = (/**@type{unknown}*/ msg) => console.debug(c.cyan('[TRACE]'), c.dim(msg));
        const value = await getHtsStorageAt(address, slot, mirrorNodeClient, { trace }, reqId);
        return value ?? ZERO_HEX_32_BYTE;
    },
};

console.log(c.cyan('[INFO]'), 'Tokens mock configuration loaded from', c.yellow('./test/data/'), tokens);

const port = process.env['PORT'] ?? 7546;
console.info(c.yellow('[HINT]'), `Remember to disable Foundry's storage cache using the \`${c.yellow('--no-storage-caching')}\` flag`);
console.info(c.yellow('[HINT]'), c.dim('>'), `forge test --fork-url http://localhost:${port} --no-storage-caching`);
console.info(c.yellow('[HINT]'), c.dim('>'), 'https://book.getfoundry.sh/reference/forge/forge-test#description');
console.info(c.cyan('[INFO]'), '\u{1F680}', c.magenta('JSON-RPC Mock Server'), `running on http://localhost:${c.yellow(port)}`);

http.createServer(function (req, res) {
    /**
     * @param {string} str 
     * @param {number} max 
     * @returns {string}
     */
    const truncate = (str, max = 92) => str.length > max
        ? c.green(str.slice(0, 92)) + c.yellow(`[${str.length - max} more bytes..]`)
        : c.green(str);

    assert(req.url === '/', 'Only root / url is supported');
    assert(req.method === 'POST', 'Only POST allowed');

    // https://nodejs.org/en/learn/modules/anatomy-of-an-http-transaction
    /** @type {Uint8Array[]} */
    let chunks = [];
    req.on('data', chunk => {
        chunks.push(chunk);
    }).on('end', async () => {
        const body = Buffer.concat(chunks).toString();
        console.info(c.cyan('[INFO]'), body);
        const { jsonrpc, id, method, params } = JSON.parse(body);

        assert(jsonrpc === '2.0', 'Only JSON-RPC 2.0');

        const handler = eth[/**@type{keyof typeof eth}*/(method)];
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
