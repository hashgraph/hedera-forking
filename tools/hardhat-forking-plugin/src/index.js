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

const { extendConfig, extendProvider } = require('hardhat/config');
const MirrornodeClient = require('./client').MirrornodeClient;
const HederaProvider = require('./hedera-provider').HederaProvider;

/**
 * Represents a chain configuration for Hedera networks.
 * @typedef {Object} Chain
 * @property {number} chainId - The unique identifier for the chain (e.g., 295 for Mainnet).
 * @property {string} mirrornode - The URL of the mirror node for accessing historical data.
 */

/**
 * @typedef {object} HederaHardhatConfig
 * @property {object} hedera - Hedera configuration object
 * @property {Chain[]} hedera.chains - Supported chains configuration
 */

/**
 * @typedef {object} HederaHardhatUserConfig
 * @property {object} hedera - Hedera configuration object
 * @property {Chain[]} hedera.chains - Supported chains configuration
 */

/**
 * Extends the provider with the HederaProvider.
 *
 * @param {object} provider - The original Hardhat provider.
 * @param {HederaHardhatConfig} config - The Hardhat configuration, including Hedera-specific settings.
 * @param {object} network - The network information.
 * @returns {Promise<HederaProvider>} A new instance of HederaProvider.
 */
extendProvider(async (provider, config, network) => {
  const chainId = await provider.request({ method: 'eth_chainId' });
  const networkData = config.hedera.chains.find(chain => chain.chainId === chainId)
  if (networkData && networkData.mirrornode) {
    return new HederaProvider(provider, new MirrornodeClient(networkData.mirrornode));
  }
  return provider;
});

/**
 * Extends the Hardhat config to include Hedera-specific configurations.
 *
 * @param {HederaHardhatConfig} config - The final Hardhat configuration object.
 * @param {Readonly<HederaHardhatUserConfig>} userConfig - The user's Hardhat configuration object, provided via hardhat.config.js or similar.
 */
extendConfig((config, userConfig) => {
  config.hedera = config.hedera || {};
  config.hedera.chains = [
    {
      chainId: 295,
      mirrornode: 'https://mainnet-public.mirrornode.hedera.com/api/v1/',
    },
    {
      chainId: 296,
      mirrornode: 'https://testnet.mirrornode.hedera.com/api/v1/',
    },
    {
      chainId: 297,
      mirrornode: 'https://previewnet.mirrornode.hedera.com/api/v1/',
    },
  ];
});
