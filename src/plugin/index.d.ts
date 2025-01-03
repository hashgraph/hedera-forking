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

declare module 'hardhat/types/config' {
    interface HardhatNetworkForkingConfig {
        /**
         * The Hedera network chain ID to use when forking is enabled.
         */
        chainId?: number;

        /**
         * The Mirror Node URL used to fetch Hedera entity data determined by `chainId`.
         */
        mirrorNodeUrl?: string;

        /**
         * A TCP port where the JSON-RPC Forwarder will listen if Hedera forking is enabled.
         * If not provided, a default value will be used.
         */
        workerPort?: number;

        /**
         * List of [initial addresses](https://hardhat.org/hardhat-network/docs/reference#initial-state) used by Hardhat Network when forking.
         *
         * The JSON-RPC Forwarder will **not** forward
         * `eth_getCode` and `eth_getBalance` method calls for these addresses.
         * They **should not** have any associated code nor balance in the remote network.
         * It is intended as a way to make fewer requests to the remote JSON-RPC Relay.
         */
        localAddresses?: string[];
    }
}

declare module 'hardhat/types/runtime' {
    interface HardhatRuntimeEnvironment {
        jsonRPCForwarder?: Promise<import('worker_threads').Worker & { host: string }>;
    }
}

// Signals to TypeScript this file is a module and not a script.
// This suppresses missing type error when requiring this module.
export {};
