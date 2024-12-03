#!/usr/bin/env node --env-file=.env

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

import { Hbar, Client, PrivateKey, TokenCreateTransaction, CustomFixedFee } from '@hashgraph/sdk';

async function main() {
  // Grab your Hedera testnet account ID and private key from the .env file
  const { ACCOUNT_ID: accountId, PRIVATE_KEY: privateKey } = process.env;

  if (!accountId || !privateKey)
    throw new Error("Environment variables ACCOUNT_ID and PRIVATE_KEY must be present");

  // Create your Hedera Testnet client and set the operator
  const client = Client.forTestnet();
  // Uncomment the following to create the token in a Local Network
  // const client = Client.forNetwork({
  //   '127.0.0.1:50211': new AccountId(3),
  // });

  client.setOperator(accountId, PrivateKey.fromStringDer(privateKey))
    .setDefaultMaxTransactionFee(new Hbar(100)) // Set default max transaction fee
    .setDefaultMaxQueryPayment(new Hbar(50)); // Set max payment for queries
  console.log("Client setup complete.");

  // Create a new token with specified properties
  const transaction = new TokenCreateTransaction()
    .setTokenName("MyFirstCryptoToken")
    .setTokenSymbol("MFCT")
    .setTreasuryAccountId(accountId)
    .setInitialSupply(15000)
    .setAdminKey(PrivateKey.fromStringDer(privateKey))
    .setCustomFees([
      new CustomFixedFee({ amount: 1, feeCollectorAccountId: "0.0.2669675" }),
      new CustomFixedFee({ amount: 1, feeCollectorAccountId: "0.0.3465", denominatingTokenId: '0.0.429274' }),
    ])
    .freezeWith(client); // Freeze the transaction for signing

  const response = await (await transaction.sign(PrivateKey.fromStringDer(privateKey))).execute(client);
  const receipt = await response.getReceipt(client);

  const tokenId = receipt.tokenId;
  console.log(`The new token ID is ${tokenId}`);
  console.log(`https://hashscan.io/testnet/token/${tokenId}`);
}

main().catch(console.error);
