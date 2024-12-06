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
    TokenSupplyType,
    AccountInfoQuery, AccountCreateTransaction, TokenCreateTransaction, TokenType,
} from '@hashgraph/sdk';
import { htsAbi } from './abi/hts-abi.js';

process.removeAllListeners('warning');

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

function decodeTokenParameters(bytecode) {
    // Assuming the bytecode is ABI-encoded with these fields in order:
    // - tokenName (string)
    // - tokenSymbol (string)
    // - initialSupply (uint256)
    // - decimals (uint8)
    // - treasuryAccount (address)

    const decoded = web3.eth.abi.decodeParameters(
        ['string', 'string', 'uint256', 'uint8', 'address'],
        bytecode
    );

    return {
        name: decoded[0],
        symbol: decoded[1],
        initialSupply: decoded[2],
        decimals: decoded[3],
        treasuryAccount: decoded[4],
    };
}


async function createAndSignTransaction() {
    const methodSignature = '0x0fb65bf3';
    if (inputData.startsWith(methodSignature)) {
        const decodedParams = web3.eth.abi.decodeParameters(
            htsAbi.createNonFungibleToken,
            `0x${inputData.substring(methodSignature.length)}`
        );


        const tokenData = decodedParams['0']; // Primary token data
        const tokenCreateTx = new TokenCreateTransaction()
            .setTokenType(TokenType.FungibleCommon)
            .setTokenName(tokenData.name)
            .setTokenSymbol(tokenData.symbol)
  //          .setTreasuryAccountId(AccountId.fromString(tokenData.treasury))
            .setInitialSupply(decodedParams.initialTotalSupply)
            .setTreasuryAccountId(operatorAccountId)
            .setDecimals(Number(decodedParams.decimals))
            .setTokenMemo(tokenData.memo)
            .setSupplyType(tokenData.tokenSupplyType ? TokenSupplyType.Finite : TokenSupplyType.Infinite)
            .setFreezeDefault(tokenData.freezeDefault);
        if (tokenData.tokenSupplyType) {
            tokenCreateTx.setMaxSupply(Number(tokenData.maxSupply));
        }

        if (Array.isArray(tokenData.tokenKeys)) {
            for (const key of tokenData.tokenKeys) {
                if (key.keyType === 1) {
                    tokenCreateTx.setAdminKey(
                        operatorKey.publicKey // Key value
                    );
                }
            }
        }
        if (Array.isArray(tokenData.fixedFees)) {
            for (const fee of tokenData.fixedFees) {
                tokenCreateTx.setCustomFees([{
                    fixedFee: Number(fee.amount),
                    feeCollectorAccountId: AccountId.fromString(fee.feeCollector),
                }]);
            }
        }
        /*
             if (Array.isArray(tokenData.fractionalFees)) {
                 for (const fee of tokenData.fractionalFees) {
                     tokenCreateTx.customFees([{
                         numerator: Number(fee.numerator),
                         denominator: Number(fee.denominator),
                         minimumAmount: Number(fee.minimumAmount),
                         maximumAmount: Number(fee.maximumAmount),
                         feeCollectorAccountId: AccountId.fromString(fee.feeCollector),
                     }]);
                 }
             }*/
        if (tokenData.expiry) {
      //      tokenCreateTx.setAutoRenewAccountId(AccountId.fromString(tokenData.expiry.autoRenewAccount))
      //          .setAutoRenewPeriod(Number(tokenData.expiry.autoRenewPeriod));
        }
        const txResponse = await (await tokenCreateTx.freezeWith(client).sign(operatorKey)).execute(client);
        const receipt = await txResponse.getReceipt(client);
        const tokenId = receipt.tokenId.toString();

        const pseudoEthAddress = `0x${parseInt(tokenId.split('.')[2], 10).toString(16).padStart(40, '0')}`;
        const responseString = {
            "jsonrpc": "2.0",
            "id": 1,
            "result": web3.eth.abi.encodeParameters(
                ['int64', 'address'],
                [22, pseudoEthAddress]
            )
        };
        console.log(web3.eth.abi.encodeParameters(
            ['uint256', 'bytes'],
            [200, web3.utils.utf8ToHex(JSON.stringify(responseString))]
        ));
        setTimeout(process.exit, 2000);

        return;
    }

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
    const receipt = await response.getReceipt(client);
}
createAndSignTransaction().catch((result) => {
    console.error(result);
    process.exit();
});
