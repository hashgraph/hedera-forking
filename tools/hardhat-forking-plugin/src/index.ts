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

import { extendConfig, extendProvider } from 'hardhat/config';
import { HardhatConfig, HardhatUserConfig } from 'hardhat/types';

import { MirrornodeClient } from './client';
import { HederaProvider } from './hedera-provider';

export interface HeaderaHardhatConfig extends HardhatConfig {
  hedera: {
    mirrornode: string;
  };
}

export interface HeaderaHardhatUserConfig extends HardhatUserConfig {
  hedera: {
    mirrornode: string;
  };
}

// @ts-ignore
extendProvider(async (provider, config: HeaderaHardhatConfig, network) => {
  return new HederaProvider(provider, new MirrornodeClient(config.hedera.mirrornode));
});

// @ts-ignore
extendConfig((config: HeaderaHardhatConfig, userConfig: Readonly<HeaderaHardhatUserConfig>) => {
  config.hedera.mirrornode =
    userConfig.hedera && userConfig.hedera.mirrornode
      ? userConfig.hedera.mirrornode
      : 'https://testnet.mirrornode.hedera.com/api/v1/';
});
