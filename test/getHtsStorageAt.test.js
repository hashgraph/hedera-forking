const { expect, config } = require('chai');

const { getHtsStorageAt } = require('@hashgraph/hedera-forking');
const utils = require('../utils');
const { keccak256 } = require('ethers');

config.truncateThreshold = 0;

describe('getHtsStorageAt', function () {

    const slotsByLabel = function (slotsByLabel, { storageLayout }) {
        for (const slot of storageLayout.storage) {
            slotsByLabel[slot.label] = slot.slot;
        }
        return slotsByLabel;
    }({}, require('../out/HtsSystemContract.sol/HtsSystemContract.json'));

    it(`should return \`null\` when \`address\` does not start with \`LONG_ZERO_PREFIX\` (${utils.LONG_ZERO_PREFIX})`, async function () {
        const result = await getHtsStorageAt('0x4e59b44847b379578588920ca78fbf26c0b4956c', '0x0');
        expect(result).to.be.null;
    });

    it(`should return \`ZERO_HEX_32_BYTE\` when slot does not correspond to any field`, async function () {
        // Slot `0x100` should not be present in `HtsSystemContract`
        const result = await getHtsStorageAt(`${utils.LONG_ZERO_PREFIX}1`, '0x100');
        expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
    });

    it(`should return \`ZERO_HEX_32_BYTE\` when \`address\` is not found for a non-keccaked slot`, async function () {
        const mirrorNodeClient = { getTokenById(_tokenId) { return null; } };
        const result = await getHtsStorageAt('0x0000000000000000000000000000000000000001', '0x0', mirrorNodeClient);
        expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
    });

    ['name', 'symbol'].forEach(name => {
        const slot = slotsByLabel[name];
        it(`should return \`ZERO_HEX_32_BYTE\` when \`address\` is not found for the keccaked slot of \`${slot}\` for field \`${name}\``, async function () {
            const keccakedSlot = keccak256('0x' + utils.toIntHex256(slot));
            const mirrorNodeClient = { getTokenById(_tokenId) { return null; } };
            const result = await getHtsStorageAt('0x0000000000000000000000000000000000000001', keccakedSlot, mirrorNodeClient);
            expect(result).to.be.equal(utils.ZERO_HEX_32_BYTE);
        });
    });

    [
        { token: 'USDC', address: '0x0000000000000000000000000000000000068cDa' },
        { token: 'MFCT', address: '0x0000000000000000000000000000000000483077' },
    ].forEach(({ token, address }) => {
        describe(`\`${token}\` token`, function () {

            const tokenResult = require(`./tokens/${token}/getToken.json`);
            const tokenBalancesResult = require(`./tokens/${token}/getTokenBalances.json`);
            const accountIdToEVMAddressSampleMap = {
                '0.0.10': '0x000000000000000000000000000000000000000a',
                '0.0.13': '0x85e9a8c94f874f317aa793026103e73ec82a759f'
            };
            /** @type {import('@hashgraph/hedera-forking').IMirrorNodeClient} */
            const mirrorNodeClient = {
                getTokenById(tokenId) {
                    // https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
                    expect(tokenId).to.be.equal(tokenResult.token_id, 'Invalid usage, provide the right address for token');
                    return tokenResult;
                },
                getTokenBalancesById(tokenId) {
                    // https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274/balances
                    return require(`./tokens/${token}/getTokenBalances.json`);
                },
                getAccount(accountId) {
                    // https://testnet.mirrornode.hedera.com/api/v1/accounts/0.0.10
                    return {
                        evm_address: accountIdToEVMAddressSampleMap[accountId],
                    };
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
                        this.test.title += ' (large string)';
                        const len = ((str.length * 2) + 1).toString(16).padStart(2, '0');
                        expect(result.slice(2)).to.be.equal('0'.repeat(62) + len);

                        const baseSlot = BigInt(keccak256('0x' + utils.toIntHex256(slot)));
                        let value = '';
                        for (let i = 0; i < (str.length >> 5) + 1; i++) {
                            const result = await getHtsStorageAt(address, baseSlot + BigInt(i), mirrorNodeClient);
                            value += result.slice(2);
                        }
                        const decoded = Buffer.from(value, 'hex').subarray(0, str.length).toString('utf8');
                        expect(decoded).to.be.equal(str);
                    } else {
                        const value = Buffer.from(str).toString('hex').padEnd(62, '0');
                        const len = (str.length * 2).toString(16).padStart(2, '0');
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
                    expect(result.slice(2)).to.be.equal(utils.toIntHex256(tokenResult[utils.toSnakeCase(name)]));
                });
            });

            [
                'balances',
                'holders',
            ].forEach(name => {
                const slot = slotsByLabel[name];
                it(`should get storage for array \`${name}\` size at slot ${slot}`, async function () {
                    const result = await getHtsStorageAt(address, slot, mirrorNodeClient);
                    expect(parseInt(result, 16)).to.be.equal(tokenBalancesResult.balances.length);
                });
            });
            for (let i = 0; i < tokenBalancesResult.balances.length; i++) {
                it(`should get storage values for array \`holders\` at index ${i}`, async function () {
                    const baseSlot = BigInt(keccak256('0x' + utils.toIntHex256(slotsByLabel['holders'])));
                    const result = await getHtsStorageAt(address, baseSlot + BigInt(i), mirrorNodeClient);
                    expect(parseInt(result, 16)).to.be.equal(parseInt(accountIdToEVMAddressSampleMap[tokenBalancesResult.balances[i].account], 16));
                });
                it(`should get storage values for array \`balances\` at index ${i}`, async function () {
                    const baseSlot = BigInt(keccak256('0x' + utils.toIntHex256(slotsByLabel['balances'])));
                    const result = await getHtsStorageAt(address, baseSlot + BigInt(i), mirrorNodeClient);
                    expect(parseInt(result, 16)).to.be.equal(tokenBalancesResult.balances[i].balance);
                });
            }
        });
    });
});
