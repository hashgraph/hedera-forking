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
const { expect } = require('chai');
const { Contract, JsonRpcProvider } = require('ethers');

// @ts-expect-error https://github.com/hashgraph/hedera-sdk-js/issues/2722
const { Hbar, Client, PrivateKey, TokenCreateTransaction } = require('@hashgraph/sdk');
const { HTSAddress, getHIP719Code } = require('@hashgraph/system-contracts-forking');

const {
    jsonRPCForwarder,
    MirrorNodeClient,
} = require('@hashgraph/system-contracts-forking/forwarder');
const { anvil } = require('./.anvil.js');
const IHederaTokenService = require('../out/IHederaTokenService.sol/IHederaTokenService.json');
const IERC20 = require('../out/IERC20.sol/IERC20.json');

// https://github.com/hashgraph/hedera-local-node?tab=readme-ov-file#network-variables
const accountId = '0.0.2';
const privateKey =
    '302e020100300506032b65700422042091132178e72057a1d7528025956fe39b0b847f200ab59b2fdd367017f3087137';

const ft = {
    name: 'Fungible Token to test HTS emulation',
    symbol: 'HTSFT',
    totalSupply: 50_000,
    decimals: 8,
    treasury: {
        id: '0.0.1021',
        evmAddress: '0x17b2b8c63fa35402088640e426c6709a254c7ffb',
        primaryKey: '0xeae4e00ece872dd14fb6dc7a04f390563c7d69d16326f2a703ec8e0934060cc7',
    },
};

async function createToken() {
    const client = Client.forNetwork({ '127.0.0.1:50211': '0.0.3' })
        .setOperator(accountId, PrivateKey.fromStringDer(privateKey))
        .setDefaultMaxTransactionFee(new Hbar(100))
        .setDefaultMaxQueryPayment(new Hbar(50));
    const transaction = await new TokenCreateTransaction()
        .setTokenName(ft.name)
        .setTokenSymbol(ft.symbol)
        .setTreasuryAccountId(ft.treasury.id)
        .setInitialSupply(ft.totalSupply)
        .setDecimals(ft.decimals)
        .setAdminKey(PrivateKey.fromStringDer(privateKey))
        .freezeWith(client)
        .sign(PrivateKey.fromStringECDSA(ft.treasury.primaryKey));
    const receipt = await (await transaction.execute(client)).getReceipt(client);
    const tokenId = receipt.tokenId;
    client.close();

    assert(tokenId !== null);
    return tokenId;
}

/**
 * @param {number} time
 * @param {string} why
 * @returns
 */
function sleep(time, why) {
    console.log(why, `(${time} ms)`);
    return new Promise(resolve => setTimeout(resolve, time));
}

describe('::e2e', function () {
    this.timeout(5 * 60 * 1000);

    const rpcRelayUrl = 'http://localhost:7546';
    const mirrorNodeUrl = 'http://localhost:5551/api/v1/';
    const mirrorNodeClient = new MirrorNodeClient(mirrorNodeUrl);

    /**
     * @param {string} tokenId
     */
    const getToken = async tokenId => {
        return (await fetch(`${mirrorNodeUrl}tokens/${tokenId}`)).json();
    };

    /**
     * @param {string} timestamp
     */
    const getBlocks = async timestamp =>
        (await fetch(`${mirrorNodeUrl}blocks?timestamp=gte:${timestamp}&order=asc&limit=1`)).json();

    const getLatestBlock = async () =>
        (await fetch(`${mirrorNodeUrl}blocks?order=desc&limit=1`)).json();

    /**
     * @param {string} timestamp
     * @param {{from: string, to: string}} blockTimestamp
     * @returns
     */
    const inBlock = (timestamp, { from, to }) => from <= timestamp && timestamp <= to;

    /** @type {string} */ let tokenId;
    /** @type {string} */ let erc20Address;

    before(async function () {
        const tokenId_ = await createToken();
        tokenId = tokenId_.toString();
        erc20Address = `0x${tokenId_.toSolidityAddress()}`;

        await sleep(1000, 'Waiting for created token to propagate to Mirror Node');
        const { created_timestamp } = await getToken(tokenId);
        const {
            blocks: [block],
        } = await getBlocks(created_timestamp);
        assert(
            inBlock(created_timestamp, block.timestamp),
            "Token created timestamp is not in block's timestamp span"
        );
        console.log('== Token Creation Block ==', block);
        console.info(`Token ID ${tokenId}|${erc20Address} @ ${created_timestamp}|${block.number}`);

        assert((await mirrorNodeClient.getTokenById(tokenId, block.number - 1)) === null);
        assert((await mirrorNodeClient.getTokenById(tokenId, block.number)) !== null);

        // This is returning empty balances? Why?
        // However, doing an `eth_call` to get this balance works fine.
        // See "local-node/should retrieve `balanceOf` treasury account" test.
        let balances = await mirrorNodeClient.getBalanceOfToken(
            tokenId,
            ft.treasury.id,
            block.number
        );
        console.log('== Treasury Balance at Creation Block ==', balances);

        // However, after ~100 blocks the balance information is visible from the Mirror Node.
        // How can we shorten this time for test purposes?
        await sleep(100 * 1000, 'Waiting for token balances to propagate?');
        const {
            blocks: [latestBlock],
        } = await getLatestBlock();
        balances = await mirrorNodeClient.getBalanceOfToken(
            tokenId,
            ft.treasury.id,
            latestBlock.number
        );
        console.log('== Treasury Balance at Latest Block ==', latestBlock, balances);
    });

    [
        {
            name: /**@type{const}*/ ('local-node'),
            host: async () => rpcRelayUrl,
        },
        {
            name: /**@type{const}*/ ('anvil/local-node'),
            host: async () => {
                const { host: forwarderUrl } = await jsonRPCForwarder(rpcRelayUrl, mirrorNodeUrl);
                const anvilHost = await anvil(forwarderUrl);

                // Ensure HTS emulation is reachable
                const provider = new JsonRpcProvider(anvilHost, undefined, { batchMaxCount: 1 });
                assert((await provider.getCode(erc20Address)) === getHIP719Code(erc20Address));
                assert((await provider.getCode(HTSAddress)).length > 4);

                return anvilHost;
            },
        },
    ].forEach(({ name, host }) => {
        describe(name, function () {
            /** @type {Contract} */ let HTS;
            /** @type {Contract} */ let ERC20;

            before(async function () {
                const provider = new JsonRpcProvider(await host(), undefined, { batchMaxCount: 1 });
                HTS = new Contract(HTSAddress, IHederaTokenService.abi, provider);
                ERC20 = new Contract(erc20Address, IERC20.abi, provider);
            });

            it("should retrieve token's `name`, `symbol` and `totalSupply`", async function () {
                expect(await ERC20['name']()).to.be.equal(ft.name);
                expect(await ERC20['symbol']()).to.be.equal(ft.symbol);
                expect(await ERC20['totalSupply']()).to.be.equal(BigInt(ft.totalSupply));
                expect(await ERC20['decimals']()).to.be.equal(BigInt(ft.decimals));
            });

            it('should retrieve `balanceOf` treasury account', async function () {
                if (name === 'anvil/local-node') this.skip();
                expect(await ERC20['balanceOf'](ft.treasury.evmAddress)).to.be.equal(50_000n);
            });

            it.skip("should token's metadata through `getTokenInfo`", async function () {
                await HTS['getTokenInfo'](erc20Address);
            });
        });
    });
});
