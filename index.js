const { keccak256 } = require('ethers');

const hts = require('./out/HtsSystemContract.sol/HtsSystemContract.json');

/**
 * Represents a slot entry in `storageLayout.storage`.
 * 
 * @typedef {{ slot: string, offset: number, type: string, label: string }} StorageSlot 
 */

let slotMap = undefined;

/**
 * 
 */
const ZERO_HEX_32_BYTE = '0x0000000000000000000000000000000000000000000000000000000000000000';

/**
 * 
 */
const LONG_ZERO_PREFIX = '0x000000000000';


/**
 * @param {string} value 
 * @returns {string}
 */
const toIntHex256 = value => parseInt(value).toString(16).padStart(64, '0');

/**
 * 
 * @param {string} camelCase 
 * @returns {string}
 */
const toSnakeCase = camelCase => camelCase.replace(/([A-Z])/g, '_$1').toLowerCase();

/**
 * @param {import('pino').Logger} logger 
 * @param {string} msg 
 */
const trace = (logger, msg) => logger.trace('(hedera-forking) ' + msg);

/**
 * 
 * @param {import("pino").Logger} logger 
 * @param {string=} requestIdPrefix
 */
function initSlotMap(logger, requestIdPrefix) {
    if (slotMap === undefined) {
        slotMap = new Map();
        for (const field of hts.storageLayout.storage) {
            slotMap.set(BigInt(field.slot), field);
        }

        trace(logger, `${requestIdPrefix} Storage Layout Slot map initialized`);
    }
};

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
        initSlotMap(logger, requestIdPrefix);

        if (!address.startsWith(LONG_ZERO_PREFIX)) {
            trace(logger, `${address} does not start with ${LONG_ZERO_PREFIX}, bail`);
            return null;
        }

        const tokenId = `0.0.${parseInt(address, 16)}`;
        trace(logger, `Getting storage for ${address} (tokenId=${tokenId}) at slot=${requestedSlot}`);

        const nrequestedSlot = BigInt(requestedSlot);

        const keccakedSlot = inferSlotAndOffset(nrequestedSlot, hts.storageLayout.storage);
        if (keccakedSlot !== null) {
            const kecRes = `0x${(await getComplexElement(keccakedSlot.slot, tokenId, keccakedSlot.offset)).padStart(64, '0')}`;
            trace(logger, `Get storage ${address} slot: ${requestedSlot}, result: ${kecRes}`);
            return kecRes;
        }

        const field = slotMap.get(nrequestedSlot);

        const tokenResult = await mirrorNodeClient.getTokenById(tokenId);
        const value = tokenResult[toSnakeCase(field.label)];
        if (!converter(field.type) || !value) {
            return ZERO_HEX_32_BYTE;
        }

        return '0x' + converter(field.type)(value);

        async function getComplexElement(slot, tokenId, offset) {
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
            return converter(slot.type, offset)(tokenData[toSnakeCase(slot.label)]);
        }
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

/**
 * 
 * @param {bigint} nrequestedSlot 
 * @param {StorageSlot[]} slots 
 * @param {bigint} MAX_ELEMENTS How many slots ahead to infer that `nrequestedSlot` is part of a given slot.
 * @returns {{slot: StorageSlot, offset: bigint}|null}
 */
function inferSlotAndOffset(nrequestedSlot, slots, MAX_ELEMENTS = 100) {
    for (const slot of slots) {
        //   if (slot.type !== 't_string_storage' && !EthGetStorageAtService.BALANCES_ARRAY.includes(slot.label)) {
        //     continue;
        //   }
        const baseKeccak = BigInt(keccak256(`0x${toIntHex256(slot.slot)}`));
        const offset = nrequestedSlot - baseKeccak;
        if (offset < 0 || offset > MAX_ELEMENTS) {
            continue;
        }
        return { slot, offset: Number(offset) };
    }

    return null;
}

//   private async get(slot: StorageSlot, address: string): Promise<string> {
//     if (EthGetStorageAtService.BALANCES_ARRAY.includes(slot.label)) {
//       const result: { balances: { account: string; balance: number }[] } =
//         await this.mirrorNodeClient.getTokenBalances(address);
//       return stringToIntHex256(`${result.balances.length}`);
//     }
//   }
// }

const stringToStringStorageHex = input => {
    let binaryString = Buffer.from(input).toString('hex');
    const stringLength = input.length;
    let lengthByte = (stringLength * 2 + 1).toString(16);

    if (stringLength > 31) {
        binaryString = '0';
    } else {
        lengthByte = (stringLength * 2).toString(16);
    }

    const paddedString = binaryString.padEnd(64 - 2, '0');

    return `${paddedString}${lengthByte.padStart(2, '0')}`;
};

/**
 * 
 * @param {*} input 
 * @param {*} offset 
 * @returns 
 */
const stringToStringNextBytesHex = (input, offset) => {
    const binaryString = Buffer.from(input).toString('hex');
    const substring = binaryString.substring(offset * 64, (offset + 1) * 64);

    return substring.padEnd(64, '0');
};

/**
 * ((input: string) => string)
 * @param {string} type 
 * @param {number?} offset 
 * @returns 
 */
function converter(type, offset) {
    if (typeof offset !== 'undefined') {
        return (input) => stringToStringNextBytesHex(input, offset);
    }
    const map = {
        t_string_storage: stringToStringStorageHex,
        t_uint8: toIntHex256,
        t_uint256: toIntHex256,
    };
    return typeof map[type] === 'function' ? map[type] : null;
};
