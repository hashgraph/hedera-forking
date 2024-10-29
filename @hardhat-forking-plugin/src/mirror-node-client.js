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

const debug = require('util').debuglog('hedera-forking-mirror');

/**
 * Class representing a client for interacting with the Hedera Mirror Node API.
 */
class MirrorNodeClient {
    /**
     * Creates a new instance of the `MirrorNodeClient`.
     *
     * @param {string} url The base URL of the Hedera Mirror Node API.
     * @param {number=} blockNumber
     */
    constructor(url, blockNumber) {
        this.url = url;
        this.blockNumber = blockNumber;
        this.forkBlock = null;
    }

    /**
     * Fetches information about a token by its token ID.
     *
     * @param {string} tokenId the token ID to fetch.
     * @returns {Promise<Record<string, unknown> | null>} a `Promise` resolving to the token information or null if not found.
     */
    async getTokenById(tokenId) {
        return this.get(`tokens/${tokenId}`);
    }

    /**
     * Fetches the balance of a token for a specific account.
     *
     * @param {string} tokenId the token ID to fetch the balance for.
     * @param {string} accountId the account ID to fetch the balance for.
     * @returns {Promise<{ balances: Array<{ balance: number }> } | null>} A `Promise` resolving to the account's token balance.
     */
    async getBalanceOfToken(tokenId, accountId) {
        return this.get(`tokens/${tokenId}/balances?account.id=${accountId}`);
    }

    /**
     * Fetches token allowances for a specific account, token, and spender.
     *
     * @param {string} accountId The owner's account ID.
     * @param {string} tokenId The token ID.
     * @param {string} spenderId The spender's account ID.
     * @returns {Promise<{ allowances: Array<{ amount: number }> } | null>} A `Promise` resolving to the token allowances.
     */
    async getAllowanceForToken(accountId, tokenId, spenderId) {
        return this.get(
            `accounts/${accountId}/allowances/tokens?token.id=${tokenId}&spender.id=${spenderId}`,
            false
        );
    }

    /**
     * Fetches account information by account ID, alias, or EVM address.
     *
     * @param {string} idOrAliasOrEvmAddress The account ID, alias, or EVM address to fetch.
     * @returns {Promise<{ account: string } | null>} A `Promise` resolving to the account information or `null` if not found.
     */
    async getAccount(idOrAliasOrEvmAddress) {
        return this.get(`accounts/${idOrAliasOrEvmAddress}?transactions=false`);
    }

    /**
     *
     * @param {number} blockNumber
     */
    async getTimestamp(blockNumber) {
        if (this.forkBlock === null) {
            this.forkBlock = await this.get(`blocks/${blockNumber}`, false);
        }
        return this.forkBlock.timestamp.to;
    }

    /**
     * Sends a `GET` request to the specified Mirror Node URL and returns the response data.
     *
     * @private
     * @template T
     * @param {string} endpoint The endpoint to send the `GET` request to.
     * @param {boolean} withTimestamp
     * @returns {Promise<T | null>} A `Promise` resolving to the response data or `null` if an error happened.
     */
    async get(endpoint, withTimestamp = true) {
        const timestamp =
            withTimestamp && this.blockNumber !== undefined
                ? `${endpoint.includes('?') ? '&' : '?'}timestamp=${await this.getTimestamp(this.blockNumber)}`
                : '';

        try {
            const url = `${this.url}${endpoint}${timestamp}`;
            debug('Mirror Node request', url);
            const response = await fetch(url);
            if (!response.ok) {
                if (response.status === 404) {
                    return null;
                }
                throw new Error(
                    `Request failed with status ${response.status}: ${response.statusText}`
                );
            }
            return await response.json();
        } catch (err) {
            console.error(`Error fetching data from ${endpoint}`);
            console.error(err);
            return null;
        }
    }
}

module.exports = {
    MirrorNodeClient,
};
