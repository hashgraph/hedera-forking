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
const { Contract, JsonRpcProvider, Wallet } = require('ethers');
const c = require('ansi-colors');

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
 * @param {import('ethers').ContractRunner} signer
 * @returns {import('ethers').Contract}
 */
const connectAs = (contract, signer) =>
    /**@type{import('ethers').Contract}*/ (contract.connect(signer));

/**
 * @param {string} accountId
 * @returns
 */
const toAddress = accountId =>
    '0x' + parseInt(accountId.replace('0.0.', '')).toString(16).padStart(40, '0');

const ft = {
    name: 'Random FT Token',
    symbol: 'RFT',
    totalSupply: 5_000_000,
    decimals: 3,
    treasury: {
        id: '0.0.1021',
        evmAddress: '0x17b2b8c63fa35402088640e426c6709a254c7ffb',
        privateKey: '0xeae4e00ece872dd14fb6dc7a04f390563c7d69d16326f2a703ec8e0934060cc7',
    },
};

const aliasKeys = /**@type{const}*/ ([
    [1012, '0x105d050185ccb907fba04dd92d8de9e32c18305e097ab41dadda21489a211524'],
    [1013, '0x2e1d968b041d84dd120a5860cee60cd83f9374ef527ca86996317ada3d0d03e7'],
    [1014, '0x45a5a7108a18dd5013cf2d5857a28144beadc9c70b3bdbd914e38df4e804b8d8'],
    [1015, '0x6e9d61a325be3f6675cf8b7676c70e4a004d2308e3e182370a41f5653d52c6bd'],
    [1016, '0x0b58b1bd44469ac9f813b5aeaf6213ddaea26720f0b2f133d08b6f234130a64f'],
    [1017, '0x95eac372e0f0df3b43740fa780e62458b2d2cc32d6a440877f1cc2a9ad0c35cc'],
    [1018, '0x6c6e6727b40c8d4b616ab0d26af357af09337299f09c66704146e14236972106'],
    [1019, '0x5072e7aa1b03f531b4731a32a021f6a5d20d5ddc4e55acbb71ae202fc6f3a26d'],
    [1020, '0x60fe891f13824a2c1da20fb6a14e28fa353421191069ba6b6d09dd6c29b90eff'],
    [1021, '0xeae4e00ece872dd14fb6dc7a04f390563c7d69d16326f2a703ec8e0934060cc7'],
]);

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
        .setTreasuryAccountId(ft.treasury.id)
        .setInitialSupply(ft.totalSupply)
        .setDecimals(ft.decimals)
        .setAdminKey(PrivateKey.fromStringDer(privateKey))
        .freezeWith(client)
        .sign(PrivateKey.fromStringECDSA(ft.treasury.privateKey));
    const receipt = await (await transaction.execute(client)).getReceipt(client);
    const tokenId = receipt.tokenId;
    client.close();

    assert(tokenId !== null);
    return tokenId.toString();
}

/**
 * @param {number} time
 * @param {string} why
 * @param {Mocha.Context|undefined} ctx
 * @returns
 */
function sleep(time, why, ctx) {
    if (ctx === undefined) {
        console.info(c.dim(why), `(${time} ms)`);
    } else {
        assert(ctx.currentTest !== undefined);
        ctx.currentTest.title += ` (${why}, ${time} ms)`;
    }

    return new Promise(resolve => setTimeout(resolve, time));
}

