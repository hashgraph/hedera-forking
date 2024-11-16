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
const { getHIP719Code } = require('@hashgraph/hts-forking');

describe('::getHIP719Code', function () {
    ['', '1234', '0x', '0x1234'].forEach(address => {
        it(`should throw when address is invalid \`${address}\``, function () {
            expect(() => getHIP719Code(address)).to.throw('Address must be a valid EVM address');
        });
    });

    ['0x', '0X'].forEach(prefix => {
        it(`should return bytecode containing address with prefix \`${prefix}\``, function () {
            const address = 'f39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
            expect(getHIP719Code(`${prefix}${address}`)).to.contain(address);
        });
    });
});
