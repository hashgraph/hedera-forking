import { ethers } from 'ethers';
import dotenv from 'dotenv';
import fs from 'fs';

const data = fs.readFileSync('./IHederaTokenService.json', 'utf8');
const IHederaTokenService = JSON.parse(data);

dotenv.config({ path: './.env.keys' });

const HEDERA_RPC_URL = 'https://testnet.hashio.io/api';

async function main() {
    const tokenAddress = process.env.TOKEN_ADDRESS;
    const privateKey = process.env.PRIVATE_KEY_ECDSA_HEX;

    if (!tokenAddress || !privateKey) {
        throw new Error('TOKEN_ADDRESS or PRIVATE_KEY is missing from .env');
    }

    const provider = new ethers.JsonRpcProvider(HEDERA_RPC_URL);
    const wallet = new ethers.Wallet(privateKey, provider);
    const hederaTokenService = new ethers.Contract(`0x${'167'.padStart(40, '0')}`, IHederaTokenService.abi, wallet);

    const tx = await hederaTokenService.getFungibleTokenInfo(tokenAddress, {
        gasLimit: 500000,
    });
    await tx.wait();
    const response = await fetch(`https://testnet.mirrornode.hedera.com/api/v1/contracts/results/${tx.hash}`);

    const result = (await response.json()).call_result;

    const functionAbi = IHederaTokenService.abi.find(fn => fn.name === 'getFungibleTokenInfo');
    const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
        functionAbi.outputs,
        result
    );
    console.log(decoded[1][0][0][7]);

    decoded[1][0][0][7].forEach((key, index) => {
        console.log(`Key ${index + 1}: Type - ${key[0]}, Key - ${key[1][3]},  Contract Id - ${key[1][1]}`);
    });

    process.exit(0);
}

main().catch(error => {
    console.error(error);
    process.exit(1);
});
