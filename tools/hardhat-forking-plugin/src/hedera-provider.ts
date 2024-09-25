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

import { keccak256, toUtf8Bytes } from 'ethers';
import fs from 'fs';
import { ProviderWrapper } from 'hardhat/plugins';
import * as path from 'path';

import HTS from '../out/HtsSystemContract.sol/HtsSystemContract.json';

import { MirrornodeClient } from './client';
import { accountIdToHex, getAccountStorageSlot } from './utils';

export const HTS_ADDRESS = '0x0000000000000000000000000000000000000167';

export class HederaProvider extends ProviderWrapper {
  private actionDone: string[] = [];
  private requestId = 0;

  constructor(protected readonly _wrappedProvider: any, protected mirrornode: MirrornodeClient) {
    super(_wrappedProvider);
  }

  public async request(args: any) {
    await this.loadHTS();
    await this.loadToken(args);
    return this._wrappedProvider.request(args);
  }

  private async loadHTS() {
    if (this.actionDone.includes('hts_code')) {
      return;
    }
    const current = await this._wrappedProvider.request({
      method: 'eth_getCode',
      params: [HTS_ADDRESS, 'latest'],
    });
    if (!['0xfe', '0x'].includes(current)) {
      return;
    }
    await this._wrappedProvider.request({
      method: 'hardhat_setCode',
      params: [HTS_ADDRESS, HTS.deployedBytecode.object],
    });
    this.actionDone.push('hts_code');
  }

  private async loadToken(args: any) {
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
    if (selector === `${keccak256(toUtf8Bytes('balanceOf(address)'))}`.slice(0, 10)) {
      await this.loadBalanceOfAnAccount(`0x${data.slice(-40)}`, target);
      return;
    }
    if (selector === `${keccak256(toUtf8Bytes('allowance(address,address)'))}`.slice(0, 10)) {
      await this.loadAllowancesOfOfAnAccount(`0x${data.slice(-104, -64)}`, `0x${data.slice(-40)}`, target);
    }
  }

  private async loadBaseTokenData(target: string) {
    if (this.actionDone.includes(`token_${target}`)) {
      return;
    }
    const token = await this.mirrornode.getTokenById(`0.0.${Number(target)}`, this.reqId());
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
    const storageLayout: Array<{
      label: string;
      slot: string;
      type: string;
    }> = HTS.storageLayout.storage;
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

  private async loadBalanceOfAnAccount(account: string, target: string) {
    if (this.actionDone.includes(`balance_${account}`)) {
      return;
    }
    const accountId = (await this.mirrornode.getAccount(account, this.reqId()))?.account;
    if (!accountId) {
      return;
    }
    await this.assignEvmAccountAddress(accountId, account);
    const result = await this.mirrornode.getBalanceOfToken(`0.0.${Number(target)}`, accountId, this.reqId());
    const balance = result.balances.length > 0 ? result.balances[0].balance : 0;
    await this.assignValueToSlot(
      target,
      getAccountStorageSlot('balanceOf(address)', [accountId]),
      `0x${balance.toString(16).padStart(64, '0')}`
    );
    this.actionDone.push(`balance_${account}`);
  }

  private async loadAllowancesOfOfAnAccount(owner: string, spender: string, target: string) {
    if (this.actionDone.includes(`allowance_${owner}_${spender}`)) {
      return;
    }
    const ownerId = (await this.mirrornode.getAccount(owner, this.reqId()))?.account;
    const spenderId = (await this.mirrornode.getAccount(spender, this.reqId()))?.account;
    if (!ownerId || !spenderId) {
      return;
    }
    await this.assignEvmAccountAddress(ownerId, owner);
    await this.assignEvmAccountAddress(spenderId, spender);
    const result = await this.mirrornode.getAllowanceForToken(
      ownerId,
      `0.0.${Number(target)}`,
      spenderId,
      this.reqId()
    );
    const allowance = result.allowances.length > 0 ? result.allowances[0].amount : 0;
    await this.assignValueToSlot(
      target,
      getAccountStorageSlot('allowance(address,address)', [spenderId, ownerId]),
      `0x${allowance.toString(16).padStart(64, '0')}`
    );
    this.actionDone.push(`allowance_${owner}_${spender}`);
  }

  private async assignEvmAccountAddress(accountId: string, evmAddress: string) {
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

  private async loadStringIntoStorage(target: string, initialSlot: number, value: string) {
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

  private async assignValueToSlot(target: string, slot: string, value: string) {
    await this._wrappedProvider.request({
      method: 'hardhat_setStorageAt',
      params: [target, slot, value],
    });
  }

  private reqId() {
    return `hardhat-hedera-plugin-${this.requestId++}`;
  }
}
