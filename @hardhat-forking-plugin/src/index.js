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

const { extendProvider, extendConfig } = require('hardhat/config');
const { JsonRpcProvider } = require('ethers');
const { MirrorNodeClient } = require('./mirror-node-client');
const { HederaProvider } = require('./hedera-provider');

const chains = {
    295: 'https://mainnet-public.mirrornode.hedera.com/api/v1/',
    296: 'https://testnet.mirrornode.hedera.com/api/v1/',
    297: 'https://previewnet.mirrornode.hedera.com/api/v1/',
};

/**
 * https://hardhat.org/hardhat-network/docs/guides/forking-other-networks#using-a-custom-hardfork-history
 * https://hardhat.org/hardhat-network/docs/reference#chains
 */
extendConfig((config, _userConfig) => {
    const hardhatChains = config.networks.hardhat.chains;
    for (const chainIdKey of Object.keys(chains)) {
        const chainId = Number(chainIdKey);
        // This can be already set if the user configures a custom hardfork for a Hedera network.
        // We don't want to overwrite the value set by the user.
        if (hardhatChains.get(chainId) === undefined) {
            hardhatChains.set(Number(chainId), {
                hardforkHistory: new Map().set('shanghai', 0)
            });
        }
    }
});

/**
 * Extends the provider with `HederaProvider` only when the forked network is a Hedera network.
 */
extendProvider(async (provider, config, network) => {
    const networkConfig = config.networks[network];
    if ('forking' in networkConfig) {
        const { forking } = networkConfig;
        if (forking.url) {
            const net = await (new JsonRpcProvider(forking.url)).getNetwork();
            const mirrorNodeUrl = chains[/**@type{keyof typeof chains}*/(Number(net.chainId))];
            if (mirrorNodeUrl !== undefined) {
                return new HederaProvider(provider, new MirrorNodeClient(mirrorNodeUrl));
            }
        }
    }

    return provider;
});
