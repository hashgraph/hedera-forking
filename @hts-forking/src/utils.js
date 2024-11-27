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

/**
 * Helpers constants and functions.
 *
 * Useful to extract these helpers in a separate module so they can be used by tests as well.
 */
module.exports = {
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
     * @param {string | number | bigint} value Decimal `value` as string.
     * @returns {string}
     */
    toIntHex256: value => BigInt(value).toString(16).padStart(64, '0'),
};
