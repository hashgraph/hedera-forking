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

export interface Expiry {
    second: number;
    autoRenewAccount: string;
    autoRenewPeriod: number;
}

interface KeyValue {
    inheritAccountKey: boolean;
    contractId: string;
    ed25519: string;
    ECDSA_secp256k1: string;
    delegatableContractId: string;
}

interface TokenKey {
    keyType: number;
    key: KeyValue;
}

interface HederaToken {
    name: string;
    symbol: string;
    treasury: string;
    memo: string;
    tokenSupplyType: boolean;
    maxSupply: number;
    freezeDefault: boolean;
    tokenKeys: TokenKey[];
    expiry: Expiry;
}

interface FixedFee {
    amount: number;
    tokenId: string;
    useHbarsForPayment: boolean;
    useCurrentTokenForPayment: boolean;
    feeCollector: string;
}

interface FractionalFee {
    numerator: number;
    denominator: number;
    minimumAmount: number;
    maximumAmount: number;
    netOfTransfers: boolean;
    feeCollector: string;
}

interface RoyaltyFee {
    numerator: number;
    denominator: number;
    amount: number;
    tokenId: string;
    useHbarsForPayment: boolean;
    feeCollector: string;
}

export interface TokenInfo {
    token: HederaToken;
    totalSupply: number;
    deleted: boolean;
    defaultKycStatus: boolean;
    pauseStatus: boolean;
    fixedFees: FixedFee[];
    fractionalFees: FractionalFee[];
    royaltyFees: RoyaltyFee[];
    ledgerId: string;
}
