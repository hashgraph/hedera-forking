const { expect, config } = require('chai');

const { getHtsStorageAt } = require('@hashgraph/hedera-forking');
const utils = require('../utils');
const { keccak256 } = require('ethers');

config.truncateThreshold = 0;

const toIntHex256 = value => parseInt(value).toString(16).padStart(64, '0');

describe(`getHtsStorageAt`, function () {

    const storageLayout = require('../out/HtsSystemContract.sol/HtsSystemContract.json').storageLayout;
    const slotsByLabel = {};

    for (const slot of storageLayout.storage) {
        slotsByLabel[slot.label] = slot.slot;
    }

    it('`storageLayout` should have all slots at `offset` `0`', function () {
        for (const slot of storageLayout.storage) {
            expect(slot.offset, slot.label).to.be.equal(0);
        }
    });

    it('`storageLayout` should have one slot per field', function () {
        const set = new Set(storageLayout.storage.map(slot => Number(slot.slot)));
        expect(set.size).to.be.equal(storageLayout.storage.length);
    });

    it(`should return \`null\` when \`address\` does not start with \`LONG_ZERO_PREFIX\` (${utils.LONG_ZERO_PREFIX})`, async function () {
        const result = await getHtsStorageAt('0x4e59b44847b379578588920ca78fbf26c0b4956c', '0x0');
        expect(result).to.be.null;
    });

    it.skip('should return `null` when `address` is not found', async function () {
        const mirrorNodeClient = { getTokenById() { throw new Error('Token not found'); } };
        const result = await getHtsStorageAt('0x0000000000000000000000000000000000000001', '0x0', mirrorNodeClient);
        expect(result).to.be.null;
    });

    [
        { token: 'USDC', address: '0x0000000000000000000000000000000000068cDa' },
        { token: 'MFCT', address: '0x0000000000000000000000000000000000483077' },
    ].forEach(({ token, address }) => {

        describe(`\`${token}\` token`, function () {

            const tokenResult = require(`./tokens/${token}/getToken.json`);

            /** @type {import('@hashgraph/hedera-forking').IMirrorNodeClient} */
            const mirrorNodeClient = {
                getTokenById(tokenId) {
                    // https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
                    expect(tokenId).to.be.equal(tokenResult.token_id, 'Invalid usage, provide the right address for token');
                    return tokenResult;
                }
            };

            it(`should return \`ZERO_HEX_32_BYTE\` when the slot is empty`, async function () {
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
                    expect(result.slice(2)).to.be.equal(toIntHex256(tokenResult[utils.toSnakeCase(name)]));
                });
            });
        });
    });
});
