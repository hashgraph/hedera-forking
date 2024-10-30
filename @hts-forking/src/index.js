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
const utils = require('./utils');

const hts = require('../out/HtsSystemContract.sol/HtsSystemContract.json');

/**
 * Represents a slot entry in `storageLayout.storage`.
 *
 * @typedef {{ slot: string, offset: number, type: string, label: string }} StorageSlot
 */

/**
 * @type {Map<bigint, StorageSlot>}
 */
const slotMap = (function (slotMap) {
    for (const slot of hts.storageLayout.storage) {
        slotMap.set(BigInt(slot.slot), slot);
    }
    return slotMap;
})(new Map());

/**
 * @type {{[t_name: string]: (value: string) => string}}
 */
const typeConverter = {
    t_string_storage: str => {
        const [hexStr, lenByte] =
            str.length > 31
                ? ['0', str.length * 2 + 1]
                : [Buffer.from(str).toString('hex'), str.length * 2];

        return `${hexStr.padEnd(64 - 2, '0')}${lenByte.toString(16).padStart(2, '0')}`;
    },
    t_uint8: utils.toIntHex256,
    t_uint256: utils.toIntHex256,
};

/**
 * @param {bigint} nrequestedSlot
 * @param {number=} MAX_ELEMENTS How many slots ahead to infer that `nrequestedSlot` is part of a given slot.
 * @returns {{slot: StorageSlot, offset: number}|null}
 */
function inferSlotAndOffset(nrequestedSlot, MAX_ELEMENTS = 100) {
    for (const slot of hts.storageLayout.storage) {
        const baseKeccak = BigInt(keccak256(`0x${utils.toIntHex256(slot.slot)}`));
        const offset = nrequestedSlot - baseKeccak;
        if (offset < 0 || offset > MAX_ELEMENTS) continue;
        return { slot, offset: Number(offset) };
    }

    return null;
}

