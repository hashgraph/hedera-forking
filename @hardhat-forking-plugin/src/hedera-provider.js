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

const { keccak256, toUtf8Bytes } = require('ethers');
const fs = require('fs');
const path = require('path');
const HTS = require('../out/HtsSystemContract.json');
const { ProviderWrapper } = require('hardhat/plugins');

const HTS_ADDRESS = '0x0000000000000000000000000000000000000167';

/**
 * Converts a Hedera account ID to its corresponding hexadecimal representation.
 *
 * @param {string} accountId - The Hedera account ID in the format `shard.realm.account`.
 * @returns {string} The hexadecimal representation of the account ID.
 */
const accountIdToHex = (accountId) => parseInt(accountId.split('.')[2], 10).toString(16);

/**
 * Generates the storage slot for a given selector and list of account IDs.
 *
 * @param {string} selector - The selector function name, e.g., 'balanceOf(address)'.
 * @param {string[]} accountIds - Array of Hedera account IDs that will be used to generate the storage slot.
 * @returns {string} The storage slot as a hexadecimal string.
 */
const getAccountStorageSlot = (selector, accountIds) =>
  `${keccak256(toUtf8Bytes(selector)).slice(0, 10)}${accountIds
    .map((accountId) => accountIdToHex(accountId).padStart(8, '0'))
    .join('')
    .padStart(56, '0')}`

/**
 * HederaProvider is a wrapper around a Hardhat provider, enabling Hedera-related logic.
 */
class HederaProvider extends ProviderWrapper {

  /**
   * Creates an instance of HederaProvider.
   * 
   * @param {import('hardhat/types').EIP1193Provider} wrappedProvider The provider being wrapped.
   * @param {import('./client').MirrorNodeClient} mirrorNode The client used to query the Hedera network's mirrornode.
   */
  constructor(wrappedProvider, mirrorNode) {
    super(wrappedProvider);
    this.mirrorNode = mirrorNode;

    /**
     * List of actions already done to prevent fetching the same data more than once.
     * 
     * @type {('hts_code' | `${'token' | 'balance' | 'allowance' | 'account'}_${string}`)[]}
     */
    this.actionDone = [];
  }

  /**
   * Processes a request and ensures HTS code and token data are loaded before passing it to the provider.
   * 
   * @param {object} args - The request arguments. Contains:
   * @param {string} args.method - The method to be called (e.g., 'eth_call').
   * @param {Array<{to: string, data: string}>} args.params - Array of parameters
   * @returns {Promise<any>} - The result of the request.
   */
  async request(args) {
    await this.loadHTS();
    await this.loadToken(args);
    return this._wrappedProvider.request(args);
  }

  /**
   * Loads HTS code if it hasn't already been loaded.
   *
   * This operation ensures that Hedera Network forks can function correctly, even when they attempt to call
   * a precompile. If the fork's EVM is unaware of the precompile code, it won't be able to query it, as JSON RPC does
   * not return this information—precompiles are specific to Hedera. Communicating with the 0x167 address will return
   * data from the actual Hedera Token Service. Since the EVM does not handle this by default, we need to emulate
   * this behavior in the forks for proper functionality. To achieve this, we are setting the HTS code here,
   * which will mimic the behavior of the real HTS.
   * 
   * @private
   * @returns {Promise<void>}
   */
  async loadHTS() {
    if (this.actionDone.includes('hts_code')) {
      return;
    }
    const current = await this._wrappedProvider.request({
      method: 'eth_getCode',
      params: [HTS_ADDRESS, 'latest'],
    });
    if (!['0xfe', '0x'].includes(/**@type{string}*/(current))) {
      return;
    }
    await this._wrappedProvider.request({
      method: 'hardhat_setCode',
      params: [HTS_ADDRESS, HTS.deployedBytecode.object],
    });
    this.actionDone.push('hts_code');
  }

