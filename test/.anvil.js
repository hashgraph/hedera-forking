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

const { spawn } = require('child_process');

/**
 * Starts a Foundry's [`anvil`](https://book.getfoundry.sh/reference/anvil/) process forking from `forkUrl` on a random port.
 *
 * It uses `--no-storage-caching` to explicitly disable the use of RPC caching.
 * This is to ensure data is always fetched from the JSON-RPC backend.
 * See https://book.getfoundry.sh/reference/forge/forge-test#forking for more details.
 *
 * It resolves to the `host:port` where `anvil` is listening on.
 *
 * ### Examples
 *
 * ```javascript
 * const anvilHost = await anvil('localhost:7546');
 * console.log(anvilHost); // 127.0.0.1:51319
 * ```
 *
 * @param {string} forkUrl the URL to fork from
 * @returns {Promise<string>} the `host:port` where `anvil` is listening on.
 */
function anvil(forkUrl) {
    return new Promise((resolve, reject) => {
        const child = spawn(
            'anvil',
            ['--port=0', `--fork-url=${forkUrl}`, '--no-storage-caching'],
            {
                detached: true,
                stdio: ['ignore', 'pipe', 'pipe'],
            }
        );
        child.stdout.on('data', data => {
            /** @type {string} */
            const message = data.toString();
            const match = message.match(/^Listening on (.+:\d+)$/m);
            if (match !== null) {
                const host = match[1];
                child.stderr.unpipe();
                child.stderr.destroy();
                child.stdout.unpipe();
                child.stdout.destroy();
                resolve(host);
            }
        });
        child.stderr.on('data', err => {
            reject(err.toString());
        });

        process.on('exit', () => {
            const result = child.kill();
            console.log('anvil terminated', result);
        });

        child.unref();
    });
}

module.exports = { anvil };
