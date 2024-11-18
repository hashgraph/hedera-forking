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
const { ZERO_HEX_32_BYTE, toIntHex256, toSnakeCase } = require('./utils');

const hts = require('../resources/HtsSystemContract.json');

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
 * @param {any} tuple
 * @param {{ [key: string]: (string | {[key: string]: string}) }} objTypes
 * @returns {string}
 */
const encodeTuple = (tuple, objTypes) => {
    return Object.entries(tuple)
        .map(([key, value]) => {
            const type = objTypes[key];
            // @ts-expect-error/TS7053
            const encodedValue = Array.isArray(type)
                ? typeConverter[type[0]](value, type[1])
                : typeConverter[type](value);
            if (!encodedValue) {
                console.log(JSON.stringify(tuple));
                throw new Error(`Failed to encode value for key \`${key}\` with type \`${type}\``);
            }
            console.log(
                `key: ${key}, value: ${value}, type: ${type}, encodedValue: ${encodedValue}`
            );
            return encodedValue;
        })
        .join('');
};

/**
 * @type {{
 * 't_string_storage': (value: string) => string,
 * 't_uint8': (value: string) => string,
 * 't_uint256': (value: string) => string,
 * 't_int64': (value: string) => string,
 * 't_bool': (value: boolean) => string,
 * 't_address': (value: string) => string,
 * 't_bytes': (value: string) => string,
 * 'tuple': (obj: any, objTypes: any) => string
 * 'tuple[]': (obj: any[], objTypes: any) => string
 * }}
 */
const typeConverter = {
    't_string_storage': str => {
        const [hexStr, lenByte] =
            str.length > 31
                ? ['0', str.length * 2 + 1]
                : [Buffer.from(str).toString('hex'), str.length * 2];

        return `${hexStr.padEnd(64 - 2, '0')}${lenByte.toString(16).padStart(2, '0')}`;
    },
    't_uint8': toIntHex256,
    't_uint256': toIntHex256,
    't_int64': toIntHex256,
    't_bool': value => (value ? toIntHex256('1') : toIntHex256('0')),
    't_address': value =>
        value ? value.replace('0x', '').padStart(64, '0') : ZERO_HEX_32_BYTE.replace('0x', ''),
    't_bytes': value => Buffer.from(value).toString('hex').padStart(64, '0'),
    'tuple': (tuple, objTypes) => {
        const empty32Bytes = ZERO_HEX_32_BYTE.replace('0x', '');
        try {
            if (!tuple || Object.keys(tuple).length === 0) return empty32Bytes;
            return encodeTuple(tuple, objTypes);
        } catch (error) {
            console.error(error);
            return empty32Bytes;
        }
    },
    'tuple[]': (tupleArr, objTypes) => {
        const empty32Bytes = ZERO_HEX_32_BYTE.replace('0x', '');
        try {
            if (!tupleArr || tupleArr.length === 0) return empty32Bytes;
            return tupleArr.map(tuple => encodeTuple(tuple, objTypes)).join('');
        } catch (error) {
            console.error(error);
            return empty32Bytes;
        }
    },
};

/**
 * @param {bigint} nrequestedSlot
 * @param {number=} MAX_ELEMENTS How many slots ahead to infer that `nrequestedSlot` is part of a given slot.
 * @returns {{slot: StorageSlot, offset: number}|null}
 */
