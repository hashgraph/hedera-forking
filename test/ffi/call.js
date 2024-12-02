import Web3 from 'web3';
import { AccessListEIP2930Transaction } from '@ethereumjs/tx';
import { Common } from '@ethereumjs/common';
import { Address } from '@ethereumjs/util';
import { ethers } from 'ethers';
import {
    Client,
    PrivateKey,
    EthereumTransaction,
    Hbar,
    AccountId,
    TransactionId,
    AccountInfoQuery, AccountCreateTransaction,
} from '@hashgraph/sdk';
import dotenv from 'dotenv';
dotenv.config();
const OPERATOR_PRIVATE_KEY = process.env['OPERATOR_PRIVATE_KEY'] || '';
const RELAY_ENDPOINT = process.env['RELAY_ENDPOINT'] || '';
if (!OPERATOR_PRIVATE_KEY || !RELAY_ENDPOINT) {
    console.error('Missing OPERATOR_PRIVATE_KEY or RELAY_ENDPOINT in .env');
    process.exit(1);
}
const args = process.argv.slice(2);
if (args.length < 4) {
    console.error('Usage: node call.js <inputData> <fromAddress> <toAddress> <gasLimit>');
    process.exit(1);
}
const operatorKey = PrivateKey.fromStringDer('302e020100300506032b65700422042091132178e72057a1d7528025956fe39b0b847f200ab59b2fdd367017f3087137');
const operatorAccountId = new AccountId(2);
const client = Client.forNetwork({
    '127.0.0.1:50211': new AccountId(3),
});
client.setOperator(operatorAccountId, operatorKey);

// @ts-ignore
const web3 = new Web3(RELAY_ENDPOINT);
const [inputData, fromAddress, toAddress, gasLimit] = args;
const privateKey = Buffer.from(OPERATOR_PRIVATE_KEY.substring(2), 'hex');
const txParams = {
    nonce: BigInt(0),
    gasPrice: BigInt(0),
    gasLimit: BigInt(parseInt(gasLimit, 16)),
    to: Address.fromString(toAddress),
    value: BigInt(0),
    data: ethers.toUtf8Bytes(inputData),
};

async function createAccountIfDoesNotExist(evmAddress) {
    try {
        await new AccountInfoQuery()
            .setAccountId(evmAddress)
            .execute(client);
    } catch (error) {
        // Seems like the account does not exist... For now, we are only checking to which is not enough
        // for transfer to transactions...
    }
    const newKey = PrivateKey.generateED25519();
    await new AccountCreateTransaction()
        .setKey(newKey.publicKey)
        .setInitialBalance(new Hbar(10))
        .execute(client);

    // todo
}


async function createAndSignTransaction() {
    txParams.nonce = await web3.eth.getTransactionCount(fromAddress, 'latest');
    txParams.gasPrice = await web3.eth.getGasPrice();
    const chainId = 298;//await web3.eth.getChainId();
    const common = Common.custom(
        {
            name: "hedera-local",
            chainId,
            networkId: chainId,
        },
        { baseChain: "mainnet" }
    );
    const tx = AccessListEIP2930Transaction.fromTxData(txParams, { common });
    const signedTx = tx.sign(privateKey);
    const serializedTx = signedTx.serialize();
    const txId = TransactionId.generate(operatorAccountId)
    const ethereumTransaction = await new EthereumTransaction()
        .setTransactionId(txId)
        .setEthereumData(serializedTx)
        .setMaxGasAllowanceHbar(new Hbar(1000000000))
        .freezeWith(client)
        .sign(operatorKey);
    const response = await ethereumTransaction.execute(client);
    console.log(response.toJSON());
    const receipt = await response.getReceipt(client);
    console.log("Transaction status:", receipt.status.toString());
}
createAndSignTransaction().catch(console.error);
