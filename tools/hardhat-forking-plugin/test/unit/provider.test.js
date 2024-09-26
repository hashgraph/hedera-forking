const sinon = require('sinon');
const { MirrornodeClient } = require('../../src/client');
const { HederaProvider, HTS_ADDRESS } = require('../../src/hedera-provider');

/**
 * Test suite for the `HederaProvider` class.
 */
describe('HederaProvider', function () {
  /** @type {sinon.SinonSandbox} */
  let sandbox;
  /** @type {any} */
  let mockWrappedProvider;
  /** @type {sinon.SinonStubbedInstance<MirrornodeClient>} */
  let mockMirrornode;
  /** @type {HederaProvider} */
  let provider;

  /**
   * Set up the sandbox and mock objects before each test case.
   */
  beforeEach(function () {
    sandbox = sinon.createSandbox();
    mockWrappedProvider = {
      request: sandbox.stub(),
    };
    mockMirrornode = sandbox.createStubInstance(MirrornodeClient);
    provider = new HederaProvider(mockWrappedProvider, mockMirrornode);
  });

  /**
   * Restore the sandbox after each test case.
   */
  afterEach(function () {
    sandbox.restore();
  });

  /**
   * Test that `eth_getCode` is called for HTS and the result is returned from the wrapped provider.
   */
  it('should call eth_getCode for HTS and return result from wrapped provider', async function () {
    mockWrappedProvider.request
      .withArgs({
        method: 'eth_getCode',
        params: [HTS_ADDRESS, 'latest'],
      })
      .resolves({ result: '0x1111111111111111' });

    await provider.request({ method: 'eth_call', params: [] });

    sinon.assert.calledTwice(mockWrappedProvider.request);
    sinon.assert.calledWith(mockWrappedProvider.request, {
      method: 'eth_getCode',
      params: [HTS_ADDRESS, 'latest'],
    });
  });

  /**
   * Test that HTS code is set when not present and the request is delegated to the wrapped provider.
   */
  it('should set HTS code when not present and delegate to wrapped provider', async function () {
    mockWrappedProvider.request
      .withArgs({
        method: 'eth_getCode',
        params: [HTS_ADDRESS, 'latest'],
      })
      .resolves('0x');
    mockWrappedProvider.request
      .withArgs({
        method: 'hardhat_setCode',
        params: [HTS_ADDRESS, 'dummy-bytecode'],
      })
      .resolves();
    await provider.request({ method: 'eth_call', params: [] });

    sinon.assert.calledWith(mockWrappedProvider.request, {
      method: 'eth_getCode',
      params: [HTS_ADDRESS, 'latest'],
    });

    sinon.assert.calledWith(mockWrappedProvider.request, {
      method: 'hardhat_setCode',
      params: [HTS_ADDRESS, sinon.match.string],
    });
  });

  /**
   * Test that setting HTS code is skipped if it is already present.
   */
  it('should skip setting HTS code if it is already present', async function () {
    mockWrappedProvider.request
      .withArgs({
        method: 'eth_getCode',
        params: [HTS_ADDRESS, 'latest'],
      })
      .resolves('0xfefefefefefefefefefefefefeefef');
    await provider.request({ method: 'eth_call', params: [] });

    sinon.assert.calledTwice(mockWrappedProvider.request);
    sinon.assert.neverCalledWith(mockWrappedProvider.request, {
      method: 'hardhat_setCode',
    });
  });

  /**
   * Test handling of balanceOf(address) call.
   */
  it('should handle balanceOf(address) call', async function () {
    const mockAccount = '0x0000000000000000000000000000000000000001';
    const targetTokenAddress = '0x0000000000000000000000000000000000000100';
    const balanceOfCall = `${mockAccount.slice(2).padStart(64, '0')}`;
    const balanceResult = { balances: [{ balance: 1000 }] };

    mockWrappedProvider.request
      .withArgs({
        method: 'eth_getCode',
        params: [HTS_ADDRESS, 'latest'],
      })
      .resolves('0xfe');
    mockMirrornode.getAccount.resolves({ account: '0.0.123' });
    mockMirrornode.getBalanceOfToken.resolves(balanceResult);

    await provider.request({
      method: 'eth_call',
      params: [{ to: targetTokenAddress, data: `0x70a08231${balanceOfCall}` }],
    });

    sinon.assert.calledWith(mockMirrornode.getAccount, sinon.match.string, sinon.match.string);
    sinon.assert.calledWith(
      mockMirrornode.getBalanceOfToken,
      sinon.match.string,
      sinon.match.string,
      sinon.match.string
    );
  });

  /**
   * Test handling of allowance(address,address) call.
   */
  it('should handle allowance(address,address) call', async function () {
    const mockOwner = '0x0000000000000000000000000000000000000001';
    const mockSpender = '0x0000000000000000000000000000000000000002';
    const targetTokenAddress = '0x0000000000000000000000000000000000000100';
    const allowanceCallData = `${mockOwner.slice(2).padStart(64, '0')}${mockSpender.slice(2).padStart(64, '0')}`;
    const allowanceResult = { allowances: [{ amount: 500 }] };

    mockWrappedProvider.request
      .withArgs({
        method: 'eth_getCode',
        params: [HTS_ADDRESS, 'latest'],
      })
      .resolves({ result: '0xfe' });

    mockMirrornode.getAccount.withArgs(mockOwner).resolves({ account: '0.0.1001' });
    mockMirrornode.getAccount.withArgs(mockSpender).resolves({ account: '0.0.1002' });
    mockMirrornode.getAllowanceForToken.resolves(allowanceResult);

    await provider.request({
      method: 'eth_call',
      params: [{ to: targetTokenAddress, data: `0xdd62ed3e${allowanceCallData}` }],
    });

    sinon.assert.calledWith(
      mockMirrornode.getAllowanceForToken,
      sinon.match.string,
      sinon.match.string,
      sinon.match.string,
      sinon.match.string
    );
  });
});
