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
const { keccak256 } = require('ethers');
const debug = require('util').debuglog('hts-forking');

const { ZERO_HEX_32_BYTE, toIntHex256, toSnakeCase } = require('./utils');
const { storageLayout, deployedBytecode } = require('../resources/HtsSystemContract.json');

/**
 * Represents a slot entry in `storageLayout.storage`.
 *
 * @typedef {{ slot: string, offset: number, type: string, label: string }} StorageSlot
 */

/**
 * @type {Map<bigint, StorageSlot>}
 */
const _slotMap = storageLayout.storage.reduce(
    (slotMap, slot) => slotMap.set(BigInt(slot.slot), slot),
    new Map()
);

/**
 * @type {{[t_name: string]: (value: string) => string}}
 */
const _typeConverter = {
    t_string_storage: str => {
        const [hexStr, lenByte] =
            str.length > 31
                ? ['0', str.length * 2 + 1]
                : [Buffer.from(str).toString('hex'), str.length * 2];

        return `${hexStr.padEnd(64 - 2, '0')}${lenByte.toString(16).padStart(2, '0')}`;
    },
    t_uint8: toIntHex256,
    t_uint256: toIntHex256,
};

/**
 * @param {bigint} nrequestedSlot
 * @param {number=} MAX_ELEMENTS How many slots ahead to infer that `nrequestedSlot` is part of a given slot.
 * @returns {{slot: StorageSlot, offset: number}|null}
 */
function _inferSlotAndOffset(nrequestedSlot, MAX_ELEMENTS = 100) {
    for (const slot of storageLayout.storage) {
        const baseKeccak = BigInt(keccak256(`0x${toIntHex256(slot.slot)}`));
        const offset = nrequestedSlot - baseKeccak;
        if (offset < 0 || offset > MAX_ELEMENTS) continue;
        return { slot, offset: Number(offset) };
    }

    return null;
}

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
    if (nrequestedSlot >> 224n === 0x4d8fdd6dn) {
        const accountId = `0.0.${parseInt(requestedSlot.slice(-8), 16)}`;
        const { tokens } = (await mirrorNodeClient.getTokenRelationship(accountId, tokenId)) ?? {
            tokens: [],
        };
        if (tokens.some(t => t.token_id === tokenId)) {
            return ret(
                `0x${Number(1).toString(16).padStart(64, '0')}`,
                `Token ${tokenId} is associated with ${accountId}`
            );
        }
        return ret(ZERO_HEX_32_BYTE, `Token ${tokenId} not associated with ${accountId}`);
    }

    const keccakedSlot = _inferSlotAndOffset(nrequestedSlot);
    if (keccakedSlot !== null) {
        const tokenData = await mirrorNodeClient.getTokenById(tokenId, blockNumber);
        if (tokenData === null)
            return ret(ZERO_HEX_32_BYTE, `Slot matches keccaked slot but token was not found`);

        const offset = keccakedSlot.offset;
        const label = keccakedSlot.slot.label;
        const value = tokenData[toSnakeCase(label)];
        if (typeof value !== 'string')
            return ret(ZERO_HEX_32_BYTE, `Slot is keccaked slot but field ${label} was not found`);
        const hexStr = Buffer.from(value).toString('hex');
        const kecRes = hexStr.substring(offset * 64, (offset + 1) * 64).padEnd(64, '0');
        return ret(`0x${kecRes}`, `Get storage ${address} slot:${requestedSlot}, result:${kecRes}`);
    }
    const slot = _slotMap.get(nrequestedSlot);
    if (slot === undefined)
        return ret(ZERO_HEX_32_BYTE, `Requested slot does not match any field slots`);

    const tokenResult = await mirrorNodeClient.getTokenById(tokenId, blockNumber);
    if (tokenResult === null)
        return ret(ZERO_HEX_32_BYTE, `Slot matches ${slot.label} field, but token was not found`);

    const value = tokenResult[toSnakeCase(slot.label)];
    if (_typeConverter[slot.type] === undefined || !value || typeof value !== 'string')
        return ret(ZERO_HEX_32_BYTE, `Slot matches ${slot.label} field, but it is not supported`);

    return ret(`0x${_typeConverter[slot.type](value)}`, `Slot matches ${slot.label}: ${slot.type}`);
}

module.exports = { HTSAddress, LONG_ZERO_PREFIX, getHIP719Code, getHtsCode, getHtsStorageAt };
