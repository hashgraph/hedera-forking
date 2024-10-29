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

const { HDKey } = require('ethereum-cryptography/hdkey');
const { mnemonicToSeedSync } = require('ethereum-cryptography/bip39');
const { privateToAddress } = require('@nomicfoundation/ethereumjs-util');

/**
 * Gets the public Ethereum address from the respective private key.
 *
 * @param {Uint8Array} pk the private key to convert.
 * @returns {string} the Ethereum address corresponding to the `pk` private key.
 */
const getEthAddress = pk => '0x' + Buffer.from(privateToAddress(pk)).toString('hex');

module.exports = {
    /**
     * Returns the addresses used by the Hardhat network from its `accounts` configuration.
     *
     * @param {import("hardhat/types").HardhatNetworkAccountsConfig} accounts
     * @returns {string[]}
     */
    getAddresses(accounts) {
        if (Array.isArray(accounts)) {
            return accounts.map(account =>
                getEthAddress(Buffer.from(account.privateKey.replace('0x', ''), 'hex'))
            );
        } else {
            const seed = mnemonicToSeedSync(accounts.mnemonic, accounts.passphrase);
            const masterKey = HDKey.fromMasterSeed(seed);

            const addresses = [];
            for (let i = accounts.initialIndex; i < accounts.count; i++) {
                const derived = masterKey.derive(`${accounts.path}/${i}`);
                if (derived.privateKey === null) continue;

                const address = getEthAddress(derived.privateKey);
                addresses.push(address);
            }

            return addresses;
        }
    },
};
