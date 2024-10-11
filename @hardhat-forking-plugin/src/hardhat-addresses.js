const { HDKey } = require('ethereum-cryptography/hdkey');
const { mnemonicToSeedSync } = require('ethereum-cryptography/bip39');
const { privateToAddress } = require("@nomicfoundation/ethereumjs-util");

/**
 * 
 * @param {Uint8Array} pk 
 * @returns {string}
 */
const toHexStrAddress = pk => '0x' + Buffer.from(privateToAddress(pk)).toString('hex');

module.exports = {

    /**
     * 
     * @param {import("hardhat/types").HardhatNetworkAccountsConfig} accounts 
     * @returns {string[]}
     */
    getAddresses(accounts) {
        if (Array.isArray(accounts)) {
            return accounts.map(account => toHexStrAddress(Buffer.from(account.privateKey.replace('0x', ''), 'hex')))
        } else {
            const seed = mnemonicToSeedSync(accounts.mnemonic, accounts.passphrase);
            const masterKey = HDKey.fromMasterSeed(seed);

            const addresses = [];
            for (let i = accounts.initialIndex; i < accounts.count; i++) {
                const derived = masterKey.derive(`${accounts.path}/${i}`);
                if (derived.privateKey === null) continue;

                const address = toHexStrAddress(derived.privateKey);
                addresses.push(address);
            }

            return addresses;
        }
    },
};