function inferSlotAndOffset(nrequestedSlot, MAX_ELEMENTS = 100) {
    for (const slot of hts.storageLayout.storage) {
        const baseKeccak = BigInt(keccak256(`0x${toIntHex256(slot.slot)}`));
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
     * @param {import('./types').IMirrorNodeClient} mirrorNodeClient
     * @param {{ trace: (msg: string) => void }} logger
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

        if (!address.startsWith(module.exports.LONG_ZERO_PREFIX))
            return rtrace(
                null,
                `${address} does not start with \`${module.exports.LONG_ZERO_PREFIX}\``
            );

        const nrequestedSlot = BigInt(requestedSlot);

        if (address === module.exports.HTSAddress) {
            // Encoded `address(0x167).getAccountId(address)` slot
            // slot(256) = `getAccountId`selector(32) + padding(64) + address(160)
            if (nrequestedSlot >> 224n === 0xe0b490f7n) {
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
                        ZERO_HEX_32_BYTE,
                        `Requested address to account id, but shardNum in \`${account.account}\` is not zero`
                    );
                if (realmNum !== '0')
                    return rtrace(
                        ZERO_HEX_32_BYTE,
                        `Requested address to account id, but realmNum in \`${account.account}\` is not zero`
                    );

                return rtrace(
                    `0x${toIntHex256(accountId)}`,
                    `Requested address to account id, and slot matches \`getAccountId\``
                );
            }

            // Encoded `address(0x167).getTokenInfo(address)` slot
            // slot(256) = `getTokenInfo`selector(32) + padding(64) + address(160)
            if (nrequestedSlot >> 224n === 0x1f69565fn) {
                const encodedAddress = requestedSlot.slice(-40);
                const tokenId = `0.0.${parseInt(encodedAddress, 16)}`;
                const tokenResponse = await mirrorNodeClient.getTokenById(tokenId);
                if (tokenResponse === null)
                    return rtrace(
                        ZERO_HEX_32_BYTE,
                        `Requested address to token info, but token \`${tokenId}\` not found`
                    );

                const tokenInfo = await mapToTokenInfo(tokenResponse, mirrorNodeClient);
                return rtrace(
                    '0x' +
                        typeConverter['tuple'](tokenInfo, {
                            token: [
                                'tuple',
                                {
                                    name: 't_string_storage',
                                    symbol: 't_string_storage',
                                    treasury: 't_address',
                                    memo: 't_string_storage',
                                    tokenSupplyType: 't_bool',
                                    maxSupply: 't_uint256',
                                    freezeDefault: 't_bool',
                                    tokenKeys: [
                                        'tuple[]',
                                        {
                                            keyType: 't_uint8',
                                            key: [
                                                'tuple',
                                                {
                                                    inheritAccountKey: 't_bool',
                                                    contractId: 't_address',
                                                    ed25519: 't_bytes',
                                                    ECDSA_secp256k1: 't_bytes',
                                                    delegatableContractId: 't_address',
                                                },
                                            ],
                                        },
                                    ],
                                    expiry: [
                                        'tuple',
                                        {
                                            second: 't_uint256',
                                            autoRenewAccount: 't_address',
                                            autoRenewPeriod: 't_uint256',
                                        },
                                    ],
                                },
                            ],
                            totalSupply: 't_int64',
                            deleted: 't_bool',
                            defaultKycStatus: 't_bool',
                            pauseStatus: 't_bool',
                            fixedFees: [
                                'tuple[]',
                                {
                                    amount: 't_uint256',
                                    tokenId: 't_string_storage',
                                    useHbarsForPayment: 't_bool',
                                    useCurrentTokenForPayment: 't_bool',
                                    feeCollector: 't_address',
                                },
                            ],
                            fractionalFees: [
                                'tuple[]',
                                {
                                    numerator: 't_uint256',
                                    denominator: 't_uint256',
                                    minimumAmount: 't_uint256',
                                    maximumAmount: 't_uint256',
                                    netOfTransfers: 't_bool',
                                    feeCollector: 't_address',
                                },
                            ],
                            royaltyFees: [
                                'tuple[]',
                                {
                                    numerator: 't_uint256',
                                    denominator: 't_uint256',
                                    amount: 't_uint256',
                                    tokenId: 't_string_storage',
                                    useHbarsForPayment: 't_bool',
                                    feeCollector: 't_address',
                                },
                            ],
                            ledgerId: 't_string_storage',
                        }),
                    `Requested address to token info, and slot matches \`getTokenInfo\``
                );
            }

            return rtrace(ZERO_HEX_32_BYTE, `Requested slot for 0x167 matches field, not found`);
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
            const { balances } = (await mirrorNodeClient.getBalanceOfToken(
                tokenId,
                accountId,
                reqId
            )) ?? { balances: [] };
            if (balances.length === 0) return rtrace(ZERO_HEX_32_BYTE, 'Balance not found');

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
            const { allowances } = (await mirrorNodeClient.getAllowanceForToken(
                ownerId,
                tokenId,
                spenderId,
                reqId
            )) ?? { allowances: [] };

            if (allowances.length === 0)
                return rtrace(
                    ZERO_HEX_32_BYTE,
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
                    ZERO_HEX_32_BYTE,
                    `Requested slot matches keccaked slot but token was not found`
                );

            const offset = keccakedSlot.offset;
            const label = keccakedSlot.slot.label;
            const value = tokenData[toSnakeCase(label)];
            if (typeof value !== 'string')
                return rtrace(
                    ZERO_HEX_32_BYTE,
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
            return rtrace(ZERO_HEX_32_BYTE, `Requested slot does not match any field slots`);

        const tokenResult = await mirrorNodeClient.getTokenById(tokenId);
        if (tokenResult === null)
            return rtrace(
                ZERO_HEX_32_BYTE,
                `Requested slot matches ${slot.label} field, but token was not found`
            );

        const value = tokenResult[toSnakeCase(slot.label)];
        if (!(slot.type in typeConverter) || !value || typeof value !== 'string')
            return rtrace(
                ZERO_HEX_32_BYTE,
                `Requested slot matches ${slot.label} field, but it is not supported`
            );

        return rtrace(
            // @ts-expect-error/TS7053
            `0x${typeConverter[slot.type](value)}`,
            `Requested slot matches \`${slot.label}\` field (type=\`${slot.type}\`)`
        );

        /**
         * @param {import('./types/mirror-node').TokenResponse} tokenResponse
         * @param {import('./types').IMirrorNodeClient} mirrorNodeClient
         * @returns {Promise<import('./types/evm').TokenInfo>}
         */
        async function mapToTokenInfo(tokenResponse, mirrorNodeClient) {
            /**
             * @param {string | null} accountId
             * @returns {Promise<string>}
             */
            const getEvmAddress = async accountId => {
                if (!accountId) return '';
                const account = await mirrorNodeClient.getAccount(accountId);
                return account
                    ? account.evm_address.replace('0x', '')
                    : getLongZeroAddress(accountId);
            };

            /**
             * @param {string | null} entityId
             * @returns {string}
             */
            const getLongZeroAddress = entityId => {
                if (!entityId) return '';
                return `${BigInt(entityId.split('.')[2]).toString(16)}`;
            };

            /**
             * @param {import('./types/mirror-node').Key} key
             * @returns {import('./types/evm').KeyValue}
             */
            const getKeyValue = key => ({
                inheritAccountKey: false,
                contractId: '',
                ed25519: key?._type === 'ED25519' ? key.key.toString() : '',
                ECDSA_secp256k1: key?._type === 'ECDSA_SECP256K1' ? key.key.toString() : '',
                delegatableContractId: '',
            });

            /**
             * @type {import('./types/evm').HederaToken}
             */
            const token = {
                name: tokenResponse.name,
                symbol: tokenResponse.symbol,
                treasury: await getEvmAddress(tokenResponse.treasury_account_id),
                memo: tokenResponse.memo,
                tokenSupplyType: tokenResponse.supply_type === 'INFINITE',
                maxSupply: tokenResponse.max_supply,
                freezeDefault: tokenResponse.freeze_default,
                tokenKeys: [
                    { keyType: 1, key: getKeyValue(tokenResponse.admin_key) },
                    { keyType: 2, key: getKeyValue(tokenResponse.kyc_key) },
                    { keyType: 4, key: getKeyValue(tokenResponse.freeze_key) },
                    { keyType: 8, key: getKeyValue(tokenResponse.wipe_key) },
                    { keyType: 16, key: getKeyValue(tokenResponse.supply_key) },
                    { keyType: 32, key: getKeyValue(tokenResponse.pause_key) },
                ],
                expiry: {
                    second: tokenResponse.expiry_timestamp
                        ? parseInt(tokenResponse.expiry_timestamp)
                        : 0,
                    autoRenewAccount: tokenResponse.auto_renew_account,
                    autoRenewPeriod: tokenResponse.auto_renew_period
                        ? parseInt(tokenResponse.auto_renew_period)
                        : 0,
                },
            };

            /**
             * @type {import('./types/evm').FixedFee[]}
             */
            const fixedFees = await Promise.all(
                (tokenResponse.custom_fees.fixed_fees ?? []).map(async fee => ({
                    amount: fee.amount,
                    tokenId: getLongZeroAddress(fee.denominating_token_id),
                    useHbarsForPayment: fee.denominating_token_id === null,
                    useCurrentTokenForPayment: fee.denominating_token_id === tokenResponse.token_id,
                    feeCollector: await getEvmAddress(fee.collector_account_id),
                }))
            );

            /**
             * @type {import('./types/evm').FractionalFee[]}
             */
            const fractionalFees = await Promise.all(
                (tokenResponse.custom_fees.fractional_fees ?? []).map(async fee => ({
                    numerator: fee.amount.numerator,
                    denominator: fee.amount.denominator,
                    minimumAmount: fee.minimum,
                    maximumAmount: fee.maximum,
                    netOfTransfers: fee.net_of_transfers,
                    feeCollector: await getEvmAddress(fee.collector_account_id),
                }))
            );

            /**
             * @type {import('./types/evm').RoyaltyFee[]}
             */
            const royaltyFees = await Promise.all(
                (tokenResponse.custom_fees.royalty_fees ?? []).map(async fee => ({
                    numerator: fee.amount.numerator,
                    denominator: fee.amount.denominator,
                    amount: fee.fallback_fee.amount,
                    tokenId: getLongZeroAddress(fee.fallback_fee.denominating_token_id),
                    useHbarsForPayment: fee.fallback_fee.denominating_token_id === null,
                    feeCollector: await getEvmAddress(fee.collector_account_id),
                }))
            );

            return {
                token,
                totalSupply: tokenResponse.total_supply,
                deleted: tokenResponse.deleted,
                defaultKycStatus: false, // Assuming default KYC status is false as it's not provided in TokenResponse
                pauseStatus: tokenResponse.pause_status === 'PAUSED',
                fixedFees,
                fractionalFees,
                royaltyFees,
                ledgerId: '', // Assuming ledgerId is empty as it's not provided in TokenResponse
            };
        }
    },
};
