require('@nomicfoundation/hardhat-toolbox');
require('@hashgraph/hardhat-forking-plugin');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: '0.8.27',
  networks: {
    hardhat: {
      forking: {
        url: 'https://testnet.hashio.io/api',
        // Here we can use `blockNumber` to enable JSON-RPC Relay's response cache
        // blockNumber: 10471740,
        chainId: 296,
        workerPort: 1235,
      },
    },
  },
};
