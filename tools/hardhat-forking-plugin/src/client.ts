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

import axios from 'axios';

export class MirrornodeClient {
  private readonly url;

  public constructor(url = 'https://testnet.mirrornode.hedera.com/api/v1/') {
    this.url = url;
  }

  public async getTokenById(tokenId: string, requestIdPrefix?: string): Promise<Record<string, unknown> | null> {
    return this.get(`${this.url}tokens/${tokenId}`, requestIdPrefix);
  }

  public async getBalanceOfToken(
    tokenId: string,
    accountId: string,
    requestIdPrefix?: string
  ): Promise<{
    balances: Array<{
      balance: number;
    }>;
  }> {
    return this.get(`${this.url}tokens/${tokenId}/balances?account.id=${accountId}`, requestIdPrefix);
  }

  public getAllowanceForToken(
    accountId: string,
    tokenId: string,
    spenderId: string,
    requestIdPrefix?: string
  ): Promise<{
    allowances: Array<{
      amount: number;
    }>;
  }> {
    return this.get(
      `${this.url}accounts/${accountId}/allowances/tokens?token.id=${tokenId}&spender.id=${spenderId}`,
      requestIdPrefix
    );
  }

  public getAccount(
    idOrAliasOrEvmAddress: string,
    requestIdPrefix?: string
  ): Promise<{
    account: string;
  } | null> {
    return this.get(`${this.url}accounts/${idOrAliasOrEvmAddress}?transactions=false`, requestIdPrefix);
  }

  private async get(url: string, requestIdPrefix?: string): Promise<any> {
    return (await axios.get(url)).data;
  }
}
