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

const hre = require('hardhat');
const { expect } = require('chai');

describe('message-call-project', function () {
    it('should get decimals through internal message call', async function () {
        const tokenAddress = '0x000000000000000000000000000000000047b52a';
        const contract = await hre.ethers.deployContract('CallToken');
        expect(await contract['getTokenDecimals'](tokenAddress)).to.be.equal(13n);
    });
});
