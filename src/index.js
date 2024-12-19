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

const { strict: assert } = require('assert');
const debug = require('util').debuglog('hts-forking');

const { ZERO_HEX_32_BYTE, toIntHex256 } = require('./utils');
const { slotMapOf, packValues } = require('./slotmap');
const { deployedBytecode } = require('../out/HtsSystemContract.sol/HtsSystemContract.json');

const HTSAddress = '0x0000000000000000000000000000000000000167';

const LONG_ZERO_PREFIX = '0x000000000000';

function getHIP719Code(/** @type {string} */ address) {
    const PLACEHOLDER = 'fefefefefefefefefefefefefefefefefefefefe';
    assert(/^0[xX][0-9a-fA-F]{40}$/.test(address), 'Address must be a valid EVM address');
    return require('./HIP719.bytecode.json').replace(PLACEHOLDER, address.slice(2));
}

function getHtsCode() {
    return deployedBytecode.object;
}

/**
 * @param {string} address
 * @param {string} requestedSlot
 * @param {number} blockNumber
 * @param {import('.').IMirrorNodeClient} mirrorNodeClient
 * @returns {Promise<string | null>}
 */
async function getHtsStorageAt(address, requestedSlot, blockNumber, mirrorNodeClient) {
    /** Logs `msg` and `return`s the provided `value`.
     *
     * @param {string|null} value
     * @param {string} msg
     * @returns {string|null}
     */
    const ret = (value, msg) => (debug(`${msg}, returning \`${value}\``), value);

    if (!address.startsWith(LONG_ZERO_PREFIX))
        return ret(null, `${address} does not start with \`${LONG_ZERO_PREFIX}\``);

    const nrequestedSlot = BigInt(requestedSlot);

    if (address === HTSAddress) {
        // Encoded `address(0x167).getAccountId(address)` slot
        // slot(256) = `getAccountId`selector(32) + padding(64) + address(160)
        if (nrequestedSlot >> 160n === 0xe0b490f7_0000_0000_0000_0000n) {
            const encodedAddress = requestedSlot.slice(-40);
            const account = await mirrorNodeClient.getAccount(encodedAddress, blockNumber);
            if (account === null)
                return ret(
                    `0x${requestedSlot.slice(-8).padStart(64, '0')}`,
                    `Requested address to account id, but address \`${encodedAddress}\` not found, use suffix as slot`
                );

            const [shardNum, realmNum, accountNum] = account.account.split('.');
            if (shardNum !== '0')
                return ret(ZERO_HEX_32_BYTE, `shardNum in \`${account.account}\` is not zero`);
            if (realmNum !== '0')
                return ret(ZERO_HEX_32_BYTE, `realmNum in \`${account.account}\` is not zero`);
            return ret(`0x${toIntHex256(accountNum)}`, 'address to accountNum');
        }

        return ret(ZERO_HEX_32_BYTE, `Requested slot for 0x167 matches field, not found`);
    }

    const tokenId = `0.0.${parseInt(address, 16)}`;
    debug(`Getting storage for \`${address}\` (tokenId=${tokenId}) at slot=${requestedSlot}`);

    // Encoded `address(tokenId).balanceOf(address)` slot
    // slot(256) = `balanceOf`selector(32) + padding(192) + accountId(32)
    if (
        nrequestedSlot >> 32n ===
        0x70a08231_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000n
    ) {
        const accountId = `0.0.${parseInt(requestedSlot.slice(-8), 16)}`;
        const { balances } = (await mirrorNodeClient.getBalanceOfToken(
            tokenId,
            accountId,
            blockNumber
        )) ?? { balances: [] };
        if (balances.length === 0) return ret(ZERO_HEX_32_BYTE, 'Balance not found');

        const value = balances[0].balance;
        return ret(`0x${value.toString(16).padStart(64, '0')}`, `${tokenId} balance ${accountId}`);
    }

    // Encoded `address(tokenId).allowance(owner, spender)` slot
    // slot(256) = `allowance`selector(32) + padding(160) + spenderId(32) + ownerId(32)
    if (nrequestedSlot >> 64n === 0xdd62ed3e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000n) {
        const ownerId = `0.0.${parseInt(requestedSlot.slice(-8), 16)}`;
        const spenderId = `0.0.${parseInt(requestedSlot.slice(-16, -8), 16)}`;
        const { allowances } = (await mirrorNodeClient.getAllowanceForToken(
            ownerId,
            tokenId,
            spenderId
        )) ?? { allowances: [] };

        if (allowances.length === 0)
            return ret(ZERO_HEX_32_BYTE, `${tokenId}.allowance(${ownerId},${spenderId}) not found`);
        const value = allowances[0].amount;
        return ret(
            `0x${value.toString(16).padStart(64, '0')}`,
            `Requested slot matches ${tokenId}.allowance(${ownerId},${spenderId})`
        );
    }

    // Encoded `address(tokenId).isAssociated()` slot
    // slot(256) = `isAssociated`selector(32) + padding(192) + accountId(32)
    if (
        nrequestedSlot >> 32n ===
        0x4d8fdd6d_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000n
    ) {
        const accountId = `0.0.${parseInt(requestedSlot.slice(-8), 16)}`;
        const { tokens } = (await mirrorNodeClient.getTokenRelationship(accountId, tokenId)) ?? {
            tokens: [],
        };
        if (tokens?.length > 0) {
            return ret(`0x${toIntHex256(1)}`, `Token ${tokenId} is associated with ${accountId}`);
        }
        return ret(ZERO_HEX_32_BYTE, `Token ${tokenId} not associated with ${accountId}`);
    }

    const token = await mirrorNodeClient.getTokenById(tokenId, blockNumber);
    if (token === null) return ret(ZERO_HEX_32_BYTE, `Token \`${tokenId}\` not found`);
    const unresolvedValues = slotMapOf(token).load(nrequestedSlot);
    if (unresolvedValues === undefined)
        return ret(ZERO_HEX_32_BYTE, `Requested slot does not match any field slots`);
    const values = await Promise.all(
        unresolvedValues.map(async ({ offset, path, value }) => ({
            offset,
            path,
            value: typeof value === 'function' ? await value(mirrorNodeClient, blockNumber) : value,
        }))
    );
    return ret(`0x${packValues(values)}`, `Slot matches ${values.map(v => v.path).join('|')}`);
}

module.exports = { HTSAddress, LONG_ZERO_PREFIX, getHIP719Code, getHtsCode, getHtsStorageAt };
