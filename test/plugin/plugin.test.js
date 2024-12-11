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

const { expect } = require('chai');
const { resetHardhatContext } = require('hardhat/plugins-testing');
const path = require('path');

describe('::plugin', function () {
    this.timeout(30000);

    [
        'custom-hardfork-project',
        'fork-block-project',
        'hedera-fork-project',
        'hedera-mainnet-project',
        'message-call-project',
        'non-hedera-project',
    ].forEach(project => {
        describe(`entering project \`${project}\`...`, function () {
            /**@type {import('hardhat/types').HardhatRuntimeEnvironment} */
            let hre;

            beforeEach('loading hardhat environment', function () {
                process.chdir(path.join(__dirname, project));
                hre = require('hardhat');
            });

            afterEach('resetting hardhat', async function () {
                resetHardhatContext();
                (await hre.jsonRPCForwarder)?.terminate();
            });

            it(`hardhat project test for \`${project}\``, async function () {
                const exitCode = await hre.run('test');
                expect(exitCode).to.be.equal(0, 'hardhat test failed');
            });
        });
    });
});
