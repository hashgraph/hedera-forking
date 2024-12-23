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

const { slotMapOf, packValues } = require('../src/slotmap');
const { toIntHex256 } = require('../src/utils');

const mirrorNode =
    /** @type{Pick<import('@hashgraph/system-contracts-forking').IMirrorNodeClient, 'getAccount'>} */ ({
        getAccount: async address => ({ account: '', evm_address: address?.replace('0.0.', '') }),
    });

describe('::slotmap', function () {
    describe('slotMapOf', function () {
        ['MFCT', 'USDC'].forEach(symbol => {
            describe(symbol, function () {
                it(`should have valid slot fields`, async function () {
                    const map = slotMapOf(require(`../test/data/${symbol}/getToken.json`));

                    [...map._map.entries()].forEach(([slot, values]) => {
                        expect(slot).to.be.not.undefined;
                        expect(values).to.be.not.undefined;
                        expect(values.length).to.be.greaterThan(0);

                        values.forEach(async ({ value }) => {
                            if (typeof value === 'function') {
                                value = await value(mirrorNode, 0);
                            }
                            expect(values).to.be.a('string');
                            expect(value).to.be.have.length(64);
                            expect(() => BigInt(`0x${value}`)).to.not.throw(SyntaxError);
                        });
                    });
                });
            });
        });
    });

    describe('packValues', function () {
        it('should not accept empty values', function () {
            expect(() => packValues([])).to.throw('values must not be empty');
        });

        [
            {
                values: [{ offset: 0, value: '1234' }],
                result: 0x1234n,
            },
            {
                values: [
                    { offset: 0, value: '12' },
                    { offset: 1, value: '34' },
                    { offset: 2, value: '45' },
                ],
                result: 0x45_34_12n,
            },
            {
                values: [
                    { offset: 0, value: '1234567890abcdef' },
                    { offset: 8, value: '01' },
                    { offset: 9, value: '12345678' },
                ],
                result: 0x12345678_01_1234567890abcdefn,
            },
        ].forEach(({ values, result }) => {
            it(`should pack ${JSON.stringify(values)} into 0x${result.toString(16)}`, function () {
                expect(packValues(values)).to.be.equal(toIntHex256(result));
            });
        });
    });
});
