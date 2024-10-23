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
const { ethers, network } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

/**
 * Wrapper around `Contract::connect` to reify its return type.
 *
 * @param {import('ethers').Contract} contract 
 * @param {import('@nomicfoundation/hardhat-ethers/signers').HardhatEthersSigner} signer 
 * @returns {import('ethers').Contract}
 */
const connectAs = (contract, signer) => /**@type{import('ethers').Contract}*/(contract.connect(signer));

describe('USDC example', function () {

    async function id() {
        const [receiver, spender] = await ethers.getSigners();
        return { receiver, spender };
    }

    /**
     * https://hashscan.io/mainnet/token/0.0.456858
     * https://mainnet.mirrornode.hedera.com/api/v1/tokens/0.0.456858
     */
    const usdcAddress = '0x000000000000000000000000000000000006f89a';

    /** @type {import('ethers').Contract} */
    let usdc;

    /**
     * https://hashscan.io/mainnet/account/0.0.6279
     * 
     * @type {import('@nomicfoundation/hardhat-ethers/signers').HardhatEthersSigner}
     */
    let holder;

    beforeEach(async function () {
        usdc = await ethers.getContractAt('IERC20', usdcAddress);

        const holderAddress = '0x0000000000000000000000000000000000001887';
        // https://hardhat.org/hardhat-network/docs/reference#hardhat_impersonateaccount
        await network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [holderAddress],
        });
        holder = await ethers.getSigner(holderAddress);
    });

    it('should get name, symbol and decimals', async function () {
        const name = await usdc['name']();
        const symbol = await usdc['symbol']();
        const decimals = await usdc['decimals']();
        expect(name).to.be.equal('USD Coin');
        expect(symbol).to.be.equal('USDC');
        expect(decimals).to.be.equal(6n);
    });

    it('should get Token name through a contract call', async function () {
        const CallToken = await ethers.getContractFactory('CallToken');
        const callToken = await CallToken.deploy();

        expect(await callToken['getTokenName'](usdcAddress))
            .to.be.equal('USD Coin');
    });

    it('should get `balanceOf` account holder', async function () {
        const balance = await usdc['balanceOf'](holder.getAddress());
        expect(balance).to.be.greaterThan(0n);
    });

    it("should `tranfer` tokens from account holder to one of Hardhat' signers", async function () {
        const { receiver } = await loadFixture(id);

        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(0n);

        await connectAs(usdc, holder)['transfer'](receiver, 10_000_000n);

        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(10_000_000n);
    });

    it("should `tranferFrom` tokens from account holder after `approve`d one of Hardhat' signers", async function () {
        const { receiver, spender } = await loadFixture(id);
        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(0n);

        await connectAs(usdc, holder)['approve'](spender, 5_000_000n);

        expect(await usdc['allowance'](holder.address, spender.address)).to.be.equal(5_000_000n);

        await connectAs(usdc, spender)['transferFrom'](holder.address, receiver, 3_000_000n);

        expect(await usdc['allowance'](holder.address, spender.address)).to.be.equal(2_000_000n);
        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(3_000_000n);
    });
});
