#!/usr/bin/env node --watch

// When in `watch` mode,
// changes in the watched files cause the Node.js process to restart. 
// See https://nodejs.org/docs/v20.17.0/api/cli.html#--watch for more information.

const { strict: assert } = require('assert');
const { readdirSync, readFileSync } = require('fs');
const http = require('http');

const { getHtsCode, getHtsStorageAt } = require('@hashgraph/hedera-forking');
const { HTSAddress, ZERO_HEX_32_BYTE } = require('../utils');

/**
 * ANSI colors functions to avoid any external dependency.
 */
const c = {
    dim: text => `\x1b[2m${text}\x1b[0m`,
    green: text => `\x1b[32m${text}\x1b[0m`,
    yellow: text => `\x1b[33m${text}\x1b[0m`,
    blue: text => `\x1b[34m${text}\x1b[0m`,
    magenta: text => `\x1b[35m${text}\x1b[0m`,
    cyan: text => `\x1b[36m${text}\x1b[0m`,
};

/**
 * Tokens mock configuration.
 */
const tokens = function (tokens) {
    const tokensMockPath = './test/data';
    for (const symbol of readdirSync(tokensMockPath)) {
        if (symbol.endsWith('.json'))
            continue;
        const { token_id } = JSON.parse(readFileSync(`${tokensMockPath}/${symbol}/getToken.json`));
        const [_shardNum, _realmNum, accountId] = token_id.split('.');
        const address = '0x' + parseInt(accountId).toString(16).padStart(40, '0');
        tokens[token_id] = { symbol, address };
    }
    console.log(c.cyan('[INFO]'), `Tokens mock configuration from \`${tokensMockPath}\``, tokens);
    return tokens;
}({});

/**
 * Returns the token proxy contract bytecode for the given `address`.
 * Based on the proxy contract defined by https://hips.hedera.com/hip/hip-719.
 * 
 * The **template** bytecode was obtained using the `eth_getCode` JSON-RPC method with an HTS token.
 * For example, for `USDC` https://hashscan.io/testnet/token/0.0.429274
 * 
 * ```sh
 * cast code --rpc-url https://testnet.hashio.io/api 0x0000000000000000000000000000000000068cDa
 * ```
 * 
 * @param {string} address The token contract `address` to replace.
 * @returns {string} The bytecode for token proxy contract with the replaced `address`.
 */
function getHIP719Code(address) {
    assert(address.startsWith('0x'), `address must start with \`0x\` prefix: ${address}`);
    assert(address.length === 2 + 40, `address must be a valid Ethereum address: ${address}`);
    return `0x6080604052348015600f57600080fd5b506000610167905077618dc65e${address.slice(2)}600052366000602037600080366018016008845af43d806000803e8160008114605857816000f35b816000fdfea2646970667358221220d8378feed472ba49a0005514ef7087017f707b45fb9bf56bb81bb93ff19a238b64736f6c634300080b0033`;
}

/**
 * Determines whether `address` should be treated as a HIP-719 token proxy contract.
 * 
 * @param {string} address 
 * @returns {boolean}
 */
const isHIP719Contract = address => Object
    .values(tokens)
    .map(({ address }) => address.toLowerCase())
    .includes(address.toLowerCase());

/**
 * Mock values taken from `testnet`.
 * 
 * https://docs.infura.io/api/networks/ethereum/json-rpc-methods
 * Official Ethereum JSON-RPC spec can be found at https://ethereum.github.io/execution-apis/api-documentation/.
 */
const eth = {
    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_blocknumber */
    eth_blockNumber: async _params => '0x811364',

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_gasprice */
    eth_gasPrice: async _params => '0x1802ba9f400',

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_chainid */
    eth_chainId: async _params => '0x12b',

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getblockbynumber */
    eth_getBlockByNumber: async ([blockNumber, _transactionDetails]) => require(`./mock/eth_getBlockByNumber_${blockNumber}.json`),

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_gettransactioncount */
    eth_getTransactionCount: ([_address, _blockNumber]) => '0x0',

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getcode */
    eth_getCode: async ([address, _blockNumber]) =>
        address === HTSAddress
            ? getHtsCode()
            : isHIP719Contract(address)
                ? getHIP719Code(address)
                : '0x',

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getbalance */
    eth_getBalance: async ([_address, _blockNumber]) => '0x0',

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getstorageat */
    eth_getStorageAt: async ([address, slot, _blockNumber], reqId) => {
        /** @type {import('@hashgraph/hedera-forking').IMirrorNodeClient} */
        const mirrorNodeClient = {
            async getTokenById(tokenId) {
                if (tokens[tokenId] === undefined)
                    return null;
                return require(`../test/data/${tokens[tokenId].symbol}/getToken.json`);
            },
            async getAccount(idOrAliasOrEvmAddress) {
                try {
                    return require(`../test/data/getAccount_0x${idOrAliasOrEvmAddress.toLowerCase()}.json`);
                } catch (err) {
                    if (err.code === 'MODULE_NOT_FOUND')
                        return null;
                    throw err;
                }
            },
            async getBalanceOfToken(tokenId, accountId) {
                const noBalance = { balances: [] };
                if (tokens[tokenId] === undefined)
                    return noBalance;
                try {
                    return require(`../test/data/${tokens[tokenId].symbol}/getBalanceOfToken_${accountId}.json`);
                } catch (err) {
                    if (err.code === 'MODULE_NOT_FOUND')
                        return noBalance;
                    throw err;
                }
            },
            async getAllowanceForToken(tokenId, accountId, spenderId) {
                const noAllowance = { allowances: [] };
                if (tokens[tokenId] === undefined)
                    return noAllowance;
                try {
                    return require(`../test/data/${tokens[tokenId].symbol}/getAllowanceForToken_${accountId}_${spenderId}.json`);
                } catch (err) {
                    if (err.code === 'MODULE_NOT_FOUND')
                        return noAllowance;
                    throw err;
                }
            }
        };

        const trace = msg => console.debug(c.cyan('[TRACE]'), c.dim(msg));
        const value = await getHtsStorageAt(address, slot, mirrorNodeClient, { trace }, reqId);
        return value ?? ZERO_HEX_32_BYTE;
    },
};

const port = process.env['PORT'] ?? 7546;
console.info(c.cyan('[INFO]'), '\u{1F680}', c.magenta('JSON-RPC Mock Server'), `running on http://localhost:${c.yellow(port)}`);
console.info(c.yellow('[HINT]'), `Remember to disable Foundry's storage cache using the \`${c.yellow('--no-storage-caching')}\` flag`);
console.info(c.yellow('[HINT]'), c.dim('>'), `foundry test --fork-url http://localhost:${port} --no-storage-caching`);
console.info(c.yellow('[HINT]'), c.dim('>'), 'https://book.getfoundry.sh/reference/forge/forge-test#description');

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
    let chunks = [];
    req.on('data', chunk => {
        chunks.push(chunk);
    }).on('end', async () => {
        const body = Buffer.concat(chunks).toString();
        console.info(c.cyan('[INFO]'), body);
        const { jsonrpc, id, method, params } = JSON.parse(body);

        assert(jsonrpc === '2.0', 'Only JSON-RPC 2.0');

        const handler = eth[method];
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
