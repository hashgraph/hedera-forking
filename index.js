const { keccak256 } = require('ethers');
const utils = require('./utils');

const hts = require('./out/HtsSystemContract.sol/HtsSystemContract.json');
/**
 * Represents a slot entry in `storageLayout.storage`.
 *
 * @typedef {{ slot: string, offset: number, type: string, label: string }} StorageSlot
 */

/**
 * @type {Map<bigint, StorageSlot>}
 */
const slotMap = function (slotMap) {
    for (const slot of hts.storageLayout.storage) {
        slotMap.set(BigInt(slot.slot), slot);
    }
    return slotMap;
}(new Map());

/**
 * @type {{[t_name: string]: (value: string) => string}}
 */
const typeConverter = {
    t_string_storage: str => {
        const [hexStr, lenByte] = str.length > 31
            ? ['0', str.length * 2 + 1]
            : [Buffer.from(str).toString('hex'), str.length * 2];

        return `${hexStr.padEnd(64 - 2, '0')}${lenByte.toString(16).padStart(2, '0')}`;
    },
    t_uint8: utils.toIntHex256,
    t_uint256: utils.toIntHex256,
};

/**
 *
 * @param {import("pino").Logger} logger
 * @param {string=} requestIdPrefix
 */

/**
 * @param {bigint} nrequestedSlot
 * @param {bigint} MAX_ELEMENTS How many slots ahead to infer that `nrequestedSlot` is part of a given slot.
 * @returns {{slot: StorageSlot, offset: bigint}|null}
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

/**
 * Primitives with the same name in the tokenData structure from both the MirrorNode and the Smart Contract
 * are supported by default. Use this fetcher to override the default behavior, especially when dealing with arrays.
 * When offset is null, the fetcher should retrieve data for the slot.
 * If offset is not null, it should return values for the array at the specified index (offset).
 *
 * @param {import(".").IMirrorNodeClient} mirrorNodeClient
 * @param {string} tokenId
 * @returns {{[slot_label: string]: (value: string) => Promise<string>}}
 */
const dataFetcher = (mirrorNodeClient, tokenId) => {
    return {
        balances: async (offset) => {
            const result = await mirrorNodeClient.getTokenBalancesById(tokenId);
            if (offset === null) return utils.toIntHex256(`${result.balances.length}`);
            const balances = result.balances;
            return utils.toIntHex256(`${balances[offset]?.balance ?? 0}`);
        },
        holders: async (offset) => {
            const result = await mirrorNodeClient.getTokenBalancesById(tokenId);
            if (offset === null) return utils.toIntHex256(`${result.balances.length}`);
            const balances = result.balances;
            const account = await mirrorNodeClient.getAccount(balances[offset].account);
            return account.evm_address.slice(2).padStart(64, '0');
        },
    };
};

/**
 * Wrapper trace logger to include origin `(hedera-forking)` in the log entry.
 * 
 * @param {import('pino').Logger} logger
 * @param {string} reqId
 * @param {string} msg
 */
const trace = (logger, reqId, msg) => logger.trace(`${reqId} (hedera-forking) ${msg}`);

