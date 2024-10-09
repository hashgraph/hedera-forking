/*-
 * Hedera Hardhat Forking Plugin
 *
 * Copyright (C) 2024 Hedera Hashgraph, LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

const sinon = require('sinon');
const { MirrorNodeClient } = require('../src/mirror-node-client');
const { HederaProvider, HTS_ADDRESS } = require('../src/hedera-provider');

describe('::HederaProvider', function () {
  /** @type {sinon.SinonSandbox} */
  let sandbox;
  /** @type {any} */
  let mockWrappedProvider;
  /** @type {sinon.SinonStubbedInstance<MirrorNodeClient>} */
  let mockMirrornode;
  /** @type {HederaProvider} */
  let provider;

  beforeEach(function () {
    sandbox = sinon.createSandbox();
    mockWrappedProvider = {
      request: sandbox.stub(),
    };
    mockMirrornode = sandbox.createStubInstance(MirrorNodeClient);
    provider = new HederaProvider(mockWrappedProvider, mockMirrornode);
  });

  afterEach(function () {
    sandbox.restore();
  });

  it('should call `eth_getCode` for HTS and return result from wrapped provider', async function () {
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

  it('should set HTS code when not present and delegate request to wrapped provider', async function () {
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

  it('should handle `balanceOf(address)` call', async function () {
    const mockAccount = '0x0000000000000000000000000000000000000001';
    const targetTokenAddress = '0x0000000000000000000000000000000000000100';
    const balanceOfCall = `${mockAccount.slice(2).padStart(64, '0')}`;

    mockWrappedProvider.request
      .withArgs({
        method: 'eth_getCode',
        params: [HTS_ADDRESS, 'latest'],
      })
      .resolves('0xfe');
    mockMirrornode.getAccount.resolves({ account: '0.0.123' });
    mockMirrornode.getBalanceOfToken.resolves({ balances: [{ balance: 1000 }] });

    await provider.request({
      method: 'eth_call',
      params: [{ to: targetTokenAddress, data: `0x70a08231${balanceOfCall}` }],
    });

    sinon.assert.calledWith(mockMirrornode.getAccount, sinon.match.string);
    sinon.assert.calledWith(mockMirrornode.getBalanceOfToken, sinon.match.string, sinon.match.string,);
  });

  it('should handle `balanceOf(address)` call even when `getBalanceOfToken` returns null', async function () {
    const mockAccount = '0x0000000000000000000000000000000000000001';
    const targetTokenAddress = '0x0000000000000000000000000000000000000100';
    const balanceOfCall = `${mockAccount.slice(2).padStart(64, '0')}`;

    mockWrappedProvider.request
      .withArgs({
        method: 'eth_getCode',
        params: [HTS_ADDRESS, 'latest'],
      })
      .resolves('0xfe');
    mockMirrornode.getAccount.resolves({ account: '0.0.123' });
    mockMirrornode.getBalanceOfToken.resolves(null);

    await provider.request({
      method: 'eth_call',
      params: [{ to: targetTokenAddress, data: `0x70a08231${balanceOfCall}` }],
    });

    sinon.assert.calledWith(mockMirrornode.getAccount, sinon.match.string);
    sinon.assert.calledWith(mockMirrornode.getBalanceOfToken, sinon.match.string, sinon.match.string);
  });

  it('should handle `allowance(address,address)` call', async function () {
    const owner = '0x0000000000000000000000000000000000000001';
    const spender = '0x0000000000000000000000000000000000000002';

    mockWrappedProvider.request
      .withArgs({ method: 'eth_getCode', params: [HTS_ADDRESS, 'latest'] })
      .resolves({ result: '0xfe' });

    mockMirrornode.getAccount.withArgs(owner).resolves({ account: '0.0.1001' });
    mockMirrornode.getAccount.withArgs(spender).resolves({ account: '0.0.1002' });
    mockMirrornode.getAllowanceForToken.resolves({ allowances: [{ amount: 500 }] });

    await provider.request({
      method: 'eth_call',
      params: [{
        to: '0x0000000000000000000000000000000000000100',
        data: `0xdd62ed3e${owner.slice(2).padStart(64, '0')}${spender.slice(2).padStart(64, '0')}`,
      }],
    });

    sinon.assert.calledWith(
      mockMirrornode.getAllowanceForToken,
      sinon.match.string,
      sinon.match.string,
      sinon.match.string,
    );
  });

  it('should handle `allowance(address,address)` call even when `getAllowanceForToken` returns null', async function () {
    const owner = '0x0000000000000000000000000000000000000001';
    const spender = '0x0000000000000000000000000000000000000002';

    mockWrappedProvider.request
      .withArgs({ method: 'eth_getCode', params: [HTS_ADDRESS, 'latest'] })
      .resolves({ result: '0xfe' });

    mockMirrornode.getAccount.withArgs(owner).resolves({ account: '0.0.1001' });
    mockMirrornode.getAccount.withArgs(spender).resolves({ account: '0.0.1002' });
    mockMirrornode.getAllowanceForToken.resolves(null);

    await provider.request({
      method: 'eth_call',
      params: [{
        to: '0x0000000000000000000000000000000000000100',
        data: `0xdd62ed3e${owner.slice(2).padStart(64, '0')}${spender.slice(2).padStart(64, '0')}`,
      }],
    });

    sinon.assert.calledWith(
      mockMirrornode.getAllowanceForToken,
      sinon.match.string,
      sinon.match.string,
      sinon.match.string,
    );
  });
});
