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

const { extendProvider } = require('hardhat/config');
const { JsonRpcProvider } = require('ethers');
const { MirrorNodeClient } = require('./client');
const { HederaProvider } = require('./hedera-provider');

const chains = {
    295: 'https://mainnet-public.mirrornode.hedera.com/api/v1/',
    296: 'https://testnet.mirrornode.hedera.com/api/v1/',
    297: 'https://previewnet.mirrornode.hedera.com/api/v1/',
};

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
