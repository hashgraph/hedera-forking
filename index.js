const hts = require("./out/HtsSystemContract.sol/HtsSystemContract.json");

let slotMap = undefined;

module.exports = {
    getFieldAt(slot) {
        if (slotMap === undefined) {
            slotMap = new Map();
            for (const field of hts.storageLayout.storage) {
                slotMap.set(BigInt(field.slot), field);
            }
        }

        return slotMap.get(BigInt(slot)).label;
    },

    /**
     *
     * @returns {string}
     */
    getHtsCode() {
        return hts.deployedBytecode.object;
    },
};
