/*-
 *
 * Hedera Hardhat Plugin Example Project
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

const hre = require('hardhat');
const { expect } = require('chai');

describe('RPC', function () {
  const accountAddress = '0x292c4acf9ec49af888d4051eb4a4dc53694d1380';
  const spenderAddress = '0x000000000000000000000000000000000043f832';
  let ft;
  beforeEach(async () => {
      ft = await hre.viem.getContractAt('IERC20', '0x000000000000000000000000000000000047b52a');
  });

 it('add sample transaction to the forked network', async function () {
    expect(await hre.network.provider.send('hardhat_mine', ['0x001'])).to.be.true;
  });

 it('show decimals', async function () {
      expect(await ft.read.decimals()).to.be.equal(13);
  });

    it('get name', async function () {
      expect(await ft.read.name()).to.be.equal(
          'Very long string, just to make sure that it exceeds 31 bytes and requires more than 1 storage slot.',
      );
    });

 it('get symbol', async function () {
    expect(await ft.read.symbol()).to.be.equal('SHRT');
  });

 it('get balance', async function () {
    expect(await ft.read.balanceOf([accountAddress])).to.be.equal(9995);
  });

  it('get allowance', async function () {
    expect(await ft.read.allowance([accountAddress, spenderAddress])).to.be.equal(0);
  });
});
