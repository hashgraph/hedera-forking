const { expect } = require('chai');

const { storageLayout } = require('../out/HtsSystemContract.sol/HtsSystemContract.json');

describe('storageLayout', function () {
    it('should have all slots at `offset` `0` (to avoid making many requests per slot)', function () {
        for (const slot of storageLayout.storage) {
            expect(slot.offset, slot.label).to.be.equal(0);
        }
    });

    it('should have one slot per field (sanity check to ensure slots are unique)', function () {
        const set = new Set(storageLayout.storage.map(slot => Number(slot.slot)));
        expect(set.size).to.be.equal(storageLayout.storage.length);
    });
});
