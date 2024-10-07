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

describe('custom-hardfork-project', function () {

    it("should not override user's hardfork customization", async function () {
        const { chains } = /** @type{import('hardhat/types').HardhatNetworkConfig} */(hre.network.config);
        expect(chains.get(295)).to.be.deep.equal({
            hardforkHistory: new Map().set('shanghai', 0)
        });
        expect(chains.get(296)).to.be.deep.equal({
            hardforkHistory: new Map().set('cancun', 1)
        });
        expect(chains.get(297)).to.be.deep.equal({
            hardforkHistory: new Map().set('shanghai', 0)
        });
    });

});
