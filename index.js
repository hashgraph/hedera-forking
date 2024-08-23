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
        //   if (slot.type !== 't_string_storage' && !EthGetStorageAtService.BALANCES_ARRAY.includes(slot.label)) {
        //     continue;
        //   }
        const baseKeccak = BigInt(keccak256(`0x${utils.toIntHex256(slot.slot)}`));
        const offset = nrequestedSlot - baseKeccak;
        if (offset < 0 || offset > MAX_ELEMENTS) continue;

        return { slot, offset: Number(offset) };
    }

    return null;
}

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
     * 
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
        trace(logger, requestIdPrefix, `Getting storage for ${address} (tokenId=${tokenId}) at slot=${requestedSlot}`);

        const nrequestedSlot = BigInt(requestedSlot);

        const keccakedSlot = inferSlotAndOffset(nrequestedSlot);
        if (keccakedSlot !== null) {
            const getComplexElement = async (slot, tokenId, offset) => {
                // if (EthGetStorageAtService.BALANCES_ARRAY.includes(slot.label)) {
                //     const result: { balances: { account: string; balance: number }[] } =
                //         await this.mirrorNodeClient.getTokenBalances(address);
                //     const balances = result.balances;
                //     if (slot.label === 'balances') {
                //         return stringToIntHex256(`${balances[offset]?.balance ?? 0}`);
                //     }
                //     if (!balances[offset]?.account) {
                //         return HashZero.slice(2);
                //     }
                //     const account: { evm_address: string } = await this.mirrorNodeClient.getAccount(balances[offset].account);
                //     return account.evm_address.slice(2);
                // }
                const tokenData = await mirrorNodeClient.getTokenById(tokenId);
                const hexStr = Buffer.from(tokenData[utils.toSnakeCase(slot.label)]).toString('hex');
                const substr = hexStr.substring(offset * 64, (offset + 1) * 64);
                return substr.padEnd(64, '0');
            }
            const kecRes = `0x${(await getComplexElement(keccakedSlot.slot, tokenId, keccakedSlot.offset)).padStart(64, '0')}`;
            trace(logger, requestIdPrefix, `Get storage ${address} slot: ${requestedSlot}, result: ${kecRes}`);
            return kecRes;
        }

        const field = slotMap.get(nrequestedSlot);
        if (field === undefined) {
            trace(logger, requestIdPrefix, `Requested slot does not match any field slots, returning ${utils.ZERO_HEX_32_BYTE}`);
            return utils.ZERO_HEX_32_BYTE;
        }

        const tokenResult = await mirrorNodeClient.getTokenById(tokenId);
        const value = tokenResult[utils.toSnakeCase(field.label)];
        if (typeConverter[field.type] === undefined || !value) {
            trace(logger, requestIdPrefix, `Requested slot matches ${field.label} field, but it is not supported, returning ${utils.ZERO_HEX_32_BYTE}`);
            return utils.ZERO_HEX_32_BYTE;
        }

        return '0x' + typeConverter[field.type](value);
    },
};

//   BALANCES_ARRAY = ['holders', 'balances'];

//       // Slot === keccaked value (long strings, maps, arrays)

//       // Slot === decimal number (primitives)
//       const decimalSlotNumber = hexToDecimal(slotNumber);
//       const slots = allSlots.filter((search) => search.slot === decimalSlotNumber);
//       slots.sort((first, second) => first.offset - second.offset);
//       let result = '';
//       for (let slotOffsetIndex = 0; slotOffsetIndex < slots.length; slotOffsetIndex++) {
//         result = `${result}${await this.get(slots[slotOffsetIndex], address)}`;
//       }
//       this.logger.error(`Get storage ${address} slot: ${slotNumber}, result: 0x${result.padStart(64, '0')}`);

//       return `0x${result.padStart(64, '0')}`;
//     } catch (e: any) {
//       this.logger.error(`Error occurred when extracting a storage for an address ${address}: ${e.message}`);
//       return '';
//     }
//   }

//   private async get(slot: StorageSlot, address: string): Promise<string> {
//     if (EthGetStorageAtService.BALANCES_ARRAY.includes(slot.label)) {
//       const result: { balances: { account: string; balance: number }[] } =
//         await this.mirrorNodeClient.getTokenBalances(address);
//       return stringToIntHex256(`${result.balances.length}`);
//     }
//   }
// }
