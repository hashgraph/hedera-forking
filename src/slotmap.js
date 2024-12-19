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
} = require('../out/HtsSystemContract.sol/HtsSystemContract.json');

/**
 * Represents the value in the `SlotMap`.
 * This can be either a `string`, or a function that returns a `string`.
 * The latter was introduced to support "lazy-loading" of values that
 * may require additional calls to the Mirror Node.
 *
 * See for example how `t_address` is converted in `_types`.
 *
 * @typedef {string | ((mirrorNode: Pick<import('.').IMirrorNodeClient, 'getAccount'>, blockNumber: number) => Promise<string>)} Value
 */

/**
 * Wrapper around a `Map` that holds the slot values for a given token.
 */
class SlotMap {
    constructor() {
        /** @type {Map<bigint, {offset: number, value: Value, path: string, type: string}[]>} */
        this._map = new Map();
    }

    /**
     * Sets `value` into `slot`.
     *
     * The slots cannot be modified,
     * so reassigning an already existing slot will throw an error.
     *
     * @param {bigint} slot
     * @param {number|null} offset
     * @param {Value} value
     * @param {string} path
     * @param {string} type
     */
    store(slot, offset, value, path, type) {
        let values = this._map.get(slot);
        if (offset === null) {
            if (values !== undefined)
                throw new Error(`Slot ${slot} used by ${JSON.stringify(values)}: ${value}@${path}`);
            this._map.set(slot, [{ offset: 0, value, path, type }]);
        } else {
            if (values === undefined) {
                values = [];
                this._map.set(slot, values);
            } else {
                if (values.find(val => val.offset === offset) !== undefined) {
                    throw new Error(`Slot ${slot}:${offset} used by ${JSON.stringify(values)}`);
                }
            }
            values.push({ offset, value, path, type });
        }
    }

    /**
     * @param {bigint} slot
     */
    load(slot) {
        return this._map.get(slot);
    }
}

/**
 * @param {{offset: number, value: string}[]} values
 * @returns {string}
 */
function packValues(values) {
    assert(values.length > 0, 'values must not be empty');

    let data = 0n;
    for (const { offset, value } of values) {
        const shifted = BigInt(`0x${value}`) << BigInt(offset * 8);
        data = data | shifted;
    }
    return toIntHex256(data);
}

/**
 * Table to convert Solidity primitive types into slot values.
 *
 * For types that may occupy more than one slot, _i.e._,
 * [`string` and `bytes`](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html#bytes-and-string),
 * a `Value[]` can be returned instead.
 * In this case, additional slot values will be stored starting from `keccak256(p)` where is `p` is the base slot.
 *
 * If a value needs to be "lazy-loaded", _e.g._, in case for `t_address`,
 * then a function that resolves to a `string` will be returned.
 * See `Value` for more details.
 *
 * @type {{[t_name: string]: (value: string) => Value[]}}
 */
const _types = {
    t_string_storage: function (str) {
        return this['t_bytes_storage'](Buffer.from(str).toString('hex'));
    },
    t_bytes_storage: hexstr => {
        const len = Buffer.from(hexstr, 'hex').length;
        const [header, lenByte, chunks] =
            len > 31
                ? [
                      '0',
                      len * 2 + 1,
                      [...Array(Math.ceil(len / 32)).keys()].map(i =>
                          hexstr.substring(i * 64, (i + 1) * 64).padEnd(64, '0')
                      ),
                  ]
                : [hexstr, len * 2, []];

        return [`${header.padEnd(64 - 2, '0')}${lenByte.toString(16).padStart(2, '0')}`, ...chunks];
    },
    t_uint8: val => [toIntHex256(val)],
    t_uint256: val => [toIntHex256(val)],
    t_int256: str => [toIntHex256(str ?? 0)],
    t_int64: str => [toIntHex256(str ?? 0)],
    t_address: str => [
        str
            ? (mirrorNode, blockNumber) =>
                  mirrorNode
                      .getAccount(str, blockNumber)
                      .then(acc => toIntHex256(acc?.evm_address ?? str?.replace('0.0.', '') ?? 0))
            : toIntHex256(0),
    ],
    t_bool: value => [toIntHex256(value ? 1 : 0)],
};

