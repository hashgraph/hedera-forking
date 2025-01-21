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
// prettier-ignore
const { ethers: { getSigner, getSigners, getContractAt }, network: { provider } } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

describe('NFT example -- transferFrom', function () {
    async function id() {
        return [(await getSigners())[0]];
    }

    it("should `transferFrom` tokens from account holder to one of Hardhat' signers", async function () {
        const [receiver] = await loadFixture(id);

        // https://hashscan.io/mainnet/token/0.0.4970613
        const nft = await getContractAt('IERC721', '0x00000000000000000000000000000000004bd875');

        const holderAddress = await nft['ownerOf'](1n);

        await provider.request({
            method: 'hardhat_impersonateAccount',
            params: [holderAddress],
        });

        const holder = await getSigner(holderAddress);
        await nft.connect(holder)['transferFrom'](holder, receiver, 1n);

        expect(await nft['ownerOf'](1n)).to.be.equal(receiver.address);
    });
});
