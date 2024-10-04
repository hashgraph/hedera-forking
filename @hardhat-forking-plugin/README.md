# Hashgraph Plugin for HardHat

This plugin replaces the default HardHat provider with one specifically designed for testing on the Hedera network.
It enables the following features

- **Hedera Precompile Support** Assigns the Hedera precompile code to the `0x167` address.
During tests, you'll be able to query Hedera token data as though they are stored on standard blockchains.
Currently, only fungible tokens are supported to a limited degree.
- **Token Proxy Address Storage** Sets up token proxy addresses by directly querying data from the Hedera MirrorNode, giving you access to real-time account balances, allowances, and token information (such as name, symbol, and decimals) in the IERC20 format for fungible tokens.
Please note that only fungible tokens are supported at this time.

## Installation

To use this plugin, install it via `npm`

```console
npm install @hashgraph/hardhat-forking-plugin
```

Next, add the following line to the top of your HardHat config file `hardhat.config.js`

```javascript
require('@hashgraph/hardhat-forking-plugin');
```

This will automatically replace the default HardHat provider with the one dedicated to the Hedera network.
You can then proceed with writing your tests, and the plugin will allow you to query Hedera token data seamlessly.

## Configuration

By default, the plugin uses the Hedera Mirror Node based on the guessed chain ID from the currently forked network.

The value of the configuration parameter: hardhat.forking.url will be used to infer the initial chain ID.

Only chain IDs 295 (Mainnet), 296 (Testnet), and 297 (Previewnet) are supported.

## Endpoints with Altered Behavior

The first RPC call using the Hardhat provider will set up the HTS bytecode via the JSON RPC method `hardhat_setCode`.

This operation will only work if the precompile address is not already occupied by an existing smart contract on your network. Forks of networks with no code deployed to the `0x167` address are required for this functionality.

Each time the `eth_call` method is invoked, the target address will be checked to see if it represents a token by querying the MirrorNode. Its basic storage fields (such as name, balance, decimals, etc.) will be set using the `hardhat_setStorageAt` method.

If the function selector in the `eth_call` request corresponds to any of the following functions, an additional operation will be performed, as described below:

| Function                     | Behavior                                                                                                                                                                                    |
|------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `balanceOf(address)`         | Sets the balance of the address (downloaded from MirrorNode) into the storage slot from where it will be queried.                                                                           |
| `allowance(address,address)` | Sets the token spending allowance for the address from the first parameter to the second parameter, after retrieving the data from the MirrorNode, and stores it in the corresponding slot. |

Additionally, by loading the HTS and token code into the EVM, the following methods can be called on the token's address, functioning similarly to how they would on the actual Hedera EVM:

| Function                                | Behavior                                                                                      |
|-----------------------------------------|-----------------------------------------------------------------------------------------------|
| `name()`                                | Returns the token's name.                                                                     |
| `symbol()`                              | Returns the token's symbol.                                                                   |
| `decimals()`                            | Returns the token's decimals.                                                                 |
| `totalSupply()`                         | Returns the token's total supply.                                                             |
| `balanceOf(address)`                    | Returns the balance of the specified address.                                                 |
| `allowance(address,address)`            | Returns the allowance for the specified address to spend tokens on behalf of another address. |
| `transfer(address,uint256)`             | Transfers a specified amount of tokens from the caller to the provided address.               |
| `transferFrom(address,address,uint256)` | Transfers a specified amount of tokens from one address to another.                           |
| `approve(address,uint256)`              | Approves an address to spend a specified number of tokens.                                    |

**Note:** Currently, only **fungible tokens** are supported.

## Publishing

In order to publish updated version of the plugin run

```bash
npm publish
```

and follow prompted instructions.
Privilege to add projects to the `@hashgraph` namespace are required.
