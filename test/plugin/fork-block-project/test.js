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

const { strict: assert } = require('assert');
const { expect } = require('chai');
require('@nomicfoundation/hardhat-chai-matchers');
const hre = require('hardhat');

describe('fork-block-project', function () {
    /**
     * https://hashscan.io/mainnet/token/0.0.1456986
     * https://mainnet.mirrornode.hedera.com/api/v1/tokens/0.0.1456986
     */
    const whbarAddress = '0x0000000000000000000000000000000000163b5a';

    /**
     * https://hashscan.io/mainnet/token/0.0.456858
     * https://mainnet.mirrornode.hedera.com/api/v1/tokens/0.0.456858
     */
    const usdcAddress = '0x000000000000000000000000000000000006f89a';

    it('should not fetch token data in a block where token is not yet created', async function () {
        const [account] = await hre.ethers.getSigners();

        const ft = await hre.ethers.getContractAt('IERC20', whbarAddress);
        await expect(ft['name']()).to.be.rejectedWith('could not decode result data');
        await expect(ft['balanceOf'](account.address)).to.be.rejectedWith(
            'could not decode result data'
        );
    });

    it('should retrieve token data when forking from token creation block', async function () {
        // Token creation block
        resetTo(40804822 + 1);

        const ft = await hre.ethers.getContractAt('IERC20', whbarAddress);
        expect(await ft['name']()).to.be.equal('Wrapped Hbar');
        expect(await ft['symbol']()).to.be.equal('WHBAR');
        expect(await ft['decimals']()).to.be.equal(8n);
    });

    it("should get account's correct balance at different forking blocks", async function () {
        const usdc = await hre.ethers.getContractAt('IERC20', usdcAddress);
        const holderAddress = '0x0000000000000000000000000000000000001887';

        expect(await usdc['balanceOf'](holderAddress)).to.be.equal(321444n);

        // Just some block number we verified the balance was changed in mainnet
        resetTo(70520505);
        expect(await usdc['balanceOf'](holderAddress)).to.be.equal(31_166_366226n);

        resetTo(70715000);
        expect(await usdc['balanceOf'](holderAddress)).to.be.equal(49_857_361652n);
    });
});

/**
 * @param {number} blockNumber
 */
async function resetTo(blockNumber) {
    const { forking } = hre.config.networks.hardhat;
    assert(forking !== undefined);

    await hre.network.provider.request({
        method: 'hardhat_reset',
        params: [
            {
                forking: {
                    // Forwards requests to `https://mainnet.hashio.io/api`
                    jsonRpcUrl: `http://127.0.0.1:${forking.workerPort}`,
                    blockNumber,
                },
            },
        ],
    });
}
