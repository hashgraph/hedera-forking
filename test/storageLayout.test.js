const { expect } = require('chai');

const { storageLayout } = require('../out/HtsSystemContract.sol/HtsSystemContract.json');

describe('storageLayout', function () {
    it('should have all slots at `offset` `0` (to avoid packing, thus making many requests per slot)', function () {
        for (const slot of storageLayout.storage) {
            expect(slot.offset, slot.label).to.be.equal(0);
        }
    });

    it('should have one slot per field (sanity check to ensure slots are unique)', function () {
        const set = new Set(storageLayout.storage.map(slot => Number(slot.slot)));
        expect(set.size).to.be.equal(storageLayout.storage.length);
    });

    it('should contain only string and number slot types (to ensure all types are supported)', function () {
        expect(storageLayout.types).to.have.all.keys('t_uint8', 't_uint256', 't_string_storage');
    });
});
