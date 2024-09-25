import { expect } from 'chai';
import dotenv from 'dotenv';
import { providers, Wallet, ContractFactory, Contract } from 'ethers';
import { createFixtureLoader } from 'ethereum-waffle';
import IERC20Contract from '../build/IERC20.json' assert { type: "json" };

dotenv.config();
const { JsonRpcProvider } = providers;

const usdcAddress = process.env.ERC20_TOKEN_ADDRESS || '';
const bob = '0x0000000000000000000000000000000000000887';

describe('RPC', () => {
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
        /**
         * @type {providers.JsonRpcProvider}
         */
        const provider = new JsonRpcProvider(process.env.RELAY_ENDPOINT);

        wallet = new Wallet(process.env.OPERATOR_PRIVATE_KEY, provider);

        // Assign the fixture loader
        loadFixture = createFixtureLoader([wallet]);

        // The fixture returns a Contract instance for IERC20
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
