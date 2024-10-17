const { expect } = require('chai');
const { ethers, network } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

describe('USDC example', function () {

    async function id() {
        const [receiver, spender] = await ethers.getSigners();
        return { receiver, spender };
    }

    /**
     * https://hashscan.io/testnet/token/0.0.429274
     * https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
     */
    const usdcAddress = '0x0000000000000000000000000000000000068cDa';

    /** @type {import('ethers').Contract} */
    let usdc;

    /**
     * https://hashscan.io/testnet/account/0.0.8196
     * 
     * @type {import('@nomicfoundation/hardhat-ethers/signers').HardhatEthersSigner}
     */
    let holder;

    beforeEach(async () => {
        usdc = await ethers.getContractAt('IERC20', usdcAddress);

        const holderAddress = '0x0000000000000000000000000000000000002004';
        // https://hardhat.org/hardhat-network/docs/reference#hardhat_impersonateaccount
        await network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [holderAddress],
        });
        holder = await ethers.getSigner(holderAddress);
    });

    it('should get name, symbol and decimals', async function () {
        const name = await usdc['name']();
        const symbol = await usdc['symbol']();
        const decimals = await usdc['decimals']();
        expect(name).to.be.equal('USD Coin');
        expect(symbol).to.be.equal('USDC');
        expect(decimals).to.be.equal(6n);
    });

    it('should get Token name through a contract call', async function () {
        const CallToken = await ethers.getContractFactory('CallToken');
        const callToken = await CallToken.deploy();

        expect(await callToken['getTokenName'](usdcAddress))
            .to.be.equal('USD Coin');

        // Another HTS Token created for test purposes
        expect(await callToken['getTokenName']('0x000000000000000000000000000000000047b52a'))
            .to.be.equal('Very long string, just to make sure that it exceeds 31 bytes and requires more than 1 storage slot.');
    });

    it('should get `balanceOf` account holder', async function () {
        const balance = await usdc['balanceOf'](holder.getAddress());
        expect(balance).to.be.greaterThan(0n);
    });

    it("should `tranfer` tokens from account holder to one of Hardhat' signers", async function () {
        const { receiver } = await loadFixture(id);

        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(0n);

        // @ts-ignore
        await usdc.connect(holder)['transfer'](receiver, 10_000_000n);

        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(10_000_000n);
    });

    it("should `tranferFrom` tokens from account holder after `approve`d one of Hardhat' signers", async function () {
        const { receiver, spender } = await loadFixture(id);
        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(0n);

        // @ts-ignore
        await usdc.connect(holder)['approve'](spender, 5_000_000n);

        expect(await usdc['allowance'](holder.address, spender.address)).to.be.equal(5_000_000n);

        // @ts-ignore
        await usdc.connect(spender)['transferFrom'](holder.address, receiver, 3_000_000n);

        expect(await usdc['allowance'](holder.address, spender.address)).to.be.equal(2_000_000n);
        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(3_000_000n);
    });
});
