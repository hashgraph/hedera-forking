
/**
 * Helpers constants and functions.
 * 
 * Useful to extract these helpers in a separate module so they can be used by tests as well.
 */
module.exports = {

    /**
     * The prefix that token addresses must match in order to perform token lookup.
     */
    LONG_ZERO_PREFIX: '0x000000000000',

    /**
     * When a slot is empty, zero must be returned.
     */
    ZERO_HEX_32_BYTE: '0x0000000000000000000000000000000000000000000000000000000000000000',

    /**
     * Converts a _camelCase_ string to a _snake_case_ string.
     * 
     * @param {string} camelCase 
     */
    toSnakeCase: camelCase => camelCase.replace(/([A-Z])/g, '_$1').toLowerCase(),

    /**
     * @param {string} value 
     * @returns {string}
     */
    toIntHex256: value => parseInt(value).toString(16).padStart(64, '0'),
};
