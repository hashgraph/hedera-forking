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

const path = require('path');
const log = require('util').debuglog('hedera-forking');
const { Worker } = require('worker_threads');
const { extendConfig } = require('hardhat/config');

const chains = {
    295: 'https://mainnet-public.mirrornode.hedera.com/api/v1/',
    296: 'https://testnet.mirrornode.hedera.com/api/v1/',
    297: 'https://previewnet.mirrornode.hedera.com/api/v1/',
};

/**
 * Extends the Hardhat config to setup hardfork history for Hedera networks.
 * This avoids the problem `No known hardfork for execution on historical block`
 * when running a forked network against a Hedera network.
 *
 * Note that the Hardhat config will be extended regardless of the selected network.
 * This is to simplify the `extendConfig` logic and it does not harm having the extra chains config.
 * 
 * We use `shanghai` as the default hardfork because setting this to `cancun` leads to the error
 * 
 * ```
 * internal error: entered unreachable code: error: Header(ExcessBlobGasNotSet)
 * ```
 * 
 * which looks like an issue in EDR
 * https://github.com/NomicFoundation/edr/blob/8aded8ba38da741b6591a9550ab1f71cd138528e/crates/edr_evm/src/block/builder.rs#L99-L103.
 * Nevertheless `cancun` opcodes work fine when running a Hardhat forked network.
 *
 * https://hardhat.org/hardhat-network/docs/guides/forking-other-networks#using-a-custom-hardfork-history
 * https://hardhat.org/hardhat-network/docs/reference#chains
 */
extendConfig((config, userConfig) => {
    const hardhatChains = config.networks.hardhat.chains;
    for (const chainIdKey of Object.keys(chains)) {
        const chainId = Number(chainIdKey);
        // This can be already set if the user configures a custom hardfork for a Hedera network.
        // We don't want to overwrite the value set by the user.
        if (hardhatChains.get(chainId) === undefined) {
            log('Setting hardfork history for chain %d', chainId);
            hardhatChains.set(Number(chainId), {
                hardforkHistory: new Map().set('shanghai', 0)
            });
        } else {
            log(`Hardfork history for chain %d set by the user`, chainId);
        }
    }

    const forking = userConfig.networks?.hardhat?.forking;
    if (forking !== undefined && 'chainId' in forking) {
        // @ts-ignore
        let { chainId, workerPort } = forking;
        if (workerPort === undefined) {
            workerPort = 1234;
        }
        const mirrorNodeUrl = chains[/**@type{keyof typeof chains}*/(chainId)];
        log(`Forking enabled using chainId=${chainId} workerPort=${workerPort}`);
        if (mirrorNodeUrl !== undefined) {
            const scriptPath = path.resolve(__dirname, './json-rpc-forwarder');
            log('Starting JSON-RPC Forwarder server from `%s`', scriptPath);
            const worker = new Worker(scriptPath, {
                workerData: {
                    forkingUrl: forking.url,
                    mirrorNodeUrl,
                    port: workerPort,
                }
            });
            worker.on('error', err => console.log(err));
            worker.on('exit', code => log('worker exited with code %d', code));
            worker.unref();
            process.on('exit', code => log('Main process exited with code %d', code));
            // Should always be true
            if (config.networks.hardhat.forking !== undefined) {
                config.networks.hardhat.forking.url = `http://127.0.0.1:${workerPort}`;
            }
        }
    }
});
