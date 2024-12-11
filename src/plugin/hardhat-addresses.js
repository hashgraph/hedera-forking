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
const getEvmAddress = pk => '0x' + Buffer.from(privateToAddress(pk)).toString('hex');

module.exports = {
    /**
     * Returns the addresses used by the Hardhat network from its `accounts` configuration.
     * Using the default Hardhat configuration,
     * this function returns the list of
     * [initial addresses](https://hardhat.org/hardhat-network/docs/reference#initial-state) used by Hardhat Network.
     *
     * Calling the `eth_accounts` method on the Hardhat provider would return the same result.
     * However, we need a **sync** method to resolve the addresses given how Hardhat `require` works.
     *
     * The implementation was taken from
     * [here](https://github.com/NomicFoundation/hardhat/blob/1c491eb9fc8b399e480aa257d0f0832f66440be1/packages/hardhat-core/src/internal/util/keys-derivation.ts#L25-L26) and
     * [here](https://github.com/NomicFoundation/hardhat/blob/1c491eb9fc8b399e480aa257d0f0832f66440be1/packages/hardhat-core/src/internal/core/providers/util.ts#L29-L44).
     *
     * @param {import("hardhat/types").HardhatNetworkAccountsConfig} accounts
     * @returns {string[]}
     */
    getAddresses(accounts) {
        if (Array.isArray(accounts)) {
            return accounts.map(account =>
                getEvmAddress(Buffer.from(account.privateKey.replace('0x', ''), 'hex'))
            );
        } else {
            const seed = mnemonicToSeedSync(accounts.mnemonic, accounts.passphrase);
            const masterKey = HDKey.fromMasterSeed(seed);

            const addresses = [];
            for (let i = accounts.initialIndex; i < accounts.count; i++) {
                const derived = masterKey.derive(`${accounts.path}/${i}`);
                if (derived.privateKey === null) continue;

                const address = getEvmAddress(derived.privateKey);
                addresses.push(address);
            }

            return addresses;
        }
    },
};
