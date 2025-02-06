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

describe('RPC', function () {
    let signers;

    before(async function () {
        signers = await hre.ethers.getSigners();
    });

    it('should be able to do crypto transfer', async function () {
        const contract = await hre.ethers.getContractAt(
            'IHederaTokenService',
            '0x0000000000000000000000000000000000000167'
        );
        const wallet = signers[0];
        const recipient = '0x435d7d41d4f69f958bda7a8d9f549a0dd9b64c86';
        const initialSenderBalance = await wallet.provider.getBalance(wallet.address);
        const OPTS = { gasLimit: 500_000 };
        const amount = 100000n;
        expect(amount).to.be.lte(initialSenderBalance);
        const hbarTransfers = {
            transfers: [
                {
                    accountID: wallet.address,
                    amount: -amount,
                    isApproval: false,
                },
                {
                    accountID: recipient,
                    amount: amount,
                    isApproval: false,
                },
            ],
        };
        contract.connect(wallet);
        const tokensTransfers = [];
        const transaction = await contract['cryptoTransfer'](hbarTransfers, tokensTransfers, OPTS);
        await transaction.wait();

        // Wait to make sure that balance change is propagated
        await new Promise(resolve => setTimeout(resolve, 5000));
        expect(await wallet.provider.getBalance(wallet.address)).to.be.lt(initialSenderBalance);
    });
});