describe('::e2e', function () {
    this.timeout(100 * 1000);

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
    const getBlocks = ts => _fetch(`blocks?timestamp=gte:${ts}&order=asc&limit=1`);

    /**
     * @param {string} tokenId
     * @param {string} accountId
     * @param {string} ts
     */
    const getBalance = (tokenId, accountId, ts) =>
        _fetch(`tokens/${tokenId}/balances?account.id=${accountId}&timestamp=lte:${ts}`);

    /** @type {string} */ let tokenId;
    /** @type {string} */ let erc20Address;
    const nonAssocAddress0 = '0x0000000000000000000000000000000001234567';
    const nonAssocAddress1 = '0xdadB0d80178819F2319190D340ce9A924f783711';

    let skipAnvilTests = false;

    before(async function () {
        if (process.env['TOKEN_ID'] === undefined) {
            console.info('The `TOKEN_ID` environment variable was not provided, creating token...');
            const tokenId = await createToken();
            console.info(`Token \`${tokenId}\` created`);
            console.info('Next test run using this token needs to be after snapshot balances');
            console.info(c.magenta(`Set \`TOKEN_ID=${tokenId}\` to run tests next time`));
            console.info(c.dim('Skipping tests...'));
            this.skip();
        }

        tokenId = process.env['TOKEN_ID'];
        const token = await getToken(tokenId);
        expect('_status' in token, `Test HTS Token \`${tokenId}\` not found`).to.be.false;

        const [block] = (await getBlocks(token.created_timestamp)).blocks;
        console.info(`Token name="${token.name}" symbol="${token.symbol}" @`, block.number);
        const [latest] = (await getLatestBlock()).blocks;
        console.info('Running on block', latest.number, '...');

        const treasuryId = token.treasury_account_id;
        const { balances } = await getBalance(tokenId, treasuryId, latest.timestamp.to);
        console.info(`Treasury's \`${treasuryId}\` balance`, balances);
        if (balances.length === 0) {
            skipAnvilTests = true;
        }

        erc20Address = toAddress(tokenId);
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
            /** @type {JsonRpcProvider} */ let rpc;
            /** @type {Contract} */ let HTS;
            /** @type {Contract} */ let ERC20;
            /** @type {Wallet} */ let treasury;
            /** @type {{ [accountNum: number]: Wallet}} */ let wallets;

            before(async function () {
                if (name === 'anvil/local-node' && skipAnvilTests) {
                    console.info('    *No balance found for treasury, wait for snapshot, skipping');
                    this.skip();
                }

                rpc = new JsonRpcProvider(await host(), undefined, { batchMaxCount: 1 });
                HTS = new Contract(HTSAddress, [...IHederaTokenService.abi, ...RedirectAbi], rpc);
                treasury = new Wallet(ft.treasury.privateKey, rpc);
                wallets = Object.fromEntries(
                    aliasKeys.map(([accId, pk]) => [accId, new Wallet(pk, rpc)])
                );
            });

            beforeEach(async function () {
                let tid;
                if (name === 'local-node') {
                    tid = await createToken();
                    await sleep(1500, `wait for Token ${tid} to propagate to Mirror Node`, this);
                } else {
                    tid = tokenId;
                }

                erc20Address = toAddress(tid);
                ERC20 = new Contract(erc20Address, [...IERC20.abi, ...IHRC719.abi], rpc);
            });

            it("should retrieve token's `name`, `symbol` and `totalSupply`", async function () {
                expect(await ERC20['name']()).to.be.equal(ft.name);
                expect(await ERC20['symbol']()).to.be.equal(ft.symbol);
                expect(await ERC20['totalSupply']()).to.be.equal(BigInt(ft.totalSupply));
                expect(await ERC20['decimals']()).to.be.equal(BigInt(ft.decimals));
            });

            it('should retrieve `balanceOf` treasury account', async function () {
                const value = await ERC20['balanceOf'](ft.treasury.evmAddress);
                expect(value).to.be.equal(BigInt(ft.totalSupply));
            });

            it('should retrieve zero `balanceOf` for non-associated accounts', async function () {
                expect(await ERC20['balanceOf'](nonAssocAddress0)).to.be.equal(0n);
                expect(await ERC20['balanceOf'](nonAssocAddress1)).to.be.equal(0n);
            });

            it('should get it `isAssociated` for treasury account', async function () {
                const value = await ERC20['isAssociated']({ from: ft.treasury.evmAddress });
                expect(value).to.be.equal(true);
            });

            it('should get not `isAssociated` for existing non-associated account', async function () {
                expect(await ERC20['isAssociated']({ from: toAddress('0.0.1002') })).to.be.equal(
                    false
                );
                expect(await ERC20['isAssociated']({ from: wallets[1012].address })).to.be.equal(
                    false
                );
            });

            // These reverts instead of returning `false`.
            // Should we have the same behavior in emulated HTS?
            it.skip('should get not `isAssociated` for non-existing non-associated accounts', async function () {
                expect(await ERC20['isAssociated']({ from: nonAssocAddress0 })).to.be.equal(false);
                expect(await ERC20['isAssociated']({ from: nonAssocAddress1 })).to.be.equal(false);
            });

            // To enable this, the signature of `getTokenInfo` needs to be "exactly" the same to HTS.
            // Now it's not the same because we needed to reorder fields and add `__gap`s to avoid offsets.
            // This implies we need to implement offsets to enable this.
            it.skip("should retrieve token's metadata through `getTokenInfo`", async function () {
                await HTS['getTokenInfo'](erc20Address);
            });

            it('should transfer from treasury to account', async function () {
                const amount = 200_000n;
                const alice = wallets[1012];

                const treasuryBalance = await ERC20['balanceOf'](ft.treasury.evmAddress);
                expect(treasuryBalance).to.be.equal(BigInt(ft.totalSupply));
                expect(await ERC20['balanceOf'](alice.address)).to.be.equal(0n);

                // const tx = await connectAs(ERC20, alice)['associate']();
                // await tx.wait();
                // console.log('receipt', r);

                // const isassoc = await ERC20['isAssociated']({ from: alice.address });
                // console.log('isassoc', isassoc);

                const x = await connectAs(ERC20, treasury)['transfer'](alice.address, amount, {
                    gasLimit: 1_000_000,
                });
                // console.log(x);
                // if (name !== 'anvil/local-node') {
                // const y =
                await x.wait();
                // console.log(y);
                // }

                expect(await ERC20['balanceOf'](ft.treasury.evmAddress)).to.be.equal(
                    treasuryBalance - amount
                );
                expect(await ERC20['balanceOf'](alice.address)).to.be.equal(amount);
            });
        });
    });
});
