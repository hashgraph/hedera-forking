# Hedera Forking Support for System Contracts

For Hardhat instructions, go to [Hardhat](#hardhat).

## Foundry

We provide a Foundry library that enables fork testing when using HTS Tokens.

### Installation

First install our library in your Foundry project

```console
forge install hashgraph/hedera-forking
```

### Set up

To use this library in your tests, you need to enable [`ffi`](https://book.getfoundry.sh/cheatcodes/ffi) in your Foundry project.
You can do so by adding the following lines to your `.toml` file

```toml
[profile.default]
ffi = true
```

Alternatively, you can add the `--ffi` flag to your execution script.

This is necessary because our library uses [`surl`](https://github.com/memester-xyz/surl),
which relies on `ffi` to make HTTP requests.

### Usage

This repository includes the example Smart Contract referenced in this [issue](https://github.com/hashgraph/hedera-smart-contracts/issues/863).

To set up and fix your Foundry tests with Hedera forking, follow these steps

Add Setup Code in Your Test Files

Import our function wrapper

Include the following lines in the setup phase of your tests to deploy the required contract code and enable cheat codes

```solidity
import {htsSetup} from "hedera-forking/src/htsSetup.sol";
```

and include it in your [test setup](https://book.getfoundry.sh/forge/writing-tests)

```solidity
    function setUp() public {
        htsSetup();
    }
```

### Running your Tests

To run the tests and observe the setup in action, use the following command

```console
forge test --fork-url https://mainnet.hashio.io/api
```

## Hardhat

This plugin replaces the default HardHat provider with one specifically designed for testing on the Hedera network.
It enables the following features

- **Hedera Precompile Support** Assigns the Hedera precompile code to the `0x167` address.
  During tests, you'll be able to query Hedera token data as though they are stored on standard blockchains.
  Currently, only fungible tokens are supported to a limited degree.
- **Token Proxy Address Storage** Sets up token proxy addresses by directly querying data from the Hedera MirrorNode, giving you access to real-time account balances, allowances, and token information (such as name, symbol, and decimals) in the IERC20 format for fungible tokens.
  Please note that only fungible tokens are supported at this time.

### Installation

To use this plugin, install it via `npm`

```console
npm install --save-dev @hashgraph/hardhat-forking-plugin
```

```console
yarn add --dev @hashgraph/hardhat-forking-plugin
```

Next, add the following line to the top of your HardHat config file `hardhat.config.js`

```javascript
require('@hashgraph/hardhat-forking-plugin');
```

This will automatically replace the default HardHat provider with the one dedicated to the Hedera network.
You can then proceed with writing your tests, and the plugin will allow you to query Hedera token data seamlessly.

### Configuration

By default, the plugin uses the Hedera Mirror Node based on the guessed chain ID from the currently forked network.

The value of the configuration parameter: hardhat.forking.url will be used to infer the initial chain ID.

Only chain IDs 295 (Mainnet), 296 (Testnet), and 297 (Previewnet) are supported.

### Endpoints with Altered Behavior

The first RPC call using the Hardhat provider will set up the HTS bytecode via the JSON RPC method `hardhat_setCode`.

This operation will only work if the precompile address is not already occupied by an existing smart contract on your network. Forks of networks with no code deployed to the `0x167` address are required for this functionality.

Each time the `eth_call` method is invoked, the target address will be checked to see if it represents a token by querying the MirrorNode. Its basic storage fields (such as name, balance, decimals, etc.) will be set using the `hardhat_setStorageAt` method.

If the function selector in the `eth_call` request corresponds to any of the following functions, an additional operation will be performed, as described below:

| Function                     | Behavior                                                                                                                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `balanceOf(address)`         | Sets the balance of the address (downloaded from MirrorNode) into the storage slot from where it will be queried.                                                                           |
| `allowance(address,address)` | Sets the token spending allowance for the address from the first parameter to the second parameter, after retrieving the data from the MirrorNode, and stores it in the corresponding slot. |

Additionally, by loading the HTS and token code into the EVM, the following methods can be called on the token's address, functioning similarly to how they would on the actual Hedera EVM:

| Function                                | Behavior                                                                                      |
| --------------------------------------- | --------------------------------------------------------------------------------------------- |
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

## Background

**Fork Testing** (or **WaffleJS Fixtures**) is an Ethereum Development Environment feature that optimizes test execution for Smart Contracts.
It enables snapshotting of blockchain state, saving developement time by avoiding the recreation of the entire blockchain state for each test.
Instead, tests can revert to a pre-defined snapshot, streamlining the testing process.
Most populars Ethereum Development Environments provide this feature, such as
[Foundry](https://book.getfoundry.sh/forge/fork-testing) and
[Hardhat](https://hardhat.org/hardhat-network/docs/overview#mainnet-forking).

This feature is enabled by their underlaying Development network, for example

- Hardhat's [EJS (EthereumJS VM)](https://github.com/nomicfoundation/ethereumjs-vm) and [EDR (Ethereum Development Runtime)](https://github.com/NomicFoundation/edr)
- Foundry's [Anvil](https://github.com/foundry-rs/foundry/tree/master/crates/anvil)
- [Ganache _(deprecated)_](https://github.com/trufflesuite/ganache)

Please note that WaffleJS, when used directly as a library, _i.e._, not inside a Hardhat project,
[uses Ganache internally](https://github.com/TrueFiEng/Waffle/blob/238c11ccf9bcaf4b83c73eca16d25243c53f2210/waffle-provider/package.json#L47).

On the other hand, Geth support some sort of snapshotting with <https://geth.ethereum.org/docs/interacting-with-geth/rpc/ns-debug#debugsethead>,
but it’s not commonly used for development and testing of Smart Contracts.

Moreover, given that Fork testing runs on a local development network, users can use `console.log` in tests to ease the debugging process.
With `console.log`, you can print logging messages and contract variables calling `console.log` from your Solidity code.
Both [Foundry](https://book.getfoundry.sh/reference/forge-std/console-log) and [Hardhat](https://hardhat.org/tutorial/debugging-with-hardhat-network) support `console.log`.
Not being able to use Forking (see below) implies also not being able to use `console.log` in tests,
which cause frustration among Hedera users.

### Can Hedera developers use Fork Testing?

**Yes**, Fork Testing works well when the Smart Contracts are standard EVM Smart Contracts that do not involve Hedera-specific services.
This is because fork testing is targeted at the local test network provided by the Ethereum Development Environment.
These networks are somewhat replicas of the Ethereum network and do not support Hedera-specific services.

**No**, Fork Testing will not work on Hedera for contracts that are specific to Hedera.
For example, if a contract includes calls to the `createFungibleToken` method on the HTS System Contract at `address(0x167)`.
This is because the internal local test network provided by the framework (`chainId: 1337`) does not have the precompiled HTS contract deployed at `address(0x167)`.

This project is an attempt to solve this problem.
It does so by providing an emulation layer for HTS written in Solidity.
Given it is written in Solidity, it can executed in a development network environment, such as Foundry or Hardhat.

## Overview

This project has two main parts

- **[`HtsSystemContract.sol`](./src/HtsSystemContract.sol) Solidity Contract**.
  This contract provides an emulator for the Hedera Token Service written in Solidity.
  It is specially designed to work in a forked network.
  Its storage reads and writes are crafted to be reversible in a way the `hedera-forking` package can fetch the appropriate data.
- **[`@hashgraph/hedera-forking`](./index.js) CommonJS Package**.
  Provides functions that can be hooked into the Relay to fetch the appropiate data when HTS System Contract (at address `0x167`) or Hedera Tokens are invoked.
  This package uses the compilation output of the `HtsSystemContract` contract to return its bytecode and to map storage slots to field names.

### How does it Work?

The following sequence diagram showcases the messages sent between components when fork testing is activated within an Ethereum Development Environment, _e.g._, Foundry or Hardhat.

> [!NOTE]
> The JSON-RPC Relay service is not shown here because is not involved when performing a requests for a Token.

```mermaid
sequenceDiagram
    autonumber
    box Local
    actor user as User
    participant client as Local Network<br/>Foundry's Anvil, Hardhat's EDR
    participant hedera-forking as Hardhat Forking Plugin
    end
    box Remote
    #participant relay as JSON-RPC Relay
    participant mirror as Mirror Node
    end

    user->>+client: address(Token).totalSupply()
    client->>+hedera-forking: eth_getCode(Token)
    hedera-forking->>+mirror: API tokens/<tokenId>
    mirror-->>-hedera-forking: Token {}
    hedera-forking-->>-client: HIP-719 Token Proxy bytecode<br/>(delegate calls to 0x167)

    client->> + hedera-forking: eth_getCode(0x167)
    hedera-forking-->>-client: HtsSystemContract bytecode

    client->>+hedera-forking: eth_getStorageAt(Token, slot<totalSupply>)
    #relay ->> + hedera-forking: getHtsStorageAt(Token, slot)
    hedera-forking -) + mirror: API tokens/<tokenId>
    mirror --) - hedera-forking: Token{}
    #hedera-forking -->> - relay: Token{}.totalSupply
    hedera-forking-->>-client: Token{}.totalSupply

    client->>-user: Token{}.totalSupply
```

The relevant interactions are

- **(5).** This is the code defined by [HIP-719](https://hips.hedera.com/hip/hip-719#specification).
  For reference, you can see the
  [`hedera-services`](https://github.com/hashgraph/hedera-services/blob/fbac99e75c27bf9c70ebc78c5de94a9109ab1851/hedera-node/hedera-smart-contract-service-impl/src/main/java/com/hedera/node/app/service/contract/impl/state/DispatchingEvmFrameState.java#L96)
  implementation.
- **(6)**-**(7)**. This calls `getHtsCode` which in turn returns the bytecode compiled from `HtsSystemContract.sol`.
- **(8)**-**(12)**. This calls `getHtsStorageAt` which uses the `HtsSystemContract`'s [Storage Layout](./INTERNALS.md#storage-layout) to fetch the appropriate state from the Mirror Node. The **(8)** JSON-RPC call is triggered as part of the `redirectForToken(address,bytes)` method call defined in HIP-719.
  Even if the call from HIP-719 is custom encoded, this method call should support standard ABI encoding as well as defined in
  [`hedera-services`](https://github.com/hashgraph/hedera-services/blob/b40f81234acceeac302ea2de14135f4c4185c37d/hedera-node/hedera-smart-contract-service-impl/src/main/java/com/hedera/node/app/service/contract/impl/exec/systemcontracts/common/AbstractCallAttempt.java#L91-L104).

## Build

This repo consists of two projects/packages.
A Foundry project, to compile and test the `HtsSystemContract.sol` contract.
And an `npm` package that implements both `eth_getCode` and `eth_getStorageAt` JSON-RPC methods when HTS emulation is involved together with the Hardhat plugin that uses these methods.

To compile the `HtsSystemContract` and test contracts run

```console
forge build
```

There is no compilation step to build the `@hashgraph/hedera-forking` package.
However, you can type-check it by running

```console
npm run type-check
```

## Tests

> [!TIP]
> The [`create-token.js`](./scripts/create-token.js) script was used to deploy Tokens using HTS to `testnet` for testing purposes.

### `getHtsCode`, `getHtsStorageAt` and `getHIP719Code` Unit Tests

These tests only involve testing `getHtsCode`, `getHtsStorageAt` and `getHIP719Code` functions.
In other words, they do not use the `HtsSystemContract` bytecode, only its `storageLayout` definition. To run them, execute

```console
npm run test
```

### `HtsSystemContract` Solidity tests + local storage emulation (_without_ forking)

We use Foundry cheatcodes, _i.e._,
[`vm.store`](https://book.getfoundry.sh/cheatcodes/store) and
[`vm.load`](https://book.getfoundry.sh/cheatcodes/load),
to provide local storage emulation that allow us to run `HtsSystemContract` Solidity tests without starting out a separate JSON-RPC process.

```console
forge test
```

> [!TIP]
> You can use the `--match-contract` flag to filter the tests to be executed if needed.
> In addition, usually when debugging the contract under test we are interested in getting the Solidity traces.
> We can use the `forge` flag `-vvvv` to display them.
> For example
>
> ```console
> forge test --match-contract TokenTest -vvvv
> ```

When running these tests **without** forking from a remote network,
the package `@hashgraph/hedera-forking` is not under test.

### `HtsSystemContract` Solidity tests + Mirror Node FFI (with mocked `curl`)

```console
PATH=./scripts:$PATH forge test --fork-url https://testnet.hashio.io/api --fork-block-number 8535327
```

In case needed, there is a trace log of requests made by mocked `curl` in `scripts/curl.log`

```console
cat scripts/curl.log
```

### `HtsSystemContract` Solidity tests + JSON-RPC mock server for storage emulation (_with_ forking)

These Solidity tests are used to test both the `HtsSystemContract` and the `@hashgraph/hedera-forking` package.
Instead of starting a `local-node` or using a remote network,
they use the [`json-rpc-mock.js`](./scripts/json-rpc-mock.js) script as a backend without the need for any additional service.
This is the network Foundry's Anvil is forking from.

In a separate terminal run the JSON-RPC Mock Server

```console
./scripts/json-rpc-mock.js
```

Then run

```console
forge test --fork-url http://localhost:7546 --no-storage-caching
```

> [!IMPORTANT]
> The `--no-storage-caching` flag disables the JSON-RPC calls cache,
> which is important to make sure the `json-rpc-mock.js` is reached in each JSON-RPC call.
> See <https://book.getfoundry.sh/reference/forge/forge-test#description> for more information.

### `HtsSystemContract` Solidity tests + Relay for storage emulation (with forking)

These tests are the same of the section above, but instead of using the `json-rpc-mock.js` it uses the Relay with `hedera-forking` enabled pointing to `testnet`.

## Internals

For detailed information on how this project works, see [Internals](./INTERNALS.md).

## Support

If you have a question on how to use the product, please see our
[support guide](https://github.com/hashgraph/.github/blob/main/SUPPORT.md).

## Contributing

Contributions are welcome. Please see the
[contributing guide](https://github.com/hashgraph/.github/blob/main/CONTRIBUTING.md)
to see how you can get involved.

## Code of Conduct

This project is governed by the
[Contributor Covenant Code of Conduct](https://github.com/hashgraph/.github/blob/main/CODE_OF_CONDUCT.md). By
participating, you are expected to uphold this code of conduct. Please report unacceptable behavior
to [oss@hedera.com](mailto:oss@hedera.com).

## License

[Apache License 2.0](LICENSE)

## Security

Please do not file a public ticket mentioning the vulnerability.
Refer to the security policy defined in the [SECURITY.md](SECURITY.md).
