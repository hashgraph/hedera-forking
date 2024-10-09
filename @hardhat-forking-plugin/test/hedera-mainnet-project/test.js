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

const hre = require('hardhat');
const { expect } = require('chai');
const { getProviderExtensions } = require('../.lib');

describe('hedera-mainnet-project', function () {

    before('provider call to force its initialization', async function () {
        await hre.network.provider.request({ method: 'eth_chainId' });
    });

    it('should have `HederaProvider` as a loaded extension', async function () {
        const extensions = getProviderExtensions(hre.network.provider).map(p => p.constructor.name);
        expect(extensions).to.include('HederaProvider');
    });

    it('should have `HederaProvider` set to fetch token data from mainnet Mirror Node', async function () {
        const [provider] = getProviderExtensions(hre.network.provider)
            .filter(p => p.constructor.name === 'HederaProvider');
        expect(/**@type{import('../../src/hedera-provider').HederaProvider}*/(provider).mirrorNode.url)
            .to.be.equal('https://mainnet-public.mirrornode.hedera.com/api/v1/');
    });
});
