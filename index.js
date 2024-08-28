const { keccak256, toUtf8Bytes } = require('ethers');
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
 * @type {{[t_name: string]: (value: string, offset: string|undefined|null) => string}}
 */
const typeConverter = {
    t_string_storage: (str, offset) => {
        if (typeof offset === 'undefined' || offset === null) {
            const [hexStr, lenByte] = str.length > 31
              ? ['0', str.length * 2 + 1]
              : [Buffer.from(str).toString('hex'), str.length * 2];
            return `${hexStr.padEnd(64 - 2, '0')}${lenByte.toString(16).padStart(2, '0')}`;
        }
        const hexStr = Buffer.from(str).toString('hex');
        const substr = hexStr.substring(offset * 64, (offset + 1) * 64);
        return substr.padEnd(64, '0');
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

// New approach - access storage slot directly! Looks like a simpler idea.
const fetchGetters = (mirrorNodeClient, logger, tokenId) => {
    return {
        'balanceOf(address)': async (address) => {
            const accountData = await mirrorNodeClient.getAccount(address);
            if (!accountData) {
                return utils.toIntHex256('0');
            }
            const tokenData = await mirrorNodeClient.getTokenById(tokenId);
            if (tokenData.type === 'NON_FUNGIBLE_COMMON') {
                const nfts = await mirrorNodeClient.getTokenNftsById(tokenId);
                return utils.toIntHex256(`${nfts.filter(nft => nft.account_id === accountData.account).length}`);
            }

            const { balances } = await mirrorNodeClient.getBalanceOfToken(tokenId, accountData.account);
            return utils.toIntHex256(`${balances[0]?.balance || 0}`);
        },
    }
};
const get = async (requestedSlot, getters) => {
    for (const [key, value] of Object.entries(getters)) {
        if (requestedSlot.startsWith(keccak256(toUtf8Bytes(key)).substring(0, 10))) {
            return await value(`0x${requestedSlot.slice(-40)}`);
        }
    }

    return null;
};
// End new approach. WIP

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
            if (!balances[offset]?.account) {
                return '0'.padStart(64, '0');
            }
            const account = await mirrorNodeClient.getAccount(balances[offset]?.account);
            return account.evm_address.slice(2).padStart(64, '0');
        },
        tokenIds: async (offset) => {
            const result = await mirrorNodeClient.getTokenNftsById(tokenId);
            if (offset === null) return utils.toIntHex256(`${result.nfts.length}`);
            return utils.toIntHex256(`${result.nfts[offset]?.serial_number}`);
        },
        owners: async (offset) => {
            const result = await mirrorNodeClient.getTokenNftsById(tokenId);
            if (offset === null) return utils.toIntHex256(`${result.nfts.length}`);
            const nfts = result.nfts;
            if (!nfts[offset]?.account_id) {
                return '0'.padStart(64, '0');
            }
            const account = await mirrorNodeClient.getAccount(nfts[offset]?.account_id);
            return account.evm_address.slice(2).padStart(64, '0');
        },
        tokenType: async (offset) => {
            const result = await mirrorNodeClient.getTokenById(tokenId);
            return typeConverter.t_string_storage(result.type, offset);
        },
    };
};

/**
 * @param {import('pino').Logger} logger
 * @param {string} requestIdPrefix
 * @param {string} msg
 */
const trace = (logger, requestIdPrefix, msg) => logger.trace(`${requestIdPrefix} (hedera-forking) ${msg}`);

module.exports = {
    getHtsCode() {
        return hts.deployedBytecode.object;
    },

    /**
     * @param {string} address
     * @param {string} requestedSlot
     * @param {import(".").IMirrorNodeClient} mirrorNodeClient
     * @param {import("pino").Logger=} logger
     * @param {string=} requestIdPrefix
     * @returns {Promise<string | null>}
     */
    async getHtsStorageAt(address, requestedSlot, mirrorNodeClient, logger = { trace: () => undefined }, requestIdPrefix) {
        if (!address.startsWith(utils.LONG_ZERO_PREFIX)) {
            trace(logger, requestIdPrefix, `${address} does not start with ${utils.LONG_ZERO_PREFIX}, returning null`);
            return null;
        }

        const tokenId = `0.0.${parseInt(address, 16)}`;
        logger.error(requestedSlot);
        const result = await get(requestedSlot, fetchGetters(mirrorNodeClient, logger, tokenId));
        if (result !== null) {
            return `0x${result}`;
        }

        const fetcher = dataFetcher(mirrorNodeClient, tokenId);

        trace(logger, requestIdPrefix, `Getting storage for ${address} (tokenId=${tokenId}) at slot=${requestedSlot}`);

        const nrequestedSlot = BigInt(requestedSlot);

        const keccakedSlot = inferSlotAndOffset(nrequestedSlot);
        if (keccakedSlot !== null) {
            const getComplexElement = async (slot, tokenId, offset) => {
                if (fetcher[slot.label] !== undefined) {
                    return await fetcher[slot.label](offset);
                }
                const tokenData = await mirrorNodeClient.getTokenById(tokenId);
                return typeConverter.t_string_storage(tokenData[utils.toSnakeCase(slot.label)], offset);
            }
            const kecRes = await getComplexElement(keccakedSlot.slot, tokenId, keccakedSlot.offset);
            trace(logger, requestIdPrefix, `Get storage ${address} slot: ${requestedSlot}, result: ${kecRes}`);
            return `0x${kecRes}`;
        }

        const slot = slotMap.get(nrequestedSlot);
        if (slot === undefined) {
            trace(logger, requestIdPrefix, `Requested slot does not match any field slots, returning ${utils.ZERO_HEX_32_BYTE}`);
            return utils.ZERO_HEX_32_BYTE;
        }

        if (fetcher[slot.label] !== undefined) {
            return `0x${await fetcher[slot.label](null)}`;
        }

        const tokenResult = await mirrorNodeClient.getTokenById(tokenId);
        const value = tokenResult[utils.toSnakeCase(slot.label)];
        if (typeConverter[slot.type] === undefined || !value) {
            trace(logger, requestIdPrefix, `Requested slot matches ${slot.label} field, but it is not supported, returning ${utils.ZERO_HEX_32_BYTE}`);
            return utils.ZERO_HEX_32_BYTE;
        }

        return `0x${typeConverter[slot.type](value)}`;
    },
};