module.exports = {
    HTSAddress: '0x0000000000000000000000000000000000000167',

    LONG_ZERO_PREFIX: '0x000000000000',

    /**
     * @param {string} address
     */
    getHIP719Code(address) {
        const templateCode = require('./HIP719.bytecode.json');
        assert(address.startsWith('0x'), `address must start with \`0x\` prefix: ${address}`);
        assert(address.length === 2 + 40, `address must be a valid Ethereum address: ${address}`);
        return templateCode.replace('fefefefefefefefefefefefefefefefefefefefe', address.slice(2));
    },

    getHtsCode() {
        return hts.deployedBytecode.object;
    },

    /**
     * @param {string} address
     * @param {string} requestedSlot
     * @param {import(".").IMirrorNodeClient} mirrorNodeClient
     * @param {import("pino").Logger} logger
     * @param {string=} reqId
     * @returns {Promise<string | null>}
     */
    async getHtsStorageAt(address, requestedSlot, mirrorNodeClient, logger, reqId) {
        /** Wrapper trace logger to include origin `(hedera-forking)` in the log entry.
         *
         * @param {string} msg
         */
        const trace = msg => logger.trace(`${reqId} (hedera-forking) ${msg}`);
        /** Logs `msg` and `return`s the provided `value`.
         *
         * @param {string|null} value
         * @param {string} msg
         * @returns {string|null}
         */
        const rtrace = (value, msg) => (trace(`${msg}, returning \`${value}\``), value);

        if (!address.startsWith(exports.LONG_ZERO_PREFIX))
            return rtrace(null, `${address} does not start with \`${exports.LONG_ZERO_PREFIX}\``);

        const nrequestedSlot = BigInt(requestedSlot);

        if (address === exports.HTSAddress) {
            // Encoded `address(0x167).getAccountId(address)` slot
            // slot(256) = `getAccountId`selector(32) + padding(64) + address(160)
            if (nrequestedSlot >> 160n === 0xe0b490f7_0000_0000_0000_0000n) {
                const encodedAddress = requestedSlot.slice(-40);
                const account = await mirrorNodeClient.getAccount(encodedAddress);
                if (account === null)
                    return rtrace(
                        `0x${requestedSlot.slice(-8).padStart(64, '0')}`,
                        `Requested address to account id, but address \`${encodedAddress}\` not found, use suffix as slot`
                    );

                const [shardNum, realmNum, accountId] = account.account.split('.');
                if (shardNum !== '0')
                    return rtrace(
                        utils.ZERO_HEX_32_BYTE,
                        `Requested address to account id, but shardNum in \`${account.account}\` is not zero`
                    );
                if (realmNum !== '0')
                    return rtrace(
                        utils.ZERO_HEX_32_BYTE,
                        `Requested address to account id, but realmNum in \`${account.account}\` is not zero`
                    );

                return rtrace(
                    `0x${utils.toIntHex256(accountId)}`,
                    `Requested address to account id, and slot matches \`getAccountId\``
                );
            }

            return rtrace(
                utils.ZERO_HEX_32_BYTE,
                `Requested slot for 0x167 matches field, not found`
            );
        }

        const tokenId = `0.0.${parseInt(address, 16)}`;
        trace(`Getting storage for \`${address}\` (tokenId=${tokenId}) at slot=${requestedSlot}`);

        // Encoded `address(tokenId).balanceOf(address)` slot
        // slot(256) = `balanceOf`selector(32) + padding(192) + accountId(32)
        if (
            nrequestedSlot >> 32n ===
            0x70a08231_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000n
        ) {
            const accountId = `0.0.${parseInt(requestedSlot.slice(-8), 16)}`;
            const { balances } = await mirrorNodeClient.getBalanceOfToken(
                tokenId,
                accountId,
                reqId
            );
            if (balances.length === 0) return rtrace(utils.ZERO_HEX_32_BYTE, 'Balance not found');

            const value = balances[0].balance;
            return rtrace(
                `0x${value.toString(16).padStart(64, '0')}`,
                `Requested slot matches \`${tokenId}.balanceOf(${accountId})\``
            );
        }

        // Encoded `address(tokenId).allowance(owner, spender)` slot
        // slot(256) = `allowance`selector(32) + padding(160) + spenderId(32) + ownerId(32)
        if (
            nrequestedSlot >> 64n ===
            0xdd62ed3e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000n
        ) {
            const ownerId = `0.0.${parseInt(requestedSlot.slice(-8), 16)}`;
            const spenderId = `0.0.${parseInt(requestedSlot.slice(-16, -8), 16)}`;
            const { allowances } = await mirrorNodeClient.getAllowanceForToken(
                ownerId,
                tokenId,
                spenderId,
                reqId
            );

            if (allowances.length === 0)
                return rtrace(
                    utils.ZERO_HEX_32_BYTE,
                    `Allowance of token ${tokenId} from ${ownerId} assigned to ${spenderId} not found`
                );
            const value = allowances[0].amount;
            return rtrace(
                `0x${value.toString(16).padStart(64, '0')}`,
                `Requested slot matches \`${tokenId}.allowance(${ownerId}, ${spenderId})\``
            );
        }

        const keccakedSlot = inferSlotAndOffset(nrequestedSlot);
        if (keccakedSlot !== null) {
            const tokenData = await mirrorNodeClient.getTokenById(tokenId);
            if (tokenData === null)
                return rtrace(
                    utils.ZERO_HEX_32_BYTE,
                    `Requested slot matches keccaked slot but token was not found`
                );

            const offset = keccakedSlot.offset;
            const label = keccakedSlot.slot.label;
            const value = tokenData[utils.toSnakeCase(label)];
            if (typeof value !== 'string')
                return rtrace(
                    utils.ZERO_HEX_32_BYTE,
                    `Requested slot matches keccaked slot but its field \`${label}\` was not found in token or it is not a string`
                );
            const hexStr = Buffer.from(value).toString('hex');
            const kecRes = hexStr.substring(offset * 64, (offset + 1) * 64).padEnd(64, '0');
            return rtrace(
                `0x${kecRes}`,
                `Get storage ${address} slot: ${requestedSlot}, result: ${kecRes}`
            );
        }
        const slot = slotMap.get(nrequestedSlot);
        if (slot === undefined)
            return rtrace(utils.ZERO_HEX_32_BYTE, `Requested slot does not match any field slots`);

        const tokenResult = await mirrorNodeClient.getTokenById(tokenId);
        if (tokenResult === null)
            return rtrace(
                utils.ZERO_HEX_32_BYTE,
                `Requested slot matches ${slot.label} field, but token was not found`
            );

        const value = tokenResult[utils.toSnakeCase(slot.label)];
        if (typeConverter[slot.type] === undefined || !value || typeof value !== 'string')
            return rtrace(
                utils.ZERO_HEX_32_BYTE,
                `Requested slot matches ${slot.label} field, but it is not supported`
            );

        return rtrace(
            `0x${typeConverter[slot.type](value)}`,
            `Requested slot matches \`${slot.label}\` field (type=\`${slot.type}\`)`
        );
    },
};
