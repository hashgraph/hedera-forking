/*-
 * Hedera Hardhat Plugin Project
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
 * Class representing a client for interacting with the Hedera Mirror Node API.
 */
class MirrornodeClient {
  /**
   * Creates a new instance of the MirrornodeClient.
   * @param {string} [url='https://testnet.mirrornode.hedera.com/api/v1/'] - The base URL of the Hedera Mirror Node API.
   */
  constructor(url = 'https://testnet.mirrornode.hedera.com/api/v1/') {
    this.url = url;
  }

  /**
   * Fetches information about a token by its token ID.
   * @param {string} tokenId - The token ID to fetch.
   * @param {string} [requestIdPrefix] - An optional request ID prefix for logging or tracing.
   * @returns {Promise<Record<string, unknown> | null>} - A Promise resolving to the token information or null if not found.
   */
  async getTokenById(tokenId, requestIdPrefix) {
    return this.get(`${this.url}tokens/${tokenId}`, requestIdPrefix);
  }

  /**
   * Fetches the balance of a token for a specific account.
   * @param {string} tokenId - The token ID to fetch the balance for.
   * @param {string} accountId - The account ID to fetch the balance for.
   * @param {string} [requestIdPrefix] - An optional request ID prefix for logging or tracing.
   * @returns {Promise<{ balances: Array<{ balance: number }> }>} - A Promise resolving to the account's token balance.
   */
  async getBalanceOfToken(tokenId, accountId, requestIdPrefix) {
    return this.get(`${this.url}tokens/${tokenId}/balances?account.id=${accountId}`, requestIdPrefix);
  }

  /**
   * Fetches token allowances for a specific account, token, and spender.
   * @param {string} accountId - The owner's account ID.
   * @param {string} tokenId - The token ID.
   * @param {string} spenderId - The spender's account ID.
   * @param {string} [requestIdPrefix] - An optional request ID prefix for logging or tracing.
   * @returns {Promise<{ allowances: Array<{ amount: number }> }>} - A Promise resolving to the token allowances.
   */
  async getAllowanceForToken(accountId, tokenId, spenderId, requestIdPrefix) {
    return this.get(
      `${this.url}accounts/${accountId}/allowances/tokens?token.id=${tokenId}&spender.id=${spenderId}`,
      requestIdPrefix
    );
  }

  /**
   * Fetches account information by account ID, alias, or EVM address.
   * @param {string} idOrAliasOrEvmAddress - The account ID, alias, or EVM address to fetch.
   * @param {string} [requestIdPrefix] - An optional request ID prefix for logging or tracing.
   * @returns {Promise<{ account: string } | null>} - A Promise resolving to the account information or null if not found.
   */
  async getAccount(idOrAliasOrEvmAddress, requestIdPrefix) {
    return this.get(`${this.url}accounts/${idOrAliasOrEvmAddress}?transactions=false`, requestIdPrefix);
  }

  /**
   * Sends a GET request to the specified URL and returns the response data.
   * @private
   * @param {string} url - The URL to send the GET request to.
   * @param {string} [requestIdPrefix] - An optional request ID prefix for logging or tracing.
   * @returns {Promise<any>} - A Promise resolving to the response data.
   */
  async get(url, requestIdPrefix) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}: ${response.statusText}`);
      }
      return await response.json();
    } catch (error) {
      console.error(`Error fetching data from ${url}. ${requestIdPrefix ? `Request ID: ${requestIdPrefix}` : ''}`);
      console.error(error);
      return null;
    }
  }
}

module.exports = {
  MirrornodeClient
};