module.exports = {
    getHtsCode() {
        return hts.deployedBytecode.object;
    },

    /**
     * @param {string} address
     * @param {string} requestedSlot
     * @param {import(".").IMirrorNodeClient} mirrorNodeClient
     * @param {import("pino").Logger=} logger
     * @param {string=} reqId
     * @returns {Promise<string | null>}
     */
    async getHtsStorageAt(address, requestedSlot, mirrorNodeClient, logger = { trace: () => undefined }, reqId) {
        /**
         * Logs `msg` and `return`s the provided `value`.
         * 
         * @param {string|null} value 
         * @param {string} msg 
         * @returns {string|null} The `value` provided
         */
        const rtrace = (value, msg) => (trace(logger, reqId, `${msg}, returning \`${value}\``),
            value === null ?
                null :
                `0x${utils.toIntHex256(value)}`
        );

        if (!address.startsWith(utils.LONG_ZERO_PREFIX)) {
            trace(logger, reqId, `${address} does not start with ${utils.LONG_ZERO_PREFIX}, returning null`);
            return null;
        }

        const nrequestedSlot = BigInt(requestedSlot);

        if (address === utils.HTSAddress) {
            trace(logger, reqId, 'nreqid' + (nrequestedSlot >> 224n).toString(16));
            if (nrequestedSlot >> 160n === 0xe0b490f7_0000000000000000n) {
                const encodedAddress = requestedSlot.slice(-40);
                const account = await mirrorNodeClient.getAccount(encodedAddress);
                const [shardNum, realmNum, accountId] = account.account.split('.');
                if (shardNum !== '0') return rtrace(utils.ZERO_HEX_32_BYTE, 'shardNum is not zero');
                if (realmNum !== '0') return rtrace(utils.ZERO_HEX_32_BYTE, 'realNum is not zero');
                return rtrace(accountId, `Requested address is 0x167 and slot matches \`getAccountId\``);
            }

            trace(logger, reqId, `Requested slot for 0x167 matches field, not found returning \`ZERO_HEX_32_BYTE\``);
            return utils.ZERO_HEX_32_BYTE;
        }

        const tokenId = `0.0.${parseInt(address, 16)}`;
        const fetcher = dataFetcher(mirrorNodeClient, tokenId);

        trace(logger, reqId, `Getting storage for ${address} (tokenId=${tokenId}) at slot=${requestedSlot}`);

        // 28 * 8 = 224
        // 00 00 00 00 
        // Encoded `balanceOf` slot
        if (nrequestedSlot >> 32n === 0x70a08231_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000n) {
            const accountId = `0.0.${parseInt(requestedSlot.slice(-8), 16)}`;
            const { balances } = await mirrorNodeClient.getBalanceOfToken(tokenId, accountId, reqId);
            if (balances.length === 0) return rtrace(utils.ZERO_HEX_32_BYTE, 'Balances not found');

            const balance = balances[0].balance;
            trace(logger, reqId, `Requested slot matches \`balanceOf\` slot`);
            return `0x${balance.toString(16).padStart(64, '0')}`;
        }

        const keccakedSlot = inferSlotAndOffset(nrequestedSlot);
        if (keccakedSlot !== null) {
            const getComplexElement = async (slot, tokenId, offset) => {
                if (fetcher[slot.label] !== undefined) {
                    return await fetcher[slot.label](offset);
                }
                const tokenData = await mirrorNodeClient.getTokenById(tokenId);
                if (tokenData === null) {
                    trace(logger, reqId, `Requested slot matches keccaked slot but token was not found, returning \`ZERO_HEX_32_BYTE\``);
                    return utils.ZERO_HEX_32_BYTE.slice(2);
                }
                const hexStr = Buffer.from(tokenData[utils.toSnakeCase(slot.label)]).toString('hex');
                const substr = hexStr.substring(offset * 64, (offset + 1) * 64);
                return substr.padEnd(64, '0');
            }
            const kecRes = await getComplexElement(keccakedSlot.slot, tokenId, keccakedSlot.offset);
            trace(logger, reqId, `Get storage ${address} slot: ${requestedSlot}, result: ${kecRes}`);
            return `0x${kecRes}`;
        }

        const slot = slotMap.get(nrequestedSlot);
        if (slot === undefined) {
            trace(logger, reqId, `Requested slot does not match any field slots, returning \`ZERO_HEX_32_BYTE\``);
            return utils.ZERO_HEX_32_BYTE;
        }

        if (fetcher[slot.label] !== undefined) {
            return `0x${await fetcher[slot.label](null)}`;
        }

        const tokenResult = await mirrorNodeClient.getTokenById(tokenId);
        if (tokenResult === null) {
            trace(logger, reqId, `Requested slot matches ${slot.label} field, but token was not found, returning \`ZERO_HEX_32_BYTE\``);
            return utils.ZERO_HEX_32_BYTE;
        }

        const value = tokenResult[utils.toSnakeCase(slot.label)];
        if (typeConverter[slot.type] === undefined || !value) {
            trace(logger, reqId, `Requested slot matches ${slot.label} field, but it is not supported, returning \`ZERO_HEX_32_BYTE\``);
            return utils.ZERO_HEX_32_BYTE;
        }

        return `0x${typeConverter[slot.type](value)}`;
    },
};
