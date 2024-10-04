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
 *
 */

const { strict: assert } = require('assert');

module.exports = {

    /**
     * Retrieves the chains of extensions of this `provider`.
     * 
     * The provider can be extended using Hardhat's
     * [`extendProvider`](https://hardhat.org/hardhat-runner/docs/advanced/building-plugins#extending-the-hardhat-provider).
     * 
     * @param {unknown} provider 
     * @returns {object[]}
     */
    getProviderExtensions(provider) {
        const extensions = [];
        while (provider !== undefined && provider !== null) {
            assert(typeof provider === 'object');
            extensions.push(provider);
            if ('_provider' in provider) provider = provider._provider;
            else if ('_wrappedProvider' in provider) provider = provider._wrappedProvider;
            else if ('provider' in provider) provider = provider.provider;
            else provider = undefined;
        }
        return extensions;
    },

};
