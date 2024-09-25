import sinon from 'sinon';

import { MirrornodeClient } from '../../src/client';
import { HederaProvider, HTS_ADDRESS } from '../../src/hedera-provider';

describe('HederaProvider', function () {
  let sandbox: sinon.SinonSandbox;
  let mockWrappedProvider: any;
  let mockMirrornode: sinon.SinonStubbedInstance<MirrornodeClient>;
  let provider: HederaProvider;

  beforeEach(function () {
    sandbox = sinon.createSandbox();
    mockWrappedProvider = {
      request: sandbox.stub(),
    };
    mockMirrornode = sandbox.createStubInstance(MirrornodeClient);
    provider = new HederaProvider(mockWrappedProvider, mockMirrornode);
  });

  afterEach(function () {
    sandbox.restore();
  });

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
