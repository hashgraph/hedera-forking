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

import dotenv from 'dotenv';
import {
    AccountId,
    AccountInfoQuery,
    Client,
    Hbar,
    TokenCreateTransaction,
    TokenSupplyType,
    TokenType,
    TransferTransaction,
    TransactionId,
    PrivateKey,
    TokenId,
} from '@hashgraph/sdk';
import { eth, utils } from 'web3';

import { htsAbi } from './abi/hts-abi.js';

/**
 * @typedef {Object} CreateFungibleTokenData
 * @property {string} name - The name of the token.
 * @property {string} symbol - The symbol of the token.
 * @property {string} memo - The memo associated with the token.
 * @property {boolean} tokenSupplyType - Whether the token has finite supply (true) or infinite supply (false).
 * @property {boolean} freezeDefault - Whether the token is frozen by default.
 * @property {number} [maxSupply] - The maximum supply of the token, applicable if `tokenSupplyType` is true.
 * @property {Array<{keyType: number}>} [tokenKeys] - Array of token key objects containing the type of key.
 * @property {{autoRenewAccount: string, autoRenewPeriod: number}} [expiry] - Expiry settings for the token.
 */

/**
 * @typedef {Object} CreateFungibleTokenDecodedParams
 * @property {CreateFungibleTokenData} tokenData - Primary token data.
 * @property {number} initialTotalSupply - The initial total supply of the token.
 * @property {number} decimals - The number of decimals for the token.
 */

/**
 * @typedef {Object} TransferFromDecodedParams
 * @property {string} from - The address of the sender in EVM-compatible format.
 * @property {string} to - The address of the receiver in EVM-compatible format.
 * @property {string | number} amount - The amount of tokens to transfer.
 */

/**
 * @typedef {Object} TransferFromData
 * @property {string} from - The address of the token sender (extracted from `DecodedParams`).
 * @property {string} to - The address of the token receiver (extracted from `DecodedParams`).
 * @property {string | Number} amount - The amount of tokens to transfer.
 */

process.removeAllListeners('warning');
dotenv.config();
const OPERATOR_PRIVATE_KEY = process.env['OPERATOR_PRIVATE_KEY'] || '';

if (!OPERATOR_PRIVATE_KEY) {
    console.error('Missing OPERATOR_PRIVATE_KEY in .env');
    process.exit(1);
}
const args = process.argv.slice(2);
if (args.length < 3) {
    console.error('Usage: node call.js <inputData> <fromAddress> <toAddress>');
    process.exit(1);
}
const operatorKey = PrivateKey.fromStringDer(OPERATOR_PRIVATE_KEY);
const operatorAccountId = new AccountId(2);
const client = Client.forNetwork({
    '127.0.0.1:50211': new AccountId(3),
});
client.setOperator(operatorAccountId, operatorKey);

const [inputData, _fromAddress, toAddress] = args;

/**
 * Retrieves the Hedera account ID associated with a given EVM address.
 * If the account does not exist, it creates a new account by transferring HBAR to the specified EVM address.
 *
 * @async
 * @function getAccountIdOrCreateNewIfDoesNotExist
 * @param {string} evmAddress - The EVM address to query or create an associated Hedera account for.
 * @returns {Promise<AccountId>} - Returns the Hedera account ID as a string.
 *
 * @throws Will throw an error if the transaction or account creation process fails.
 *
 * @example
 * const evmAddress = "0x1234abcd...";
 * const accountId = await getAccountIdOrCreateNewIfDoesNotExist(evmAddress);
 * console.log(`Hedera Account ID: ${accountId}`);
 *
 * @note
 * - Ensure the client is initialized with sufficient HBAR in the operator's account to fund new accounts.
 * - This function performs two operations:
 *   1. Queries for an existing account linked to the EVM address.
 *   2. If no account is found, creates a new one by transferring HBAR.
 */
async function getAccountIdOrCreateNewIfDoesNotExist(evmAddress) {
    try {
        const accountInfo = await new AccountInfoQuery().setAccountId(evmAddress).execute(client);
        return accountInfo.accountId;
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
    } catch (_error) {
        const transaction = new TransferTransaction()
            .addHbarTransfer(operatorAccountId, new Hbar(100).negated())
            .addHbarTransfer(evmAddress, new Hbar(100));

        const response = await transaction.execute(client);
        await response.getReceipt(client);
        const accountInfo = await new AccountInfoQuery().setAccountId(evmAddress).execute(client);
        return accountInfo.accountId;
    }
}