  /**
   * Loads token data into storage for calls related to tokens.
   *
   * The primary purpose of using network forks is to test your own code against an existing infrastructure.
   * In the context of Hedera, this means you can use tokens present on the forked network and execute operations
   * with or against them. While we've already set the Hedera Token Service code in the previous step, each time
   * we detect a call to a token's address, we will attempt to set that token's storage data, which is retrieved from
   * the MirrorNode API. We are also setting its code (each token forwards requests to the HTS, but the data is
   * queried from the specific token's storage).
   *
   * However, we don't load the entire token's memory at once. Instead, we always set the basic token information
   * (such as name, balance, decimals, etc.). The relationships between tokens and users are dynamically loaded based
   * on the incoming call request. We infer the required information, determine where it should be stored in the smart
   * contract's memory, and set it before making the actual request.
   * 
   * @private
   * @param {object} args - The request arguments. Contains:
   *    @param {string} args.method - The method to be called (e.g., 'eth_call').
   *    @param {Array<{to: string, data: string}>} args.params - Array of parameters
   * @returns {Promise<void>}
   */
  async loadToken(args) {
    const { method, params } = args;
    if (method !== 'eth_call') {
      return;
    }
    const target = params.length ? params[0].to : null;
    const data = params.length ? params[0].data : null;
    if (!target || !data) {
      return;
    }
    await this.loadBaseTokenData(target);
    const selector = data.slice(0, 10);
    if (selector === keccak256(toUtf8Bytes('balanceOf(address)')).slice(0, 10)) {
      await this.loadBalanceOfAnAccount(`0x${data.slice(-40)}`, target);
      return;
    }
    if (selector === `${keccak256(toUtf8Bytes('allowance(address,address)'))}`.slice(0, 10)) {
      await this.loadAllowancesOfOfAnAccount(`0x${data.slice(-104, -64)}`, `0x${data.slice(-40)}`, target);
    }
  }

  /**
   * Loads base token data into storage for the specified token.
   *
   * Sets the token proxy code and basic data into storage.
   * When a request is directed to the address reserved for a Hedera token, we
   *  - Load the bytecode that emulates its behavior on the actual Hedera EVM into memory.
   *  - Load its basic data, such as name and decimals, into the appropriate storage slots in
   *    the smart contract's memory.
   *
   * @private
   * @param {string} target - The target address of the token contract.
   * @returns {Promise<void>}
   */
  async loadBaseTokenData(target) {
    if (this.actionDone.includes(`token_${target}`)) {
      return;
    }
    const token = await this.mirrorNode.getTokenById(`0.0.${Number(target)}`);
    if (!token) {
      return;
    }
    await this._wrappedProvider.request({
      method: 'hardhat_setCode',
      params: [
        target,
        fs
          .readFileSync(path.resolve(__dirname, '..', 'out', 'HIP719.bytecode'), 'utf8')
          .replace('fefefefefefefefefefefefefefefefefefefefe', target.replace('0x', '')),
      ],
    });
    const storageLayout = HTS.storageLayout.storage;
    for (const layout of storageLayout) {
      const value = `${token[layout.label.replace(/([A-Z])/g, '_$1').toLowerCase()]}`;
      if (layout.type === 't_string_storage') {
        await this.loadStringIntoStorage(target, Number(layout.slot), value);
      } else {
        await this.assignValueToSlot(
          target,
          `0x${Number(layout.slot).toString(16)}`,
          `0x${parseInt(value, 10).toString(16).padStart(64, '0')}`
        );
      }
    }
    this.actionDone.push(`token_${target}`);
  }

  /**
   * Loads the balance of a specific account for the specified token.
   * 
   * @private
   * @param {string} account - The account address to load balance for.
   * @param {string} target - The target token contract address.
   * @returns {Promise<void>}
   */
  async loadBalanceOfAnAccount(account, target) {
    if (this.actionDone.includes(`balance_${account}`)) {
      return;
    }
    const accountId = (await this.mirrorNode.getAccount(account))?.account;
    if (!accountId) {
      return;
    }
    await this.assignEvmAccountAddress(accountId, account);
    const result = await this.mirrorNode.getBalanceOfToken(`0.0.${Number(target)}`, accountId);
    const balance = result.balances.length > 0 ? result.balances[0].balance : 0;
    await this.assignValueToSlot(
      target,
      getAccountStorageSlot('balanceOf(address)', [accountId]),
      `0x${balance.toString(16).padStart(64, '0')}`
    );
    this.actionDone.push(`balance_${account}`);
  }