/**
 * Computes the storage slots starting from the given `slot` and
 * extracts the corresponding field from `obj` and stores it into `map`.
 *
 * When a `slot` is either a `struct` or an array,
 * it will visit its members or items recursively.
 *
 * Some `struct`s may contain "gap"s in their definitions.
 * These gaps are declared only to avoid packing multiple fields in the same storage slot.
 * These "gap" fields must start with `__gap` to avoid retrieving an inexisting value.
 *
 * @param {{label: string;slot: string;type: string; offset: number;}} slot the starting slot to compute storage slots.
 * @param {bigint} baseSlot the base slot that `slot` is instantiated from.
 * @param {Record<string, unknown>} obj the current object to extract values from. It may change when visiting arrays.
 * @param {string} path represents the current `path` to extract a primitive value.
 * @param {SlotMap} map the `SlotMap` used to store the computed values. This argument will remain invariant across recursive calls.
 */
function visit(slot, baseSlot, obj, path, map) {
    const computedSlot = BigInt(slot.slot) + baseSlot;
    path += `.${slot.label}`;
    const { label, type, offset } = slot;

    const ty = types[/**@type{keyof typeof types}*/ (type)];
    if ('members' in ty) {
        ty.members.forEach(s => visit(s, computedSlot, obj, path, map));
    } else if ('base' in ty) {
        const base = ty['base'];
        const arr = obj[toSnakeCase(label)];
        assert(Array.isArray(arr));

        map.store(computedSlot, null, toIntHex256(arr.length), `${path}{len}`, type);
        const baseKeccak = BigInt(keccak256(`0x${toIntHex256(computedSlot)}`));
        const { numberOfBytes } = types[/**@type{keyof typeof types}*/ (base)];
        assert(parseInt(numberOfBytes) % 32 === 0);
        arr.forEach((item, i) =>
            visit(
                { label: '_', type: base, slot: '0', offset: 0 },
                baseKeccak + BigInt(i) * (BigInt(numberOfBytes) / 32n),
                item,
                `${path}[${i}]`,
                map
            )
        );
    } else {
        const prop = obj[toSnakeCase(label)];
        const [value, ...chunks] = _types[type](/**@type{string}*/ (prop));
        map.store(computedSlot, offset, value, path, type);

        const baseKeccak = BigInt(keccak256(`0x${toIntHex256(computedSlot)}`));
        chunks.forEach((c, i) => map.store(baseKeccak + BigInt(i), null, c, `${path}{${i}}`, type));
    }
}

/**
 * Builds the `SlotMap` for the given `token`.
 * It uses the Solidity [storage layout](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html)
 * definition to build the slot map.
 *
 * It works in two phases.
 *
 * Firstly, it normalizes the `token` object.
 * This consist of
 * - normalizing some field names so that the Solidity definition matches the `token` object
 * - creating `token_keys` array to match Solidity definitions
 * - flattening top-level `structs`, _e.g._, `second`
 *
 * Secondly, it builds the actual `SlotMap` starting from the declared fields in the storage layout.
 *
 * @param {Record<string, unknown>} token
 * @returns {SlotMap}
 */
function slotMapOf(token) {
    token['token_type'] = token['type'];
    token['token_supply_type'] = token['supply_type'] === 'FINITE';
    token['default_kyc_status'] = false;
    // TODO: Decide what we will do with these hardcoded fields
    // token['contract_id'] = zeroAddress();
    // token['inherit_account_key'] = ZERO_HEX_32_BYTE;
    // token['delegatable_contract_id'] = zeroAddress();
    token['treasury'] = token['treasury_account_id'];
    token['ledger_id'] = '0x00';
    // Every inner `struct` will be flattened by `visit`,
    // so it uses the last part of the field path, _i.e._, `.second`.
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
    const customFees = /**@type {Record<string, Record<string, unknown>[]>}*/ (
        token['custom_fees']
    );
    token['fixed_fees'] = (customFees['fixed_fees'] ?? []).map(fee => ({
        fee_collector: fee['collector_account_id'],
        amount: fee['amount'],
        token_id: fee['denominating_token_id'],
        use_hbars_for_payment: !fee['denominating_token_id'],
        use_current_token_for_payment: fee['denominating_token_id'] === token['token_id'],
    }));
    token['fractional_fees'] = (customFees['fractional_fees'] ?? []).map(fee => ({
        net_of_transfers: fee['net_of_transfers'],
        numerator: /**@type{{numerator: unknown}}*/ (fee['amount'])['numerator'],
        denominator: /**@type{{denominator: unknown}}*/ (fee['amount'])['denominator'],
        minimum_amount: fee['minimum'],
        maximum_amount: fee['maximum'],
        fee_collector: fee['collector_account_id'],
    }));
    token['royalty_fees'] = customFees['royalty_fees'] ?? [];

    const map = new SlotMap();
    storage.forEach(slot => visit(slot, 0n, token, '', map));
    return map;
}

module.exports = { slotMapOf, packValues };