async function createAndSignTransaction() {
    // The selector of: createFungibleToken((string,string,address,string,bool,int64,bool,(uint256,(bool,address,bytes,bytes,address))[],(int64,address,int64)),int64,int32)
    const methodSignature = '0x0fb65bf3';
    if (inputData.startsWith(methodSignature)) {
        /** @type {CreateFungibleTokenDecodedParams|any} */
        const decodedParams = eth.abi.decodeParameters(
            htsAbi.createNonFungibleToken,
            `0x${inputData.substring(methodSignature.length)}`
        );
        /** @type {CreateFungibleTokenData} */
        const tokenData = decodedParams['0'];
        const tokenCreateTx = new TokenCreateTransaction()
            .setTokenType(TokenType.FungibleCommon)
            .setTokenName(tokenData.name)
            .setTokenSymbol(tokenData.symbol)
            .setInitialSupply(decodedParams.initialTotalSupply)
            .setTreasuryAccountId(operatorAccountId)
            .setDecimals(Number(decodedParams.decimals))
            .setTokenMemo(tokenData.memo)
            .setSupplyType(
                tokenData.tokenSupplyType ? TokenSupplyType.Finite : TokenSupplyType.Infinite
            )
            .setFreezeDefault(tokenData.freezeDefault);
        if (tokenData.tokenSupplyType) {
            tokenCreateTx.setMaxSupply(Number(tokenData.maxSupply));
        }

        if (Array.isArray(tokenData.tokenKeys)) {
            for (const key of tokenData.tokenKeys) {
                if (key.keyType === 1) {
                    tokenCreateTx.setAdminKey(operatorKey.publicKey);
                }
            }
        }
        const txResponse = await (
            await tokenCreateTx.freezeWith(client).sign(operatorKey)
        ).execute(client);
        const receipt = await txResponse.getReceipt(client);
        if (!receipt.tokenId) {
            return;
        }
        const tokenId = receipt.tokenId.toString();
        const pseudoEthAddress = `0x${parseInt(tokenId.split('.')[2], 10).toString(16).padStart(40, '0')}`;
        const responseString = {
            'jsonrpc': '2.0',
            'id': 1,
            'result': eth.abi.encodeParameters(['int64', 'address'], [22, pseudoEthAddress]),
        };
        console.log(
            eth.abi.encodeParameters(
                ['uint256', 'bytes'],
                [200, utils.utf8ToHex(JSON.stringify(responseString))]
            )
        );
        setTimeout(process.exit, 2000);

        return;
    }
    // The selector of: transferFrom(address,address,uint256)
    const transferFromSelector = '0x41423b872dd';
    const proxyPrefix = '0x618dc65e';
    const wholePrefix = proxyPrefix.padEnd(47, '0') + transferFromSelector.substring(2);
    if (inputData.startsWith(wholePrefix)) {
        /** @type {TransferFromData|any} */
        const transferData = eth.abi.decodeParameters(
            htsAbi.transferFrom,
            `0x${inputData.substring(wholePrefix.length)}`
        );
        const from = await getAccountIdOrCreateNewIfDoesNotExist(transferData.from);
        const to = await getAccountIdOrCreateNewIfDoesNotExist(transferData.to);
        const tokenId = TokenId.fromString(`0.0.${parseInt(toAddress, 16)}`);
        const transferTx = new TransferTransaction()
            .addApprovedTokenTransfer(tokenId, from, -parseInt(transferData.amount))
            .addTokenTransfer(tokenId, to, parseInt(transferData.amount))
            .setTransactionId(TransactionId.generate(operatorAccountId))
            .freezeWith(client);
        const signedTransferTx = await transferTx.sign(operatorKey);
        const transferResponse = await signedTransferTx.execute(client);
        await transferResponse.getReceipt(client);
        const responseString = {
            'jsonrpc': '2.0',
            'id': 1,
            'result': eth.abi.encodeParameters(['int64', 'bool'], [22, true]),
        };
        console.log(
            eth.abi.encodeParameters(
                ['uint256', 'bytes'],
                [200, utils.utf8ToHex(JSON.stringify(responseString))]
            )
        );
        setTimeout(process.exit, 2000);
    }
    process.exit();
}
createAndSignTransaction().catch(result => {
    console.error(result);
    process.exit();
});
