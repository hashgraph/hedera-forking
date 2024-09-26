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
 * @typedef {object} HederaHardhatConfig
 * @property {object} hedera - Hedera configuration object
 * @property {string} hedera.mirrornode - URL of the Hedera Mirror Node API
 */

/**
 * @typedef {object} HederaHardhatUserConfig
 * @property {object} hedera - User's Hedera configuration object
 * @property {string} hedera.mirrornode - URL of the Hedera Mirror Node API from the user's config
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
  return new HederaProvider(provider, new MirrornodeClient(config.hedera.mirrornode));
});

/**
 * Extends the Hardhat config to include Hedera-specific configurations.
 *
 * @param {HederaHardhatConfig} config - The final Hardhat configuration object.
 * @param {Readonly<HederaHardhatUserConfig>} userConfig - The user's Hardhat configuration object, provided via hardhat.config.js or similar.
 */
extendConfig((config, userConfig) => {
  config.hedera = config.hedera || {};
  config.hedera.mirrornode =
    userConfig.hedera && userConfig.hedera.mirrornode
      ? userConfig.hedera.mirrornode
      : 'https://testnet.mirrornode.hedera.com/api/v1/';
});
