# Hashgraph Plugin for HardHat

This plugin replaces the default HardHat provider with one specifically designed for testing on the Hedera network. It enables the following features:
- **Hedera Precompile Support**: Assigns the Hedera precompile code to the `0x167` address. During tests, you'll be able to query Hedera token data as though they are stored on standard blockchains. Currently, only fungible tokens are supported to a limited degree.
- **Token Proxy Address Storage**: Sets up token proxy addresses by directly querying data from the Hedera Mirrornode, giving you access to real-time account balances, allowances, and token information (such as name, symbol, and decimals) in the IERC20 format for fungible tokens. Please note that only fungible tokens are supported at this time.

## Installation

To use this plugin, install it via npm:

```bash
npm install @hashgraph/hardhat-forking-plugin
```

Next, add the following line to the top of your HardHat config file (`hardhat.config.js`):

```javascript
require("@hashgraph/hardhat-forking-plugin");
```

This will automatically replace the default HardHat provider with the one dedicated to the Hedera network. You can then proceed with writing your tests, and the plugin will allow you to query Hedera token data seamlessly.

## Configuration

By default, the plugin uses the Hedera testnet Mirrornode. To use a different endpoint, such as for mainnet, update your HardHat configuration as follows:

```javascript
module.exports = {
  hedera: {
    mirrornode: "https://mainnet-public.mirrornode.hedera.com/api/v1/",
  }
};
```

This configuration enables you to test your code against actual token data stored on the Hedera mainnet.

## Publishing

In order to publish updated version of the plugin run:

```bash
npm publish
```

and follow prompted instructions. Privilege to add projects to the @hashgraph namespace are required.
