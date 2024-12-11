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

const {
    storageLayout: { storage, types },
} = require('../out/HtsSystemContract.sol/HtsSystemContract.json');

describe('::storageLayout', function () {
    describe('storage', function () {
        it('should have one slot per field (sanity check to ensure slots are unique and not shared between fields)', function () {
            const set = new Set(storage.map(slot => Number(slot.slot)));
            expect(set.size).to.be.equal(storage.length);
        });

        describe('slots', function () {
            storage.forEach(({ label, offset, slot, type }) => {
                it(`should have slot \`${label}(${slot}): ${type}\` at \`offset\` \`0\` (to avoid packing, thus avoiding making many requests per slot)`, function () {
                    expect(offset, label).to.be.equal(0);
                });
            });
        });
    });

    describe('types', function () {
        it('should contain only supported encodings, i.e., no `mapping`', function () {
            const encodings = new Set(Object.values(types).map(({ encoding }) => encoding));
            expect([...encodings]).to.be.have.members(['inplace', 'bytes', 'dynamic_array']);
        });

        it('should have all its struct members with offset `0` to avoid field packing', function () {
            Object.values(types)
                .filter(ty => 'members' in ty)
                .flatMap(ty => ty.members)
                .forEach(member => {
                    expect(member.offset).to.be.equal(0, member.label);
                });
        });
    });
});
