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

const { toIntHex256, toSnakeCase } = require('./utils');
const {
    storageLayout: { storage, types },
} = require('../resources/HtsSystemContract.json');

class SlotMap {
    constructor() {
        /** @type {Map<bigint, {value: string, path: string, type: string}>} */
        this._map = new Map();
    }

    /**
     *
     * @param {bigint} slot
     * @param {string} value
     * @param {string} path
     * @param {string} type
     */
    store(slot, value, path, type) {
        const prev = this._map.get(slot);
        if (prev !== undefined)
            throw new Error(`Slot \`${slot}\` in use by ${JSON.stringify(prev)}: ${value}@${path}`);
        this._map.set(slot, { value: '0x' + value, path, type });
    }
}

/**
 * @type {{[t_name: string]: (value: string) => string | string[]}}
 */
const _typeConverter = {
    t_string_storage: function (str) {
        return this['t_bytes_storage'](Buffer.from(str).toString('hex'));
    },
    t_bytes_storage: str => {
        const len = Buffer.from(str, 'hex').length;
        const [chunk, lenByte, rest] =
            len > 31
                ? [
                      '0',
                      len * 2 + 1,
                      [...Array(Math.ceil(len / 32)).keys()].map(i =>
                          str.substring(i * 64, (i + 1) * 64).padEnd(64, '0')
                      ),
                  ]
                : [str, len * 2, []];

        return [`${chunk.padEnd(64 - 2, '0')}${lenByte.toString(16).padStart(2, '0')}`, ...rest];
    },
    t_uint8: toIntHex256,
    t_uint256: toIntHex256,
    t_int256: str => toIntHex256(str ?? 0),
    t_address: str => toIntHex256(str?.replace('0.0.', '') ?? 0),
    t_bool: value => toIntHex256(value ? 1 : 0),
};

/**
 * @param {Record<string, unknown>} token
 * @returns {Map<bigint, {value: string, path: string}>}
 */
function slotMapOf(token) {
    token['default_kyc_status'] = false;
    token['treasury'] = token['treasury_account_id'];
    token['ledger_id'] = '0x00';
    token['second'] = `${token['expiry_timestamp']}`;
    token['pause_status'] = token['pause_status'] === 'PAUSED';

    token['token_keys'] = /**@type {const}*/ ([
        ['admin_key', 0x1],
        ['kyc_key', 0x2],
        ['freeze_key', 0x4],
        ['wipe_key', 0x8],
        ['supply_key', 0x10],
        ['fee_schedule_key', 0x20],
        ['pause_key', 0x40],
    ]).map(([prop, key_type]) => {
        const key = token[prop];
        if (key === null) return { key_type, ed25519: '', _e_c_d_s_a_secp256k1: '' };
        assert(typeof key === 'object');
        assert('_type' in key && 'key' in key);
        if (key._type === 'ED25519')
            return { key_type, ed25519: key.key, _e_c_d_s_a_secp256k1: '' };
        return { key_type, ed25519: '', _e_c_d_s_a_secp256k1: key.key };
    });

    const customFees = /**@type {Record<string, unknown>}*/ (token['custom_fees']);
    token['fixed_fees'] = customFees['fixed_fees'] ?? [];
    token['fractional_fees'] = customFees['fractional_fees'] ?? [];
    token['royalty_fees'] = customFees['royalty_fees'] ?? [];

    const map = new SlotMap();

    /**
     * @param {{label: string, slot: string, type: string}} slot
     * @param {bigint} baseSlot
     * @param {Record<string, unknown>} obj
     * @param {string} path
     */
    function flatten(slot, baseSlot, obj, path) {
        const computedSlot = BigInt(slot.slot) + baseSlot;
        path += `.${slot.label}`;
        const { type } = slot;

        const ty = types[/**@type{keyof typeof types}*/ (type)];
        if ('members' in ty) {
            ty.members.forEach(s => flatten(s, computedSlot, obj, path));
        } else if ('base' in ty) {
            const base = ty['base'];
            const arr = obj[toSnakeCase(slot.label)];
            assert(Array.isArray(arr));

            map.store(computedSlot, toIntHex256(arr.length), `${path}{len}`, type);
            const baseKeccak = BigInt(keccak256(`0x${toIntHex256(computedSlot)}`));
            const { numberOfBytes } = types[/**@type{keyof typeof types}*/ (base)];
            assert(parseInt(numberOfBytes) % 32 === 0);
            arr.forEach((item, i) =>
                flatten(
                    { label: '_', type: base, slot: '0' },
                    baseKeccak + BigInt(i) * (BigInt(numberOfBytes) / 32n),
                    item,
                    `${path}[${i}]`
                )
            );
        } else {
            const prop = obj[toSnakeCase(slot.label)];
            const value = _typeConverter[slot.type](/**@type{string}*/ (prop));

            if (!Array.isArray(value)) {
                map.store(computedSlot, value, path, type);
            } else if (value.length === 1) {
                map.store(computedSlot, value[0], path, type);
            } else {
                const [x, ...xs] = value;
                map.store(computedSlot, x, `${path}{len}`, type);
                const baseKeccak = BigInt(keccak256(`0x${toIntHex256(computedSlot)}`));
                xs.forEach((x, i) => map.store(baseKeccak + BigInt(i), x, `${path}{${i}}`, type));
            }
        }
    }

    storage.forEach(slot => flatten(slot, 0n, token, ''));
    return map._map;
}

module.exports = { slotMapOf };
