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

const { slotMapOf } = require('../src/slotmap');

describe('::slotMapOf', function () {
    ['MFCT', 'USDC'].forEach(symbol => {
        describe(symbol, function () {
            const map = slotMapOf(require(`../test/data/${symbol}/getToken.json`));

            [...map.entries()].forEach(([slot, { value, path }]) => {
                it(`should have valid slot \`${slot}\` for field \`${path}\``, function () {
                    expect(slot).to.be.not.undefined;
                    expect(value).to.be.not.undefined;
                    expect(value).to.be.a('string');
                    expect(value).to.be.have.length(2 + 64);
                    expect(value.slice(0, 2)).to.be.equal('0x');
                    expect(() => BigInt(value)).to.not.throw(SyntaxError);
                });
            });
        });
    });
});
