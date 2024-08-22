const { expect, config } = require('chai');

const { getHtsStorageAt } = require('@hashgraph/hedera-forking');

config.truncateThreshold = 0;

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

    [
        { token: 'USDC', address: '0x0000000000000000000000000000000000068cDa' }
    ].forEach(({ token, address }) => {

        describe(`\`${token}\` token`, function () {

            /** @type {import('@hashgraph/hedera-forking').IMirrorNodeClient} */
            const mirrorNodeClient = {
                getTokenById(tokenId) {
                    // https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
                    const result = require(`./tokens/${token}/getToken.json`);
                    expect(tokenId).to.be.equal(result.token_id, 'asfdasdf');
                    return result;
                }
            }

            const slot = slotsByLabel['decimals'];
            it(`should be larger than decimals ${slot}`, async function () {
                const decimals = await getHtsStorageAt(address, slot, mirrorNodeClient);
                expect(decimals).to.be.equal(6);
            });

        });
    });
});
