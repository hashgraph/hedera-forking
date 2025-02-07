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
const { ethers: { getContractAt } } = require('hardhat');

describe('NFT example -- ownerOf', function () {
    it('should get `ownerOf` account holder', async function () {
        // https://hashscan.io/mainnet/token/0.0.4970613
        const nft = await getContractAt('IERC721', '0x00000000000000000000000000000000004bd875');

        // The assertion below cannot be guaranteed, since we can only query the current owner of the NFT,
        // Note that the ownership of the NFT may change over time.
        expect(await nft['ownerOf'](1)).to.be.equal('0x0000000000000000000000000000000000161927');
    });
});
