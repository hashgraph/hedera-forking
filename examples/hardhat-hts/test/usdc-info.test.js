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
const { ethers } = require('hardhat');

describe('USDC example -- informational', function () {
    it('should get name, symbol and decimals', async function () {
        // https://hashscan.io/mainnet/token/0.0.456858
        const usdcAddress = '0x000000000000000000000000000000000006f89a';

        const usdc = await ethers.getContractAt('IERC20', usdcAddress);
        expect(await usdc['name']()).to.be.equal('USD Coin');
        expect(await usdc['symbol']()).to.be.equal('USDC');
        expect(await usdc['decimals']()).to.be.equal(6n);
    });
});