  /**
   * Loads the allowance for a specific owner-spender pair for the specified token.
   * 
   * @private
   * @param {string} owner - The owner address.
   * @param {string} spender - The spender address.
   * @param {string} target - The target token contract address.
   * @returns {Promise<void>}
   */
  async loadAllowancesOfOfAnAccount(owner, spender, target) {
    if (this.actionDone.includes(`allowance_${owner}_${spender}`)) {
      return;
    }
    const ownerId = (await this.mirrorNode.getAccount(owner))?.account;
    const spenderId = (await this.mirrorNode.getAccount(spender))?.account;
    if (!ownerId || !spenderId) {
      return;
    }
    await this.assignEvmAccountAddress(ownerId, owner);
    await this.assignEvmAccountAddress(spenderId, spender);
    const result = await this.mirrorNode.getAllowanceForToken(
      ownerId,
      `0.0.${Number(target)}`,
      spenderId,
    );
    const allowance = result.allowances.length > 0 ? result.allowances[0].amount : 0;
    await this.assignValueToSlot(
      target,
      getAccountStorageSlot('allowance(address,address)', [spenderId, ownerId]),
      `0x${allowance.toString(16).padStart(64, '0')}`
    );
    this.actionDone.push(`allowance_${owner}_${spender}`);
  }

  /**
   * Assigns an EVM account address to a corresponding Hedera account ID.
   * 
   * @private
   * @param {string} accountId - The Hedera account ID.
   * @param {string} evmAddress - The corresponding EVM address.
   * @returns {Promise<void>}
   */
  async assignEvmAccountAddress(accountId, evmAddress) {
    if (this.actionDone.includes(`account_${accountId}`)) {
      return;
    }
    await this.assignValueToSlot(
      HTS_ADDRESS,
      `${`${keccak256(toUtf8Bytes('getAccountId(address)'))}`.slice(0, 10)}0000000000000000${evmAddress.slice(2)}`,
      `0x${accountIdToHex(accountId).padStart(64, '0')}`
    );
    this.actionDone.push(`account_${accountId}`);
  }

  /**
   * Loads a string value into the storage of the target contract.
   * 
   * @private
   * @param {string} target - The target contract address.
   * @param {number} initialSlot - The initial storage slot.
   * @param {string} value - The string value to store.
   * @returns {Promise<void>}
   */
  async loadStringIntoStorage(target, initialSlot, value) {
    const [hexStr, lenByte] =
      value.length > 31 ? ['0', value.length * 2 + 1] : [Buffer.from(value).toString('hex'), value.length * 2];
    const storageMemory = `${hexStr.padEnd(64 - 2, '0')}${lenByte.toString(16).padStart(2, '0')}`;
    await this.assignValueToSlot(target, `0x${initialSlot.toString(16)}`, `0x${storageMemory}`);
    for (let i = 0; i < (value.length + 31) / 32; i++) {
      const nextSlot = BigInt(keccak256(`0x${initialSlot.toString(16).padStart(64, '0')}`)) + BigInt(i);
      await this.assignValueToSlot(
        target,
        `0x${nextSlot.toString(16)}`,
        `0x${Buffer.from(value)
          .toString('hex')
          .substring(i * 64, (i + 1) * 64)
          .padEnd(64, '0')}`
      );
    }
  }

  /**
   * Assigns a value to a specific storage slot of the target contract.
   * 
   * @private
   * @param {string} target - The target contract address.
   * @param {string} slot - The storage slot.
   * @param {string} value - The value to store.
   * @returns {Promise<void>}
   */
  async assignValueToSlot(target, slot, value) {
    await this._wrappedProvider.request({
      method: 'hardhat_setStorageAt',
      params: [target, slot, value],
    });
  }
}

module.exports = {
  HederaProvider,
  HTS_ADDRESS,
};
