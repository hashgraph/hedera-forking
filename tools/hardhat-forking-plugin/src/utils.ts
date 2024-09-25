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

export const accountIdToHex = (accountId: string) => parseInt(accountId.split('.')[2], 10).toString(16);
export const getAccountStorageSlot = (selector: string, accountIds: string[]) =>
  `${`${keccak256(toUtf8Bytes(selector))}`.slice(0, 10)}${accountIds
    .map((accountId) => accountIdToHex(accountId).padStart(8, '0'))
    .join('')
    .padStart(56, '0')}`;
