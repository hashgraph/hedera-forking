import {
    Client,
    PrivateKey,
    TokenCreateTransaction,
    Hbar,
} from '@hashgraph/sdk';
import dotenv from 'dotenv';

dotenv.config({ path: './.env.create' });

async function main() {
    const accountId = process.env.ACCOUNT_ID;
    const hexPrivateKey = process.env.PRIVATE_KEY_DER;
    const privateKey = PrivateKey.fromStringDer(hexPrivateKey);
    const supplyKey = PrivateKey.fromStringDer(process.env.SUPPLY_KEY_DER);
    if (!privateKey || !accountId || !supplyKey) {
        throw new Error('Missing account ID or private key');
    }
    const client = Client.forTestnet().setOperator(accountId, privateKey);
    const transaction = new TokenCreateTransaction()
        .setTokenName('MyTestToken')
        .setTokenSymbol('MTT')
        .setTreasuryAccountId(accountId)
        .setInitialSupply(1000000)
        .setDecimals(2)
        .setSupplyType(0)
        .setSupplyKey(supplyKey)
        .setAdminKey(privateKey)
        .setMaxTransactionFee(new Hbar(10));

    const txResponse = await transaction.execute(client);
    const receipt = await txResponse.getReceipt(client);
    const tokenId = receipt.tokenId;

    console.log(`Token created successfully with ID: ${tokenId}`);
    client.close();
    process.exit(0);
}

main().catch(error => {
    console.error(error);
    process.exit(1);
});
