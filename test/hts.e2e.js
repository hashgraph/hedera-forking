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

const { inspect } = require('util');

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
function sendAs(contract, signer) {
    return /**@type{import('ethers').Contract}*/ (contract.connect(signer));
}

/**
 * @param {Promise<import('ethers').ContractTransactionResponse>} promise
 * @returns {Promise<void>}
 */
async function waitForTx(promise) {
    const tx = await promise;
    await tx.wait();
}

const OPTS = {
    gasLimit: 500_000,
};

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
        .setSupplyKey(PrivateKey.fromStringECDSA(ft.treasury.privateKey))
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
 * @returns
 */
function sleep(time, why) {
    console.info(c.dim(why), `(${time} ms)`);
    return new Promise(resolve => setTimeout(resolve, time));
}

describe('::e2e', function () {
    this.timeout(60000);

    const rpcRelayUrl = 'http://localhost:7546';
    const mirrorNodeUrl = 'http://localhost:5551/api/v1/';

    /** @type {string} */ let tokenId;
    /** @type {string} */ let erc20Address;
    const nonAssocAddress0 = '0x0000000000000000000000000000000001234567';
    const nonAssocAddress1 = '0xdadB0d80178819F2319190D340ce9A924f783711';

    before(async function () {
        process.env['DEBUG_DISABLE_BALANCE_BLOCKNUMBER'] = '1';

        tokenId = await createToken();
        await sleep(2000, `Token \`${tokenId}\` created, waiting to propagate to Mirror Node`);

        const token = await (await fetch(`${mirrorNodeUrl}tokens/${tokenId}`)).json();
        expect('_status' in token, `Test HTS Token \`${tokenId}\` not found`).to.be.false;

        erc20Address = toAddress(tokenId);
    });

    /**@type{unknown}*/ let tokenInfo = undefined;

    [
        {
            network: /**@type{const}*/ ('anvil/local-node'),
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
            network: /**@type{const}*/ ('local-node'),
            host: async () => rpcRelayUrl,
        },
    ].forEach(({ network, host }) =>
        describe(network, function () {
            /** @type {Contract} */ let HTS;
            /** @type {Contract} */ let ERC20;
            /** @type {Wallet} */ let treasury;
            /** @type {{ [accountNum: number]: Wallet}} */ let wallets;

            before(async function () {
                const rpc = new JsonRpcProvider(await host(), undefined, { batchMaxCount: 1 });
                HTS = new Contract(HTSAddress, [...IHederaTokenService.abi, ...RedirectAbi], rpc);
                treasury = new Wallet(ft.treasury.privateKey, rpc);
                wallets = Object.fromEntries(
                    aliasKeys.map(([accId, pk]) => [accId, new Wallet(pk, rpc)])
                );
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

            // To enable this, we need to change `getTokenInfo` to a `view` function
            it.skip("should retrieve token's metadata through `getTokenInfo`", async function () {
                const info = await HTS['getTokenInfo'](erc20Address);
                console.log(inspect(info, { depth: null }));
                if (tokenInfo === undefined) {
                    tokenInfo = info;
                } else {
                    expect(info).to.be.deep.equal(tokenInfo);
                }
            });

            it('should transfer from treasury to account and leave total supply untouched', async function () {
                const amount = 200_000n;
                const alice = wallets[1012];

                const preTreasuryBalance = await ERC20['balanceOf'](ft.treasury.evmAddress);
                expect(preTreasuryBalance).to.be.equal(BigInt(ft.totalSupply));
                expect(await ERC20['balanceOf'](alice.address)).to.be.equal(0n);
                const preTotalSupply = await ERC20['totalSupply']();

                await waitForTx(sendAs(ERC20, treasury)['transfer'](alice.address, amount, OPTS));

                const postTreasuryBalance = await ERC20['balanceOf'](ft.treasury.evmAddress);
                expect(postTreasuryBalance).to.be.equal(preTreasuryBalance - amount);
                expect(await ERC20['balanceOf'](alice.address)).to.be.equal(amount);
                const postTotalSupply = await ERC20['totalSupply']();
                expect(postTotalSupply).to.be.equal(preTotalSupply);
            });

            it('should mint to treasury account and increase total supply', async function () {
                const preTreasuryBalance = await ERC20['balanceOf'](ft.treasury.evmAddress);
                const preTotalSupply = await ERC20['totalSupply']();

                const amount = 1_000_000n;
                await waitForTx(sendAs(HTS, treasury)['mintToken'](erc20Address, amount, [], OPTS));

                const postTreasuryBalance = await ERC20['balanceOf'](ft.treasury.evmAddress);
                expect(postTreasuryBalance).to.be.equal(preTreasuryBalance + amount);
                const postTotalSupply = await ERC20['totalSupply']();
                expect(postTotalSupply).to.be.equal(preTotalSupply + amount);
            });

            it('should burn from treasury account and decrease total supply', async function () {
                const preTreasuryBalance = await ERC20['balanceOf'](ft.treasury.evmAddress);
                const preTotalSupply = await ERC20['totalSupply']();

                const amount = 500_000n;
                await waitForTx(sendAs(HTS, treasury)['burnToken'](erc20Address, amount, [], OPTS));

                const postTreasuryBalance = await ERC20['balanceOf'](ft.treasury.evmAddress);
                expect(postTreasuryBalance).to.be.equal(preTreasuryBalance - amount);
                const postTotalSupply = await ERC20['totalSupply']();
                expect(postTotalSupply).to.be.equal(preTotalSupply - amount);
            });
        })
    );
});
