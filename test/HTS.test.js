
const { strict: assert } = require('assert');
const { expect } = require('chai');
const { Interface } = require('ethers');
const { Contract, AbiCoder } = require('ethers');
const { JsonRpcProvider } = require('ethers');
require('./utils/snapshot');

const HTSAddr = '0x0000000000000000000000000000000000000167';

const abiCoder = AbiCoder.defaultAbiCoder();

/**
 * @typedef {(provider: JsonRpcProvider, tokenAddr: string, bytesData: string) => Promise<[string, string]>} CallStrategy
 */

const RedirectForToken = {
    /** @type {CallStrategy} */
    abi: async (provider, tokenAddr, bytesData) => {
        const contract = new Contract(HTSAddr, [
            'function redirectForToken(address,bytes) view returns (int,bytes)',
        ], provider)

        const [status, result] = await contract.redirectForToken(tokenAddr, bytesData);
        expect(status).to.be.equal(22n);
        return [null, result];
    },
    /** @type {CallStrategy} */
    call: async (provider, tokenAddr, bytesData) => {
        const HTS = new Contract(HTSAddr, [
            'function redirectForToken(address,bytes) view returns (int,bytes)',
        ])
        const data = HTS.interface.encodeFunctionData('redirectForToken', [tokenAddr, bytesData]);
        const response = await provider.call({ to: HTSAddr, data });
        const [status, result] = abiCoder.decode(['uint256', 'bytes'], response);
        expect(status).to.be.equal(22n);
        return [data, result];
    },
    /** @type {CallStrategy} */
    proxy: async (provider, tokenAddr, bytesData) => {
        const data = `0x618dc65e${tokenAddr.slice(2)}${bytesData.slice(2)}`;
        const result = await provider.call({ to: HTSAddr, data });
        return [data, result];
    }
};

const RPC_URL = process.env['RPC_URL'];

describe(`::HTS <RPC_URL=${RPC_URL ?? 'not set, skipping'}>`, function () {

    /** @type {JsonRpcProvider} */
    let provider;

    before(function () {
        if (!RPC_URL) {
            this.skip();
        }
        provider = new JsonRpcProvider(RPC_URL);
    });

    const IERC20 = new Interface([
        'function name() view returns (string)',
        'function totalSupply() view returns (uint256)',
        'function balanceOf(address owner) view returns (uint256)',
    ]);

    [{
        name: 'USDC',
        addr: '0x0000000000000000000000000000000000068cDa',
        invokes: [
            ['name'],
            ['totalSupply'],
            ['balanceOf', [HTSAddr]],
        ],
    }, {
        name: 'No Token',
        addr: '0xdA743Ce0Eb7cC541093F030A3126bF9e3d427E93',
        invokes: [
            ['totalSupply'],
        ],
    }].forEach(({ name, addr, invokes }) => {
        describe(`${name}(${addr})`, function () {
            describe('redirectForToken', function () {
                invokes.forEach(([method, args]) => {
                    const fragment = IERC20.getFunction(method);
                    assert(fragment.outputs.length === 1, 'Tuples are not allowed for return types');
                    const output = fragment.outputs[0];

                    describe(`${fragment.format('sighash')}:${output.format()}`, function () {
                        const bytes = IERC20.encodeFunctionData(method, args);

                        [
                            RedirectForToken.abi,
                            RedirectForToken.call,
                            RedirectForToken.proxy,
                        ].forEach(fn => {
                            it(`${fn.name}`, async function () {
                                const [calldata, result] = await fn(provider, addr, bytes);
                                const [decoded] = abiCoder.decode([output], result).toArray();
                                expect(result).to.matchCall(calldata, decoded, this);
                            });
                        });
                    });
                });
            });
        });
    });
});
