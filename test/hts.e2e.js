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

// @ts-expect-error issue with sdk
const { Hbar, Client, PrivateKey, TokenCreateTransaction } = require('@hashgraph/sdk');
const { HTSAddress, getHIP719Code } = require('@hashgraph/system-contracts-forking');

const { jsonRPCForwarder } = require('@hashgraph/system-contracts-forking/forwarder');
const { anvil } = require('./.anvil.js');
const IHederaTokenService = require('../out/IHederaTokenService.sol/IHederaTokenService.json');
const IERC20 = require('../out/IERC20.sol/IERC20.json');

// https://github.com/hashgraph/hedera-local-node?tab=readme-ov-file#network-variables
const accountId = '0.0.2';
const privateKey =
    '302e020100300506032b65700422042091132178e72057a1d7528025956fe39b0b847f200ab59b2fdd367017f3087137';

const treasury = {
    id: '0.0.1021',
    evmAddress: '0x17b2b8c63fa35402088640e426c6709a254c7ffb',
    primaryKey: '0xeae4e00ece872dd14fb6dc7a04f390563c7d69d16326f2a703ec8e0934060cc7',
};

async function createToken() {
    const client = Client.forNetwork({ '127.0.0.1:50211': '0.0.3' })
        .setOperator(accountId, PrivateKey.fromStringDer(privateKey))
        .setDefaultMaxTransactionFee(new Hbar(100))
        .setDefaultMaxQueryPayment(new Hbar(50));

    const transaction = new TokenCreateTransaction()
        .setTokenName('Fungible Token to test HTS emulation')
        .setTokenSymbol('HTSFT')
        .setTreasuryAccountId(treasury.id)
        .setInitialSupply(50000)
        .setAdminKey(PrivateKey.fromStringDer(privateKey))
        .freezeWith(client);

    const response = await (
        await transaction.sign(PrivateKey.fromStringECDSA(treasury.primaryKey))
    ).execute(client);
    const receipt = await response.getReceipt(client);
    client.close();

    const tokenId = receipt.tokenId;
    assert(tokenId !== null);
    console.info(
        `HTS Token ID ${tokenId} @ 0x${tokenId?.toSolidityAddress()} http://localhost:8080/devnet/token/${tokenId}`
    );

    return tokenId;
}

/**
 *
 * @param {number} time
 * @returns
 */
function sleep(time) {
    return new Promise(resolve => setTimeout(resolve, time));
}

describe('::e2e', function () {
    this.timeout(60000);

    const rpcRelayUrl = 'http://localhost:7546';
    const mirrorNodeUrl = 'http://localhost:5551/api/v1/';

    /** @type {string} */ let tokenId;
    /** @type {string} */ let erc20Address;

    before(async function () {
        const tokenId_ = await createToken();
        tokenId = tokenId_.toString();
        erc20Address = `0x${tokenId_.toSolidityAddress()}`;

        console.log('waiting for token to propagate');
        await sleep(20000);
    });

    [
        {
            name: /**@type{const}*/ ('local-node'),
            host: async () => rpcRelayUrl,
        },
        {
            name: /**@type{const}*/ ('anvil/local-node'),
            host: async () => {
                const token = await (await fetch(`${mirrorNodeUrl}tokens/${tokenId}`)).json();
                console.log(token);
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

                // await sleep(3000);
            });

            it("should retrieve token's `name`, `symbol` and `totalSupply`", async function () {
                expect(await ERC20['name']()).to.be.equal('Fungible Token to test HTS emulation');
                expect(await ERC20['symbol']()).to.be.equal('HTSFT');
                expect(await ERC20['totalSupply']()).to.be.equal(50_000n);
            });

            it('should retrieve `balanceOf` treasury account', async function () {
                if (name === 'anvil/local-node') this.skip();
                expect(await ERC20['balanceOf'](treasury.evmAddress)).to.be.equal(50_000n);
            });

            it.skip("should token's metadata through `getTokenInfo`", async function () {
                await HTS['getTokenInfo'](erc20Address);
            });
        });
    });
});
