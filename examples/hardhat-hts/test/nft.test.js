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
const connectAs = (contract, signer) =>
    /**@type{import('ethers').Contract}*/ (contract.connect(signer));

describe('NFT example', function () {
    /**
     * `signers[0]` is used in test `nft-transfer.test`
     * Signers need to be different because otherwise the state is shared between test suites.
     * This is because to use the same fixture, the `id` function needs to be shared among them.
     *
     * See https://hardhat.org/hardhat-network-helpers/docs/reference#fixtures for more details.
     */
    async function id() {
        const [, receiver, spender] = await ethers.getSigners();
        return { receiver, spender };
    }

    /**
     * https://hashscan.io/mainnet/token/0.0.8098137
     * https://mainnet.mirrornode.hedera.com/api/v1/tokens/0.0.8098137
     */
    const nftAddress = '0x00000000000000000000000000000000007b9159';

    /** @type {import('ethers').Contract} */
    let nft;

    /**
     * https://hashscan.io/mainnet/account/0.0.6279
     *
     * @type {import('@nomicfoundation/hardhat-ethers/signers').HardhatEthersSigner}
     */
    let holder;

    beforeEach(async function () {
        nft = await ethers.getContractAt('IERC721', nftAddress);

        const holderAddress = '0x0000000000000000000000000000000000001887';
        // https://hardhat.org/hardhat-network/docs/reference#hardhat_impersonateaccount
        await network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [holderAddress],
        });
        holder = await ethers.getSigner(holderAddress);
    });

    it('should get name, symbol and tokenURI', async function () {
        const name = await nft['name']();
        const symbol = await nft['symbol']();
        const tokenURI = await nft['tokenURI'](1);
        expect(name).to.be.equal('Hash Monkey Community token support');
        expect(symbol).to.be.equal('NFTmonkey');
        expect(tokenURI).to.be.equal(
            'ipfs://bafkreif4t2apm7apgyu3lsi6ak3vxa3nd2oqpczqhnqapno2jbnj62oszy'
        );
    });

    it('should get Token name through a contract call', async function () {
        const CallToken = await ethers.getContractFactory('CallNFT');
        const callToken = await CallToken.deploy();

        expect(await callToken['getTokenName'](nftAddress)).to.be.equal(
            'Hash Monkey Community token support'
        );
    });

    it('should get `ownerOf` account holder', async function () {
        const owner = await nft['ownerOf'](1);
        expect(owner).to.be.equal(holder.address);
    });

    it("should `transfer` tokens from account holder to one of Hardhat' signers", async function () {
        const { receiver } = await loadFixture(id);
        const serialId = 1;

        expect(await nft['ownerOf'](serialId)).to.be.equal(holder.address);

        await connectAs(nft, holder)['transfer'](receiver, serialId);

        expect(await nft['ownerOf'](serialId)).to.be.equal(receiver.address);
    });

    it("should `transferFrom` tokens from account holder after `approve`d one of Hardhat' signers", async function () {
        const { receiver, spender } = await loadFixture(id);
        const serialId = 1;
        expect(await nft['ownerOf'](serialId)).to.be.equal(holder.address);

        await connectAs(nft, holder)['approve'](spender, serialId);

        expect(await nft['isApproved'](holder.address, spender.address)).to.be.equal(true);

        await connectAs(nft, spender)['transferFrom'](spender.address, receiver, serialId);

        expect(await nft['isApproved'](holder.address, spender.address)).to.be.equal(false);
        expect(await nft['ownerOf'](serialId)).to.be.equal(receiver);
    });

    it("should indirectly `transferFrom` tokens from account holder after `approve`d one of Hardhat' signers", async function () {
        const { receiver, spender } = await loadFixture(id);
        const serialId = 1;
        expect(await nft['ownerOf'](serialId)).to.be.equal(holder.address);

        const CallToken = await ethers.getContractFactory('CallNFT');
        const callToken = await CallToken.deploy();
        const callTokenAddress = await callToken.getAddress();

        await connectAs(nft, holder)['approve'](callTokenAddress, 1);
        await connectAs(callToken, holder)['invokeTransferFrom'](nftAddress, receiver, 1);

        expect(await nft['isApproved'](holder.address, spender.address)).to.be.equal(false);
        expect(await nft['ownerOf'](serialId)).to.be.equal(receiver);
    });
});
