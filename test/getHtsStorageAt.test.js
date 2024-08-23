const { expect, config } = require('chai');

const { getHtsStorageAt } = require('@hashgraph/hedera-forking');

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

    it('should return `null` when `address` does not start with `LONG_ZERO_PREFIX`', async function () {
        const result = await getHtsStorageAt('0x4e59b44847b379578588920ca78fbf26c0b4956c', '0x0');
        expect(result).to.be.null;
    });

    it.skip('should return `null` when `address` is not found', async function () {
        const mirrorNodeClient = { getTokenById() { throw new Error('Token not found'); } };
        const result = await getHtsStorageAt('0x0000000000000000000000000000000000000001', '0x0', mirrorNodeClient);
        expect(result).to.be.null;
    });

    [
        { token: 'USDC', address: '0x0000000000000000000000000000000000068cDa' }
    ].forEach(({ token, address }) => {

        describe(`\`${token}\` token`, function () {

            const tokenResult = require(`./tokens/${token}/getToken.json`);

            /** @type {import('@hashgraph/hedera-forking').IMirrorNodeClient} */
            const mirrorNodeClient = {
                getTokenById(tokenId) {
                    // https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
                    expect(tokenId).to.be.equal(tokenResult.token_id, 'asfdasdf');
                    return tokenResult;
                }
            };

            [
                'decimals',
                'totalSupply'
            ].forEach(name => {
                const slot = slotsByLabel[name];

                it(`should get storage for field \`${name}\` at slot \`${slot}\``, async function () {
                    const result = await getHtsStorageAt(address, slot, mirrorNodeClient);

                    const snakeCase = name.replace(/([A-Z])/g, '_$1').toLowerCase();
                    expect(result.slice(2)).to.be.equal(toIntHex256(tokenResult[snakeCase]));
                });
            });

        });
    });
});
