import { expect } from 'chai';
import dotenv from 'dotenv';
import { Wallet, ContractFactory, Contract } from 'ethers';
import { createFixtureLoader, MockProvider } from 'ethereum-waffle';
import IERC20Contract from '../build/IERC20.json' assert { type: "json" };

dotenv.config();

const usdcAddress = process.env.ERC20_TOKEN_ADDRESS || '';
const bob = '0x0000000000000000000000000000000000000887';
const providerConfig =  {
    ganacheOptions: {
        fork: {
            url: process.env.RELAY_ENDPOINT,
        },
        wallet: {
            accounts: [
                {
                    balance: `0x${Number(10 * 10**32).toString(16)}`,
                    secretKey: process.env.OPERATOR_PRIVATE_KEY || '',
                },
            ],
        },
    },
};

describe('RPC', function () {
    this.timeout(100000);
    /**
     * @type {function(any): Promise<Contract>}
     */
    let loadFixture;

    /**
     * @type {function(Wallet[]): Contract}
     */
    let fixture;

    /**
     * @type {Wallet}
     */
    let wallet;

    beforeEach(async () => {
        const provider = new MockProvider(providerConfig);
        wallet = provider.getWallets()[0];
        loadFixture = createFixtureLoader([wallet]);
        fixture = ([wallet]) => ContractFactory.getContract(usdcAddress, IERC20Contract.abi, wallet);
    });

    it('should have initial balance', async () => {
        /**
         * @type {Contract}
         */
        const contract = await loadFixture(fixture);
        const balance = (await contract.balanceOf(wallet.address)).toNumber();

        expect(balance).to.not.equal(0, `Please use an account with a non-zero ${usdcAddress} token balance for this test to function correctly.`);

        const currentBalance = (await contract.balanceOf(wallet.address)).toNumber();
        await contract.transfer(bob, currentBalance); // We transfer everything out.
        expect((await contract.balanceOf(wallet.address)).toNumber()).to.equal(0);
    });

    it('should have some initial balance again!', async () => {
        /**
         * @type {Contract}
         */
        const contract = await loadFixture(fixture);

        const balance = (await contract.balanceOf(wallet.address)).toNumber();

        expect(balance).to.not.equal(0);
    });
});
