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

describe('NFT example -- informational', function () {
    it('should get name, symbol and tokenURI', async function () {
        // https://hashscan.io/mainnet/token/0.0.8098137
        const nft = await getContractAt('IERC721', '0x00000000000000000000000000000000007b9159');
        expect(await nft['name']()).to.be.equal('Hash Monkey Community token support');
        expect(await nft['symbol']()).to.be.equal('NFTmonkey');
        expect(await nft['tokenURI']()).to.be.equal(
            'ipfs://bafkreif4t2apm7apgyu3lsi6ak3vxa3nd2oqpczqhnqapno2jbnj62oszy'
        );
    });
});
