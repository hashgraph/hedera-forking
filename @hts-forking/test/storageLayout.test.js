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

const { expect } = require('chai');

const { storageLayout } = require('../resources/HtsSystemContract.json');

describe('::storageLayout', function () {
    it('should have one slot per field (sanity check to ensure slots are unique)', function () {
        const set = new Set(storageLayout.storage.map(slot => Number(slot.slot)));
        expect(set.size).to.be.equal(storageLayout.storage.length);
    });

    it('should contain only supported slot types', function () {
        expect(storageLayout.types).to.include.keys(
            't_address',
            't_bool',
            't_bytes_storage',
            't_int256',
            't_string_storage',
            't_uint256',
            't_uint8'
        );
    });

    describe('storage', function () {
        storageLayout.storage.forEach(({ label, offset, slot, type }) => {
            it(`should have slot \`${label}(${slot}): ${type}\` at \`offset\` \`0\` (to avoid packing, thus avoiding making many requests per slot)`, function () {
                expect(offset, label).to.be.equal(0);
            });
        });
    });
});
