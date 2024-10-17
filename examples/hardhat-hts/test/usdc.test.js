const { expect } = require('chai');
const { ethers, network } = require('hardhat');

describe('USDC example', function () {

    /**
     * https://hashscan.io/testnet/token/0.0.429274
     * https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
     * 
     * @type {import('ethers').Contract}
     */
    let usdc;

    /**
     * https://hashscan.io/testnet/account/0.0.8196
     * 
     * @type {import('@nomicfoundation/hardhat-ethers/signers').HardhatEthersSigner}
     */
    let holder;

    beforeEach(async () => {
        usdc = await ethers.getContractAt('IERC20', '0x0000000000000000000000000000000000068cDa');

        const holderAddress = '0x0000000000000000000000000000000000002004';
        // https://hardhat.org/hardhat-network/docs/reference#hardhat_impersonateaccount
        await network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [holderAddress],
        });
        holder = await ethers.getSigner(holderAddress);
    });

    it('should get name and symbol', async function () {
        const name = await usdc['name']();
        const symbol = await usdc['symbol']();
        const decimals = await usdc['decimals']();
        expect(name).to.be.equal('USD Coin');
        expect(symbol).to.be.equal('USDC');
        expect(decimals).to.be.equal(6n);
    });

    it('should get `balanceOf` account holder', async function () {
        const balance = await usdc['balanceOf'](holder.getAddress());
        expect(balance).to.be.greaterThan(0n);
    });

    it("should `tranfer` tokens from account holder to one of Hardhat' signers", async function () {
        const [receiver] = await ethers.getSigners();
        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(0n);

        // @ts-ignore
        await usdc.connect(holder)['transfer'](receiver, 10_000_000n);

        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(10_000_000n);
    });

});
