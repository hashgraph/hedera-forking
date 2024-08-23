const hts = require("./out/HtsSystemContract.sol/HtsSystemContract.json");

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
 * @param {import("pino").Logger} logger 
 * @param {string=} requestIdPrefix
 */
function initSlotMap(logger, requestIdPrefix) {
    if (slotMap === undefined) {
        slotMap = new Map();
        for (const field of hts.storageLayout.storage) {
            slotMap.set(BigInt(field.slot), field);
        }

        logger.trace(`${requestIdPrefix} Storage Layout Slot map initialized`);
    }
};

module.exports = {
    getHtsCode() {
        return hts.deployedBytecode.object;
    },

    /**
     * 
     * @param {string} address 
     * @param {string} slot 
     * @param {import(".").IMirrorNodeClient} mirrorNodeClient 
     * @param {import("pino").Logger=} logger 
     * @param {string=} requestIdPrefix
     * @returns {Promise<string | null>}
     */
    async getHtsStorageAt(address, slot, mirrorNodeClient, logger = { trace: () => undefined }, requestIdPrefix) {
        initSlotMap(logger, requestIdPrefix);

        if (!address.startsWith(LONG_ZERO_PREFIX)) {
            logger.trace(`${address} does not start with ${LONG_ZERO_PREFIX}, bail`);
            return null;
        }

        logger.trace(`convert ddress ${address} to tokenId`);
        const tokenId = `0.0.${parseInt(address, 16)}`;

        const field = slotMap.get(BigInt(slot));

        const tokenResult = await mirrorNodeClient.getTokenById(tokenId);
        const value = tokenResult[toSnakeCase(field.label)];
        if (!converter(field.type) || !value) {
            return ZERO_HEX_32_BYTE;
        }

        return '0x' + converter(field.type)(value);
    },

};



// import { MirrorNodeClient } from '../../../clients';
// import { calculateOffset, converter, hexToDecimal, stringToIntHex256, toSnakeCase } from './utils/converter';
// import { keccak256 } from 'ethers';
// import { getStorageLayout, StorageSlot } from './utils/artifactParser';
// import { Logger } from 'pino';
// import { HashZero } from '@ethersproject/constants';
// import constants from '../../../constants';
// import { EthImpl } from '../../../eth';

// export class EthGetStorageAtService {
//   private static readonly MAX_ELEMENTS = 1000;
//   private static readonly BALANCES_ARRAY = ['holders', 'balances'];
//   constructor(
//     private mirrorNodeClient: MirrorNodeClient,
//     private logger: Logger,
//   ) {}

//   public async execute(address: string, slotNumber: string) {
//     try {
//       if (!(await this.isSupported(address))) {
//         return '';
//       }

//       const type = (await this.mirrorNodeClient.isTokenFungible(address)) ? 'fungible' : 'nonFungible';
//       const allSlots = getStorageLayout(type);

//       // Slot === keccaked value (long strings, maps, arrays)
//       const keccakedSlot = await this.guessSlotAndOffsetFromKeccakedNumber(slotNumber, allSlots);
//       if (keccakedSlot) {
//         const kecRes = `0x${(await this.getComplexElement(keccakedSlot.slot, address, keccakedSlot.offset)).padStart(
//           64,
//           '0',
//         )}`;
//         this.logger.error(`Get storage ${address} slot: ${slotNumber}, result: ${kecRes}`);
//         return kecRes;
//       }

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

//   private async isSupported(address: string) {
//     const resolved = await this.mirrorNodeClient.resolveEntityType(
//       address,
//       [constants.TYPE_TOKEN],
//       EthImpl.ethGetStorageAt,
//     );
//     return resolved !== null && resolved.type === constants.TYPE_TOKEN;
//   }

//   private async guessSlotAndOffsetFromKeccakedNumber(input: string, slots: StorageSlot[]) {
//     for (const slot of slots) {
//       if (slot.type !== 't_string_storage' && !EthGetStorageAtService.BALANCES_ARRAY.includes(slot.label)) {
//         continue;
//       }
//       const baseKeccak = keccak256(`0x${stringToIntHex256(slot.slot)}`);
//       const offset = calculateOffset(baseKeccak, input);
//       if (offset === null || offset > EthGetStorageAtService.MAX_ELEMENTS) {
//         continue;
//       }
//       return { slot, offset };
//     }

//     return null;
//   }

//   private async getComplexElement(slot: any, address: string, offset: number): Promise<string> {
//     if (EthGetStorageAtService.BALANCES_ARRAY.includes(slot.label)) {
//       const result: { balances: { account: string; balance: number }[] } =
//         await this.mirrorNodeClient.getTokenBalances(address);
//       const balances = result.balances;
//       if (slot.label === 'balances') {
//         return stringToIntHex256(`${balances[offset]?.balance ?? 0}`);
//       }
//       if (!balances[offset]?.account) {
//         return HashZero.slice(2);
//       }
//       const account: { evm_address: string } = await this.mirrorNodeClient.getAccount(balances[offset].account);
//       return account.evm_address.slice(2);
//     }
//     const tokenData = await this.mirrorNodeClient.getToken(address);
//     return converter(slot.type, offset)(tokenData[toSnakeCase(slot.label)]);
//   }

//   private async get(slot: StorageSlot, address: string): Promise<string> {
//     if (EthGetStorageAtService.BALANCES_ARRAY.includes(slot.label)) {
//       const result: { balances: { account: string; balance: number }[] } =
//         await this.mirrorNodeClient.getTokenBalances(address);
//       return stringToIntHex256(`${result.balances.length}`);
//     }
//   }
// }

// export const stringToStringStorageHex = (input: string) => {
//   let binaryString = Buffer.from(input).toString('hex');
//   const stringLength = input.length;
//   let lengthByte = (stringLength * 2 + 1).toString(16);

//   if (stringLength > 31) {
//     binaryString = '0';
//   } else {
//     lengthByte = (stringLength * 2).toString(16);
//   }

//   const paddedString = binaryString.padEnd(64 - 2, '0');

//   return `${paddedString}${lengthByte.padStart(2, '0')}`;
// };

// export const stringToStringNextBytesHex = (input: string, offset: number) => {
//   const binaryString = Buffer.from(input).toString('hex');
//   const substring = binaryString.substring(offset * 64, (offset + 1) * 64);

//   return substring.padEnd(64, '0');
// };



// export const hexToDecimal = (hex: string) => new BigNumber(hex.startsWith('0x') ? hex.slice(2) : hex, 16).toString(10);

// export const calculateOffset = (z: string, y: string) => {
//   const zDec = new BigNumber(hexToDecimal(z));
//   const yDec = new BigNumber(hexToDecimal(y));
//   return yDec.isLessThan(zDec) ? null : yDec.minus(zDec).toNumber();
// };

/**
 * 
 * @param {string} camelCase 
 * @returns {string}
 */
function toSnakeCase(camelCase) {
    return camelCase.replace(/([A-Z])/g, '_$1').toLowerCase();
}

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
        // t_string_storage: stringToStringStorageHex,
        t_uint8: toIntHex256,
        t_uint256: toIntHex256,
    };
    return typeof map[type] === 'function' ? map[type] : null;
};
