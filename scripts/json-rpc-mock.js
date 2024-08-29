#!/usr/bin/env node --watch

const { strict: assert } = require('assert');
const http = require('http');
const utils = require('../utils');

const c = {
    dim: text => `\x1b[2m${text}\x1b[0m`,
    red: text => `\x1b[31m${text}\x1b[0m`,
    // const green = text => `\x1b[32m${text}\x1b[0m`,
    yellow: text => `\x1b[33m${text}\x1b[0m`,
    // const blue = text => `\x1b[34m${text}\x1b[0m`,
    // const magenta = text => `\x1b[35m${text}\x1b[0m`,
    cyan: text => `\x1b[36m${text}\x1b[0m`,
};

/**
 * Tokens mock setup
 */
const tokens = {
    '0.0.429274': { symbol: 'USDC', address: '0x0000000000000000000000000000000000068cDa' },
    '0.0.4730999': { symbol: 'MFCT', address: '0x0000000000000000000000000000000000483077' },
};

/**
 * https://hips.hedera.com/hip/hip-719
 * 
 * @param {string} address 
 * @returns {string}
 */
function HIP719(address) {
    assert(address.startsWith('0x'), `address must start with \`0x\` prefix: ${address}`);
    assert(address.length === 2 + 40, `address must be a valid Ethereum address: ${address}`);
    return `6080604052348015600f57600080fd5b506000610167905077618dc65e${address.slice(2)}600052366000602037600080366018016008845af43d806000803e8160008114605857816000f35b816000fdfea2646970667358221220d8378feed472ba49a0005514ef7087017f707b45fb9bf56bb81bb93ff19a238b64736f6c634300080b0033`;
}

/**
 * 
 * @param {string} address 
 * @returns {boolean}
 */
function isHIP719(address) {
    return Object
        .values(tokens)
        .map(({ address }) => address.toLowerCase())
        .includes(address.toLowerCase());
}

/**
 * https://ethereum.github.io/execution-apis/api-documentation/
 */
const eth = {
    eth_blockNumber: async _params => '0x811364',
    eth_gasPrice: async _params => '0x1802ba9f400',
    eth_chainId: async _params => '0x12b',
    eth_getBlockByNumber: async ([blockNumber, _transactionDetails]) => require(`./mock/eth_getBlockByNumber_${blockNumber}.json`),

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_gettransactioncount */
    eth_getTransactionCount: ([_address, _blockNumber]) => '0x0',

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getcode */
    eth_getCode: async ([address, _blockNumber]) =>
        address === utils.HTSAddress
            ? require('@hashgraph/hedera-forking').getHtsCode()
            : isHIP719(address)
                ? HIP719(address)
                : '0x'
    ,

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getbalance */
    eth_getBalance: async ([_address, _blockNumber]) => '0x0',

    /** https://docs.infura.io/api/networks/ethereum/json-rpc-methods/eth_getstorageat */
    eth_getStorageAt: async ([address, slot, _blockNumber], reqId) => {
        /** @type {import('@hashgraph/hedera-forking').IMirrorNodeClient} */
        const mirrorNodeClient = {
            async getTokenById(tokenId) {
                if (tokens[tokenId] === undefined)
                    return null;
                return require(`../test/tokens/${tokens[tokenId].symbol}/getToken.json`);
            },
            async getAccount(idOrAliasOrEvmAddress) {
                try {
                    return require(`../test/accounts/getAccount_0x${idOrAliasOrEvmAddress.toLowerCase()}.json`);
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
                    return require(`../test/tokens/${tokens[tokenId].symbol}/getBalanceOfToken_${accountId}.json`);
                } catch (err) {
                    if (err.code === 'MODULE_NOT_FOUND')
                        return noBalance;
                    throw err;
                }
            }
        };

        const trace = msg => console.debug(c.cyan('[TRACE]'), c.dim(msg));

        const value = await require('@hashgraph/hedera-forking').getHtsStorageAt(address, slot, mirrorNodeClient, { trace }, `[Req ID: ${reqId}]`);
        return value ?? utils.ZERO_HEX_32_BYTE;
    },
};

const port = process.env['PORT'] ?? 7546;
console.info(`\u{1F680} JSON-RPC Mock Server running on http://localhost:${c.yellow(port)}`);

http.createServer(function (req, res) {
    assert(req.url === '/', 'Only root / url is supported');
    assert(req.method === 'POST', 'Only POST allowed');

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
        const response = JSON.stringify({ jsonrpc, id, result: await handler(params, id) });
        // console.info('[INFO]', response.slice(0, 100), '...');

        res.setHeader('Content-Type', 'application/json');
        res.writeHead(200);
        res.end(response);
    });
}).listen(port);
