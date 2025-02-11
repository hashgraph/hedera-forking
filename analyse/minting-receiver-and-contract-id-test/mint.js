import {
    Client,
    PrivateKey,
    TokenMintTransaction,
    Hbar
} from '@hashgraph/sdk';
import dotenv from 'dotenv';

dotenv.config({ path: './.env.mint' });

async function main() {
    const accountId = process.env.ACCOUNT_ID;
    const hexSupplyKey = process.env.SUPPLY_KEY_DER;
    const supplyKey = PrivateKey.fromStringDer(hexSupplyKey);
    const tokenId = process.env.TOKEN_ID;
    if (!accountId || !supplyKey || !tokenId) {
        throw new Error('Missing account ID, supply key, or token ID');
    }
    const client = Client.forTestnet().setOperator(accountId, supplyKey);
    const mintTransaction = new TokenMintTransaction()
        .setTokenId(tokenId)
        .setAmount(3)
        .setMaxTransactionFee(new Hbar(5));
    const mintResponse = await mintTransaction.execute(client);
    await mintResponse.getReceipt(client);
    console.log(`Minted 3 additional tokens. New total supply updated.`);
    client.close();
    process.exit(0);
}

main().catch(error => {
    console.error(error);
    process.exit(1);
});
