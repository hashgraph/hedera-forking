require('@nomicfoundation/hardhat-toolbox');
require('@hashgraph/hardhat-forking-plugin');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: '0.8.27',
  networks: {
    hardhat: {
      forking: {
        url: 'https://testnet.hashio.io/api',
        // This allows Hardhat to enable JSON-RPC's response cache.
        // Forking from a block is not fully integrated yet into HTS emulation.
        blockNumber: 10471740,
        chainId: 296,
        workerPort: 1235,
      },
    },
  },
};
