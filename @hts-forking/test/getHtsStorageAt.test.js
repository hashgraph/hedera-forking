const { strict: assert } = require('assert');
const { expect, config } = require('chai');
const { keccak256, id } = require('ethers');

const { getHtsStorageAt: _getHtsStorageAt } = require('@hashgraph/hts-forking');
const utils = require('../src/utils');
const { tokens } = require('../test/data');

config.truncateThreshold = 0;

describe('::getHtsStorageAt', function () {

    /**
     * Enable test `logger` for `getHtsStorageAt` by setting the `TRACE` environment variable.
     * 
     * When `TRACE` is set, `trace` logger will be enabled using a sequential `requestId`.
     * 
     * @type {(address: string, slot: string, mirrorNodeClient: import('@hashgraph/hts-forking').IMirrorNodeClient) => Promise<string | null>}
     */
    const getHtsStorageAt = function () {
        const logger = !!process.env['TRACE']
            ? { trace: (/**@type{unknown}*/ msg) => console.log(`TRACE ${msg}`) }
            : { trace: () => undefined };
        let reqId = 1;
        return (address, slot, mirrorNodeClient) => _getHtsStorageAt(address, slot, mirrorNodeClient, logger, `[Req ID: ${reqId++}]`);
    }();

    /** @type {import('@hashgraph/hts-forking').IMirrorNodeClient} */
    const baseMirrorNodeClient = {
        getTokenById(_tokenId) {
            throw Error('Not implemented');
        },
        async getAccount(_idOrAliasOrEvmAddress) {
            throw Error('Not implemented');
        },
        async getBalanceOfToken(_tokenId, _accountId) {
            throw Error('Not implemented');
        },
        async getAllowanceForToken(_accountId, _tokenId, _spenderId) {
            throw Error('Not implemented');
        }
    };

    const slotsByLabel = function (/**@type{{[label: string]: string}}*/ slotsByLabel, { storageLayout }) {
        for (const slot of storageLayout.storage) {
            slotsByLabel[slot.label] = slot.slot;
        }
        return slotsByLabel;
    }({}, require('../out/HtsSystemContract.sol/HtsSystemContract.json'));

    it(`should return \`null\` when \`address\` does not start with \`LONG_ZERO_PREFIX\` (${utils.LONG_ZERO_PREFIX})`, async function () {
        const result = await getHtsStorageAt('0x4e59b44847b379578588920ca78fbf26c0b4956c', '0x0', baseMirrorNodeClient);
        expect(result).to.be.null;
    });

    it(`should return \`ZERO_HEX_32_BYTE\` when slot does not correspond to any field`, async function () {
        // Slot `0x100` should not be present in `HtsSystemContract`
        const result = await getHtsStorageAt(`${utils.LONG_ZERO_PREFIX}1`, '0x100', baseMirrorNodeClient);
        expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
    });

    it(`should return \`ZERO_HEX_32_BYTE\` when \`address\` is not found for a non-keccaked slot`, async function () {
        /** @type{import('@hashgraph/hts-forking').IMirrorNodeClient} */
        const mirrorNodeClient = { ...baseMirrorNodeClient, getTokenById: async _tokenId => null };
        const result = await getHtsStorageAt('0x0000000000000000000000000000000000000001', '0x0', mirrorNodeClient);
        expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
    });

    ['name', 'symbol'].forEach(name => {
        const slot = slotsByLabel[name];
        it(`should return \`ZERO_HEX_32_BYTE\` when \`address\` is not found for the keccaked slot of \`${slot}\` for field \`${name}\``, async function () {
            const keccakedSlot = keccak256('0x' + utils.toIntHex256(slot));
            /** @type{import('@hashgraph/hts-forking').IMirrorNodeClient} */
            const mirrorNodeClient = { ...baseMirrorNodeClient, getTokenById: async _tokenId => null };
            const result = await getHtsStorageAt('0x0000000000000000000000000000000000000001', keccakedSlot, mirrorNodeClient);
            expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
        });
    });

    describe('`getAccountId` mapping on `0x167`', function () {
        const HTS = '0x0000000000000000000000000000000000000167';

        it(`should return \`ZERO_HEX_32_BYTE\` on \`0x167\` when slot does not match \`getAccountId\``, async function () {
            const slot = '0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15';
            const result = await getHtsStorageAt(HTS, slot, baseMirrorNodeClient);
            expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
        });

        it(`should return address' suffix on \`0x167\` when accountId does not exist`, async function () {
            /** @type{import('@hashgraph/hts-forking').IMirrorNodeClient} */
            const mirrorNodeClient = { ...baseMirrorNodeClient, getAccount: async _address => null };
            const slot = '0xe0b490f700000000000000004D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15';
            const result = await getHtsStorageAt(HTS, slot, mirrorNodeClient);
            expect(result).to.be.equal(`0x${slot.slice(-8).padStart(64, '0')}`);
        });

        ['1.0.1421', '0.1.1421'].forEach(accountId => {
            it(`should return \`ZERO_HEX_32_BYTE\` on \`0x167\` when slot matches \`getAccountId\` but \`${accountId}\`'s shard|realm is not zero`, async function () {
                /** @type{import('@hashgraph/hts-forking').IMirrorNodeClient} */
                const mirrorNodeClient = { ...baseMirrorNodeClient, getAccount: async _address => ({ account: accountId }) };
                const slot = '0xe0b490f700000000000000004D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15';
                const result = await getHtsStorageAt(HTS, slot, mirrorNodeClient);
                expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
            });
        });

        it(`should return accountId on \`0x167\` when slot matches \`getAccountId\``, async function () {
            /**
             * https://testnet.mirrornode.hedera.com/api/v1/accounts/0x4d1c823b5f15be83fdf5adaf137c2a9e0e78fe15?transactions=false
             * @param {string} idOrAliasOrEvmAddress 
             * @returns 
             */
            const getAccount = (idOrAliasOrEvmAddress) => {
                return require(`./data/getAccount_0x${idOrAliasOrEvmAddress.toLowerCase()}.json`);
            };

            const slot = '0xe0b490f700000000000000004D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15';
            const result = await getHtsStorageAt(HTS, slot, { ...baseMirrorNodeClient, getAccount });
            expect(result).to.be.equal(`0x${'58d'.padStart(64, '0')}`);
        });
    });

    Object.values(tokens).forEach(({ symbol, address }) => {
        describe(`\`${symbol}(${address})\` token`, function () {
            const tokenResult = require(`./data/${symbol}/getToken.json`);

            /** @type {import('@hashgraph/hts-forking').IMirrorNodeClient} */
            const mirrorNodeClient = {
                ...baseMirrorNodeClient,
                getTokenById(tokenId) {
                    // https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
                    expect(tokenId).to.be.equal(tokenResult.token_id, 'Invalid usage, provide the right address for token');
                    return tokenResult;
                },
            };

            it(`should return \`ZERO_HEX_32_BYTE\` when slot does not correspond to any field (even if token is found)`, async function () {
                // Slot `0x100` should not be present in `HtsSystemContract`
                const result = await getHtsStorageAt(address, '0x100', mirrorNodeClient);
                expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
            });

            [
                'name',
                'symbol'
            ].forEach(name => {
                const slot = slotsByLabel[name];

                it(`should get storage for string field \`${name}\` at slot \`${slot}\``, async function () {
                    const result = await getHtsStorageAt(address, slot, mirrorNodeClient);

                    const str = tokenResult[name];
                    if (str.length > 31) {
                        assert(this.test !== undefined);
                        this.test.title += ' (large string)';
                        const len = ((str.length * 2) + 1).toString(16).padStart(2, '0');
                        assert(result !== null);
                        expect(result.slice(2)).to.be.equal('0'.repeat(62) + len);

                        const baseSlot = BigInt(keccak256('0x' + utils.toIntHex256(slot)));
                        let value = '';
                        for (let i = 0; i < (str.length >> 5) + 1; i++) {
                            const result = await getHtsStorageAt(address, `0x${(baseSlot + BigInt(i)).toString(16)}`, mirrorNodeClient);
                            assert(result !== null);
                            value += result.slice(2);
                        }
                        const decoded = Buffer.from(value, 'hex').subarray(0, str.length).toString('utf8');
                        expect(decoded).to.be.equal(str);
                    } else {
                        const value = Buffer.from(str).toString('hex').padEnd(62, '0');
                        const len = (str.length * 2).toString(16).padStart(2, '0');
                        assert(result !== null);
                        expect(result.slice(2)).to.be.equal(value + len);
                    }
                });
            });

            [
                'decimals',
                'totalSupply'
            ].forEach(name => {
                const slot = slotsByLabel[name];

                it(`should get storage for primitive field \`${name}\` at slot \`${slot}\``, async function () {
                    const result = await getHtsStorageAt(address, slot, mirrorNodeClient);
                    assert(result !== null);
                    expect(result.slice(2)).to.be.equal(utils.toIntHex256(tokenResult[utils.toSnakeCase(name)]));
                });
            });

            /**
             * Pads `accountId` to be encoded within a storage slot.
             * 
             * @param {number} accountId The `accountId` to pad.
             * @returns {string}
             */
            const padAccountId = accountId => accountId.toString(16).padStart(8, '0');

            (/**@type{{name: string, fn: import('@hashgraph/hts-forking').IMirrorNodeClient['getBalanceOfToken']}[]}*/([
                { name: 'balance is found', fn: async (_tid, accountId) => require(`./data/${symbol}/getBalanceOfToken_${accountId}`) },
                { name: 'balance is empty', fn: async (_tid, _accountId) => ({ balances: [] }) },
            ])).forEach(({ name, fn: getBalanceOfToken }) => {
                const selector = id('balanceOf(address)').slice(0, 10);
                const padding = '0'.repeat(24 * 2);

                it(`should get \`balanceOf(${selector})\` tokenId for encoded account when '${name}'`, async function () {
                    const accountId = 1421;
                    const slot = `${selector}${padding}${padAccountId(accountId)}`;
                    const result = await getHtsStorageAt(address, slot, { ...baseMirrorNodeClient, getBalanceOfToken });

                    const { balances } = await getBalanceOfToken('<not used>', `0.0.${accountId}`);
                    expect(result).to.be.equal(balances.length === 0
                        ? utils.ZERO_HEX_32_BYTE
                        : `0x${utils.toIntHex256(balances[0].balance.toString())}`
                    );
                });
            });

            (/**@type{{name: string, fn: import('@hashgraph/hts-forking').IMirrorNodeClient['getAllowanceForToken']}[]}*/([
                { name: 'allowance is found', fn: (accountId, _tid, spenderId) => require(`./data/${symbol}/getAllowanceForToken_${accountId}_${spenderId}`) },
                { name: 'allowance is empty', fn: (_accountId, _tid, _spenderId) => ({ allowances: [] }) },
            ])).forEach(({ name, fn: getAllowanceForToken }) => {
                const selector = id('allowance(address,address)').slice(0, 10);
                const padding = '0'.repeat(20 * 2);

                it(`should get \`allowance(${selector})\` of tokenId for encoded owner/spender when '${name}'`, async function () {
                    const accountId = 4233295;
                    const spenderId = 1335;
                    const slot = `${selector}${padding}${padAccountId(spenderId)}${padAccountId(accountId)}`;
                    const result = await getHtsStorageAt(address, slot, { ...baseMirrorNodeClient, getAllowanceForToken });

                    const { allowances } = await getAllowanceForToken(`0.0.${accountId}`, '<not used>', `0.0.${spenderId}`);
                    expect(result).to.be.equal(allowances.length === 0
                        ? utils.ZERO_HEX_32_BYTE
                        : `0x${utils.toIntHex256(allowances[0].amount.toString())}`
                    );
                });
            });

        });
    });
});