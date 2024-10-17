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
const { getAddresses } = require('../src/hardhat-addresses');

describe('::hardhat-addresses', function () {

    it('should get addresses from HD Wallet configuration', function () {
        const hdWalletConfig = {
            initialIndex: 0,
            count: 20,
            path: "m/44'/60'/0'/0",
            passphrase: '',
            mnemonic: 'test test test test test test test test test test test junk',
            accountsBalance: '1',
        };
        const accounts = [
            '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
            '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
            '0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc',
            '0x90f79bf6eb2c4f870365e785982e1f101e93b906',
            '0x15d34aaf54267db7d7c367839aaf71a00a2c6a65',
            '0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc',
            '0x976ea74026e726554db657fa54763abd0c3a0aa9',
            '0x14dc79964da2c08b23698b3d3cc7ca32193d9955',
            '0x23618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8f',
            '0xa0ee7a142d267c1f36714e4a8f75612f20a79720',
            '0xbcd4042de499d14e55001ccbb24a551f3b954096',
            '0x71be63f3384f5fb98995898a86b02fb2426c5788',
            '0xfabb0ac9d68b0b445fb7357272ff202c5651694a',
            '0x1cbd3b2770909d4e10f157cabc84c7264073c9ec',
            '0xdf3e18d64bc6a983f673ab319ccae4f1a57c7097',
            '0xcd3b766ccdd6ae721141f452c550ca635964ce71',
            '0x2546bcd3c84621e976d8185a91a922ae77ecec30',
            '0xbda5747bfd65f08deb54cb465eb87d40e51b197e',
            '0xdd2fd4581271e230360230f9337d5c0430bf44c0',
            '0x8626f6940e2eb28930efb4cef49b2d1f2c9c1199'
        ];

        expect(getAddresses(hdWalletConfig)).to.be.deep.equal(accounts);
    });

    it('should get addresses from private keys', function () {
        const accounts = [
            { privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', balance: '1000' },
            { privateKey: '59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', balance: '1000' },
        ];

        expect(getAddresses(accounts)).to.be.deep.equal([
            '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
            '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        ]);
    });

});
