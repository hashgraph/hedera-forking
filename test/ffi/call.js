import Web3 from 'web3';
import {
    Client,
    PrivateKey,
    Hbar,
    AccountId,
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
if (args.length < 3) {
    console.error('Usage: node call.js <inputData> <fromAddress> <toAddress>');
    process.exit(1);
}
const operatorKey = PrivateKey.fromStringDer('302e020100300506032b65700422042091132178e72057a1d7528025956fe39b0b847f200ab59b2fdd367017f3087137');
const operatorAccountId = new AccountId(2);
const client = Client.forNetwork({
    '127.0.0.1:50211': new AccountId(3),
});
client.setOperator(operatorAccountId, operatorKey);

const web3 = new Web3(RELAY_ENDPOINT);
const [inputData, fromAddress, toAddress] = args;

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
    // The selector of: createFungibleToken((string,string,address,string,bool,int64,bool,(uint256,(bool,address,bytes,bytes,address))[],(int64,address,int64)),int64,int32)
    const methodSignature = '0x0fb65bf3';
    if (inputData.startsWith(methodSignature)) {
        const decodedParams = web3.eth.abi.decodeParameters(
            htsAbi.createNonFungibleToken,
            `0x${inputData.substring(methodSignature.length)}`
        )
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
    process.exit();
}
createAndSignTransaction().catch((result) => {
    console.error(result);
    process.exit();
});
