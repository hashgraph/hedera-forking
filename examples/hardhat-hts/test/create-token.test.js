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

describe('Create Token example', function () {
    it('should create and get local token', async function () {
        const name = 'Fungible Token';
        const symbol = 'FT';
        const decimals = 4n;
        const [treasury] = await ethers.getSigners();

        const contract = await ethers.deployContract('CallToken');
        const tx = await (
            await contract['createToken'](name, symbol, decimals, treasury.address, {
                value: 1_000n,
            })
        ).wait();
        const logs = tx.logs.map(log => contract.interface.parseLog(log));

        expect(logs).to.have.length(1);
        expect(logs[0].signature).to.be.equal('TokenCreated(address)');

        const tokenAddress = logs[0].args.toArray()[0];
        {
            const tx = await (await contract['getTokenInfo'](tokenAddress)).wait();
            const logs = tx.logs.map(log => contract.interface.parseLog(log));

            expect(logs).to.have.length(1);
            expect(logs[0].signature).to.be.equal('GetTokenInfo(string,string,string)');
            expect(logs[0].args.toArray()).to.be.deep.equal([name, symbol, '']);
        }
    });
});
