const { expect } = require('chai');

const { getHtsCode } = require('@hashgraph/hedera-forking');

describe('::getHtsCode', function () {

    it('should be larger than `0xfe` (invalid instruction bytecode)', function () {
        const bytecode = getHtsCode();
        expect(bytecode).to.have.lengthOf.above(4);
    });

});
