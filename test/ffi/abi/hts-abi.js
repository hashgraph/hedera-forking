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

export const htsAbi = {
    transferFrom: [
        { name: 'from', type: 'address' },
        { name: 'to', type: 'address' },
        { name: 'amount', type: 'uint256' },
    ],
    createNonFungibleToken: [
        {
            type: 'tuple',
            components: [
                { name: 'name', type: 'string' },
                { name: 'symbol', type: 'string' },
                { name: 'treasury', type: 'address' },
                { name: 'memo', type: 'string' },
                { name: 'tokenSupplyType', type: 'bool' },
                { name: 'maxSupply', type: 'int64' },
                { name: 'freezeDefault', type: 'bool' },
                {
                    name: 'tokenKeys',
                    type: 'tuple[]',
                    components: [
                        { name: 'keyType', type: 'uint256' },
                        {
                            name: 'key',
                            type: 'tuple',
                            components: [
                                { name: 'inheritAccountKey', type: 'bool' },
                                { name: 'contractId', type: 'address' },
                                { name: 'ed25519', type: 'bytes' },
                                { name: 'ECDSA_secp256k1', type: 'bytes' },
                                { name: 'delegatableContractId', type: 'address' },
                            ],
                        },
                    ],
                },
                {
                    name: 'expiry',
                    type: 'tuple',
                    components: [
                        { name: 'second', type: 'int64' },
                        { name: 'autoRenewAccount', type: 'address' },
                        { name: 'autoRenewPeriod', type: 'int64' },
                    ],
                },
            ],
        },
        { name: 'initialTotalSupply', type: 'int64' },
        { name: 'decimals', type: 'int32' },
    ],
};
