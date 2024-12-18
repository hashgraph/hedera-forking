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

const { jsonRPCForwarder } = require('@hashgraph/system-contracts-forking/forwarder');
const { anvil } = require('./.anvil.js');

const IHederaTokenService = require('../out/IHederaTokenService.sol/IHederaTokenService.json');
const IERC20 = require('../out/IERC20.sol/IERC20.json');
const IHRC719 = require('../out/IHRC719.sol/IHRC719.json');

const RedirectAbi = [
    'function redirectForToken(address token, bytes memory encodedFunctionSelector) external returns (int64 responseCode, bytes memory response)',
];

/**
 * Wrapper around `Contract::connect` to reify its return type.
 *
 * @param {import('ethers').Contract} contract
 * @param {import('@nomicfoundation/hardhat-ethers/signers').HardhatEthersSigner} signer
 * @returns {import('ethers').Contract}
 */
const _connectAs = (contract, signer) =>
    /**@type{import('ethers').Contract}*/ (contract.connect(signer));

/**
 * @param {string} accountId
 * @returns
 */
const toAddress = accountId =>
    '0x' + parseInt(accountId.replace('0.0.', '')).toString(16).padStart(40, '0');

const treasury = {
    id: '0.0.1021',
    evmAddress: '0x17b2b8c63fa35402088640e426c6709a254c7ffb',
    primaryKey: '0xeae4e00ece872dd14fb6dc7a04f390563c7d69d16326f2a703ec8e0934060cc7',
};

const ft = {
    name: 'Random FT Token',
    symbol: 'RFT',
    totalSupply: 5_000_000,
    decimals: 3,
};

async function createToken() {
    // https://github.com/hashgraph/hedera-local-node?tab=readme-ov-file#network-variables
    const accountId = '0.0.2';
    const privateKey =
        '302e020100300506032b65700422042091132178e72057a1d7528025956fe39b0b847f200ab59b2fdd367017f3087137';

    const client = Client.forNetwork({ '127.0.0.1:50211': '0.0.3' })
        .setOperator(accountId, PrivateKey.fromStringDer(privateKey))
        .setDefaultMaxTransactionFee(new Hbar(100))
        .setDefaultMaxQueryPayment(new Hbar(50));
    const transaction = await new TokenCreateTransaction()
        .setTokenName(ft.name)
        .setTokenSymbol(ft.symbol)
        .setTreasuryAccountId(treasury.id)
        .setInitialSupply(ft.totalSupply)
        .setDecimals(ft.decimals)
        .setAdminKey(PrivateKey.fromStringDer(privateKey))
        .freezeWith(client)
        .sign(PrivateKey.fromStringECDSA(treasury.primaryKey));
    const receipt = await (await transaction.execute(client)).getReceipt(client);
    const tokenId = receipt.tokenId;
    client.close();

    assert(tokenId !== null);
    return tokenId.toString();
}

/**
 * @param {number} time
 * @param {string} why
 * @returns
 */
function sleep(time, why) {
    console.info(why, `(${time} ms)`);
    return new Promise(resolve => setTimeout(resolve, time));
}

describe('::e2e', function () {
    this.timeout(10 * 1000);

    const rpcRelayUrl = 'http://localhost:7546';
    const mirrorNodeUrl = 'http://localhost:5551/api/v1/';

    /**
     * @param {string} endpoint
     */
    const _fetch = async endpoint => (await fetch(`${mirrorNodeUrl}${endpoint}`)).json();

    const getLatestBlock = () => _fetch('blocks?order=desc&limit=1');

    /**
     * @param {string} tokenId
     */
    const getToken = tokenId => _fetch(`tokens/${tokenId}`);

    /**
     * @param {string} ts
     */
    const getBlocks = async ts => _fetch(`blocks?timestamp=gte:${ts}&order=asc&limit=1`);

    /** @type {string} */ let tokenId;
    /** @type {string} */ let erc20Address;
    const nonAssocAddress = '0x0000000000000000000000000000000000012345';

    before(async function () {
        const [latest] = (await getLatestBlock()).blocks;
        console.info('Running on block', latest.number, '...');

        if (process.env['TOKEN_ID'] === undefined) {
            tokenId = await createToken();
            await sleep(1000, `Waiting for created token ${tokenId} to propagate to Mirror Node`);
        } else {
            tokenId = process.env['TOKEN_ID'];
        }

        erc20Address = toAddress(tokenId);
        const token = await getToken(tokenId);
        if ('_status' in token) {
            console.info('Token has not been propagated yet, skipping tests');
            this.skip();
        }

        const [block] = (await getBlocks(token.created_timestamp)).blocks;
        console.info(`Token name='${token.name}' symbol='${token.symbol}' @`, block.number);
    });

    [
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
        {
            name: /**@type{const}*/ ('local-node'),
            host: async () => rpcRelayUrl,
        },
    ].forEach(({ name, host }) => {
        describe(name, function () {
            /** @type {Contract} */ let HTS;
            /** @type {Contract} */ let ERC20;

            before(async function () {
                const p = new JsonRpcProvider(await host(), undefined, { batchMaxCount: 1 });
                HTS = new Contract(HTSAddress, [...IHederaTokenService.abi, ...RedirectAbi], p);
                ERC20 = new Contract(erc20Address, [...IERC20.abi, ...IHRC719.abi], p);
            });

            it("should retrieve token's `name`, `symbol` and `totalSupply`", async function () {
                expect(await ERC20['name']()).to.be.equal(ft.name);
                expect(await ERC20['symbol']()).to.be.equal(ft.symbol);
                expect(await ERC20['totalSupply']()).to.be.equal(BigInt(ft.totalSupply));
                expect(await ERC20['decimals']()).to.be.equal(BigInt(ft.decimals));
            });

            it('should retrieve `balanceOf` treasury account', async function () {
                const value = await ERC20['balanceOf'](treasury.evmAddress);
                expect(value).to.be.equal(BigInt(ft.totalSupply));
            });

            it('should retrieve zero `balanceOf` for non-associated account', async function () {
                const value = await ERC20['balanceOf'](nonAssocAddress);
                expect(value).to.be.equal(0n);
            });

            it('should get it `isAssociated` for treasury account', async function () {
                const value = await ERC20['isAssociated']({ from: treasury.evmAddress });
                expect(value).to.be.equal(true);
            });

            it('should get not `isAssociated` for existing non-associated account', async function () {
                const value = await ERC20['isAssociated']({ from: toAddress('0.0.1002') });
                expect(value).to.be.equal(false);
            });

            it('should get not `isAssociated` for non-existing non-associated account', async function () {
                const value = await ERC20['isAssociated']({ from: nonAssocAddress });
                expect(value).to.be.equal(false);
            });

            it("should retrieve token's metadata through `getTokenInfo`", async function () {
                this.skip();
                await HTS['getTokenInfo'](erc20Address);
            });
        });
    });
});
