# Hedera Forking for System Contracts

**This projects allows Smart Contract developers working on Hedera to use fork testing while using Hedera System Contracts.**
It does so by providing an emulation layer for the [Hedera Token Service](https://hedera.com/token-service) _(more System Contracts to come)_ written in Solidity.
Given it is written in Solidity, it can be executed in a forked network environment, such as
[Foundry](https://book.getfoundry.sh/forge/fork-testing) or
[Hardhat](https://hardhat.org/hardhat-network/docs/overview#mainnet-forking).

You can use either our [Foundry library](#foundry-library) or [Hardhat plugin](#hardhat-plugin) to enable HTS emulation in your project.

See [Hedera Token Service Supported Methods](#hedera-token-service-supported-methods) for a list of methods currently implemented as part of this project.

> [!IMPORTANT]
> The HTS emulation contract **SHOULD BE ONLY** used to ease development workflow when working with Hedera Tokens.
> The HTS emulation contract **DOES NOT** replicate Hedera Token Services fully.
> That is, behavior might differ when switching from local development to a real Hedera network.
> **Always test your contracts against a real Hedera network before launching your contracts.**

> For detailed information on how this project works, see [Internals](./INTERNALS.md).

## Foundry library

We provide a Foundry library that enables fork testing when using HTS Tokens.

> To see how this library works in details, see [_Foundry library_](./INTERNALS.md#foundry-library) in Internals.

### Installation

First, install our library in your Foundry project

```console
forge install hashgraph/hedera-forking
```

### Set up

To use this library in your tests, you need to enable [`ffi`](https://book.getfoundry.sh/cheatcodes/ffi).
You can do so by adding the following lines to your `.toml` file

```toml
[profile.default]
ffi = true
```

Alternatively, you can add the `--ffi` flag to your execution script.

This is necessary because our library relies on [`curl`](https://curl.se/) to make HTTP requests to the Hedera remote network.
This enables the library to fetch token state in the remote network.
Given `curl` is an external command, `ffi` needs to be enabled.

> [!NOTE]
> The Foundry library assumes it is running on a Unix-like operating system.
> In addition to `curl`, it uses `bash`, `tail`, `sed` and `tr` and to make requests and parse responses.

To activate HTS emulation in your tests, you need to add the following setup code in your test files.
Import our wrapper function to deploy HTS emulation and enable cheat codes for it.

```solidity
import {htsSetup} from "hedera-forking/contracts/htsSetup.sol";
```

and then invoke it in your [test setup](https://book.getfoundry.sh/forge/writing-tests)

```solidity
    function setUp() public {
        htsSetup();
    }
```

### Running your Tests

Now you can use Hedera Token Services and remote tokens as if they were deployed locally when fork testing.
For example

```solidity examples/foundry-hts/USDC.t.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {htsSetup} from "hedera-forking/contracts/htsSetup.sol";
import {IERC20} from "hedera-forking/contracts/IERC20.sol";

contract USDCExampleTest is Test {
    // https://hashscan.io/mainnet/token/0.0.456858
    address USDC_mainnet = 0x000000000000000000000000000000000006f89a;

    address private user1;

    function setUp() external {
        htsSetup();

        user1 = makeAddr("user1");
        deal(USDC_mainnet, user1, 1000 * 10e8);
    }

    function test_get_balance_of_existing_account() view external {
        // https://hashscan.io/mainnet/account/0.0.1528
        address usdcHolder = 0x00000000000000000000000000000000000005f8;
        // Balance retrieved from mainnet at block 72433403
        assertEq(IERC20(USDC_mainnet).balanceOf(usdcHolder), 28_525_752677);
    }

    function test_dealt_balance_of_local_account() view external {
        assertEq(IERC20(USDC_mainnet).balanceOf(user1), 1000 * 10e8);
    }
}
```

To run your tests, use the usual command

```console
forge test --fork-url https://mainnet.hashio.io/api
```

You can also include a specific block number.
For example, the test above is known to work at block `72433403`

```console
forge test --fork-url https://mainnet.hashio.io/api --fork-block-number 72433403
```

You can use all the tools and cheatcodes Foundry provides, _e.g._, `console.log`

```solidity examples/foundry-hts/USDCConsole.t.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {htsSetup} from "hedera-forking/contracts/htsSetup.sol";
import {IERC20} from "hedera-forking/contracts/IERC20.sol";

contract USDCConsoleExampleTest is Test {
    function setUp() external {
        htsSetup();
    }

    function test_using_console_log() view external {
        // https://hashscan.io/mainnet/token/0.0.456858
        address USDC_mainnet = 0x000000000000000000000000000000000006f89a;

        string memory name = IERC20(USDC_mainnet).name();
        string memory symbol = IERC20(USDC_mainnet).symbol();
        uint8 decimals = IERC20(USDC_mainnet).decimals();
        assertEq(name, "USD Coin");
        assertEq(symbol, "USDC");
        assertEq(decimals, 6);

        console.log("name: %s, symbol: %s, decimals: %d", name, symbol, decimals);
    }
}
```

## Hardhat plugin

We provide a Hardhat plugin that enables fork testing when using HTS Tokens.

In addition, this plugin provides the following features

- **Sets up Hardfork history for Hedera networks.** This solves the issue
  [`No known hardfork for execution on historical block`](https://hardhat.org/hardhat-network/docs/guides/forking-other-networks#using-a-custom-hardfork-history).
- **Avoids `Missing access list` error.** Hardhat throws this error when a `blockNumber` is provided in the forking configuration. The plugin solves this issue.

This plugin intercepts the calls made by Hardhat to fetch remote state, \_i.e.,
`eth_getCode` and `eth_getStorageAt`, to provide emulation for HTS.
It assigns the Hedera Token Service code to the `0x167` address.
In your tests, you will be able to query Hedera Token data as if they were stored as regular Smart Contracts.

> To see how this plugin works in details, see [_Hardhat plugin_](./INTERNALS.md#hardhat-plugin) in Internals.

### Installation

To use this plugin, install it via your package manager.

If you are using **npm**

```console
npm install --save-dev @hashgraph/system-contracts-forking
```

or using **yarn**

```console
yarn add --dev @hashgraph/system-contracts-forking
```

### Set up

Next, add the following line to the top of your Hardhat config file, _e.g._, `hardhat.config.js`

```javascript
require('@hashgraph/system-contracts-forking/plugin');
```

or if you are using TypeScript, include the following line into your `hardhat.config.ts`

```javascript
import '@hashgraph/system-contracts-forking/plugin';
```

This will automatically create a worker thread to intercept calls to fetch remote state.
You can then proceed with writing your tests, and the plugin will allow you to query Hedera token data seamlessly.

### Configuration

By default, the plugin uses the Hedera Mirror Node based on the guessed chain ID from the currently forked network.

Two additional values needs to be set in order to activate the plugin.

- **`chainId`**. The call to `eth_chainId` of configuration parameter `hardhat.forking.url` needs to match the `chainId` configuration argument. Only chain IDs `295` (Mainnet), `296` (Testnet), and `297` (Previewnet) are supported.
- **`workerPort`**. Any free port to start the worker to intercept Hardhat calls to fetch remote state.

For example

```javascript
    networks: {
        hardhat: {
            forking: {
                url: 'https://mainnet.hashio.io/api',
                // This allows Hardhat to enable JSON-RPC's response cache.
                // Forking from a block is not fully integrated yet into HTS emulation.
                blockNumber: 70531900,
                chainId: 295,
                workerPort: 1235,
            },
        },
    },
```

> [!NOTE]
> These configuration settings cannot be set automatically by the Plugin.
> This is because the way Hardhat plugins are loaded by Hardhat.
> The main issue is _"since Hardhat needs to be loadable via `require` call, configuration must be synchronous"_.
> See [here](https://github.com/NomicFoundation/hardhat/issues/3287) and [here](https://github.com/NomicFoundation/hardhat/issues/2496) for more details.
>
> Creating a Worker so we can hook into `eth_getCode` and `eth_getStorageAt` to provide HTS emulation and querying the `chainId` of a remote network are **asynchronous** operations.
> That is why we need to shift the setting of `chainId` and `workerPort` to the user.

### Running Your Tests

For example, to query USDC information on mainnet you can use the following test

```javascript examples/hardhat-hts/test/usdc-info.test.js
const { expect } = require('chai');
const { ethers: { getContractAt } } = require('hardhat');

describe('USDC example -- informational', function () {
    it('should get name, symbol and decimals', async function () {
        // https://hashscan.io/mainnet/token/0.0.456858
        const usdc = await getContractAt('IERC20', '0x000000000000000000000000000000000006f89a');
        expect(await usdc['name']()).to.be.equal('USD Coin');
        expect(await usdc['symbol']()).to.be.equal('USDC');
        expect(await usdc['decimals']()).to.be.equal(6n);
    });
});
```

Then run your Hardhat tests as usual

```console
npx hardhat
```

You can also query an existing account's balance.
For example using the `blockNumber` as shown above in [_Configuration_](#configuration),
you can query the USDC balance for an existing account.

```javascript examples/hardhat-hts/test/usdc-balance.test.js
const { expect } = require('chai');
const { ethers: { getContractAt } } = require('hardhat');

describe('USDC example -- balanceOf', function () {
    it('should get `balanceOf` account holder', async function () {
        // https://hashscan.io/mainnet/token/0.0.456858
        const usdc = await getContractAt('IERC20', '0x000000000000000000000000000000000006f89a');

        // https://hashscan.io/mainnet/account/0.0.6279
        const holderAddress = '0x0000000000000000000000000000000000001887';
        expect(await usdc['balanceOf'](holderAddress)).to.be.equal(31_166_366226);
    });
});
```

You can also perform modifications in the forked network.
Let's see an example where we execute the `transfer` method from an existing account to a local Hardhat signer.
It is usually paired with [Fixtures](https://hardhat.org/hardhat-network-helpers/docs/reference#fixtures),
so that each test can start in a known state.
Moreover, you can use the tools you are already familiar with, for example,
[`hardhat_impersonateAccount`](https://hardhat.org/hardhat-network/docs/reference#hardhat_impersonateaccount).

```javascript examples/hardhat-hts/test/usdc-transfer.test.js
const { expect } = require('chai');
const { ethers: { getSigner, getSigners, getContractAt }, network: { provider } } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

describe('USDC example -- transfer', function () {
    async function id() {
        return [(await getSigners())[0]];
    }

    it("should `tranfer` tokens from account holder to one of Hardhat' signers", async function () {
        const [receiver] = await loadFixture(id);

        // https://hashscan.io/mainnet/account/0.0.6279
        const holderAddress = '0x0000000000000000000000000000000000001887';
        await provider.request({
            method: 'hardhat_impersonateAccount',
            params: [holderAddress],
        });
        const holder = await getSigner(holderAddress);

        // https://hashscan.io/mainnet/token/0.0.456858
        const usdc = await getContractAt('IERC20', '0x000000000000000000000000000000000006f89a');

        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(0n);

        await usdc.connect(holder)['transfer'](receiver, 10_000_000n);

        expect(await usdc['balanceOf'](receiver.address)).to.be.equal(10_000_000n);
    });
});
```

## Hedera Token Service Supported Methods

Given your HTS token address, you can invoke these functions whether the token is either fungible or non-fungible.

### Fungible Tokens

The following methods and events are applicable to Fungible Tokens.

#### ERC20 Interface

<!-- !./scripts/abi-table.js out/IERC20.sol/IERC20.json out/IERC20.sol/IERC20Events.json -->

| Function                                                          | Comment                                                                                                                                                                                                              |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `allowance(address owner, address spender) view`                  | Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through {transferFrom}. This is zero by default. This value changes when {approve} or {transferFrom} are called. |
| `approve(address spender, uint256 amount)`                        | Sets a `value` amount of tokens as the allowance of `spender` over the caller's tokens. Returns a boolean value indicating whether the operation succeeded.                                                          |
| `balanceOf(address account) view`                                 | Returns the value of tokens owned by `account`.                                                                                                                                                                      |
| `decimals() view`                                                 | Returns the decimals places of the token.                                                                                                                                                                            |
| `name() view`                                                     | Returns the name of the token.                                                                                                                                                                                       |
| `symbol() view`                                                   | Returns the symbol of the token.                                                                                                                                                                                     |
| `totalSupply() view`                                              | Returns the value of tokens in existence.                                                                                                                                                                            |
| `transfer(address recipient, uint256 amount)`                     | Moves a `value` amount of tokens from the caller's account to `to`. Returns a boolean value indicating whether the operation succeeded.                                                                              |
| `transferFrom(address sender, address recipient, uint256 amount)` | Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism. `value` is then deducted from the caller's allowance. Returns a boolean value indicating whether the operation succeeded.        |

| Event                                                                      | Comment                                                                                                               |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `Approval(address indexed owner, address indexed spender, uint256 amount)` | Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance. |
| `Transfer(address indexed from, address indexed to, uint256 amount)`       | Emitted when `value` tokens are moved from one account (`from`) to another (`to`). Note that `value` may be zero.     |

<!-- -->

#### Association Methods Interface

<!-- !./scripts/abi-table.js out/IHRC719.sol/IHRC719.json -->

| Function              | Comment                                                                                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `associate()`         | Associates the calling account with the token This function allows an account to opt-in to receive the token                   |
| `dissociate()`        | Dissociates the calling account from the token This function allows an account to opt-out from receiving the token             |
| `isAssociated() view` | Checks if the calling account is associated with the token This function returns the association status of the calling account |

<!-- -->

### Non-Fungible Tokens

The following methods and events are applicable to Non-Fungible Tokens.

> [!NOTE]
> ERC721 support coming soon!

#### Association Methods Interface

<!-- !./scripts/abi-table.js out/IHRC719.sol/IHRC719.json -->

| Function              | Comment                                                                                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `associate()`         | Associates the calling account with the token This function allows an account to opt-in to receive the token                   |
| `dissociate()`        | Dissociates the calling account from the token This function allows an account to opt-out from receiving the token             |
| `isAssociated() view` | Checks if the calling account is associated with the token This function returns the association status of the calling account |

<!-- -->

### Hedera Token Service (located at address `0x167`)

The following methods can be invoked on the Hedera Token Service contract located at address `0x167`.

<!-- !./scripts/abi-table.js out/IHederaTokenService.sol/IHederaTokenService.json -->

| Function                                                        | Comment                                                        |
| --------------------------------------------------------------- | -------------------------------------------------------------- |
| `burnToken(address token, int64 amount, int64[] serialNumbers)` | Burns an amount of the token from the defined treasury account |
| `getTokenInfo(address token)`                                   | Query token info                                               |
| `mintToken(address token, int64 amount, bytes[] metadata)`      | Mints an amount of the token to the defined treasury account   |

<!-- -->

## JS Library

Service and application builders can use the core state emulation library.
These functions can be embedded in a JSON-RPC implementation to enable System Contracts fork testing without using the Hardhat plugin.

```javascript
const { getHtsCode, getHtsStorageAt, getHIP719Code } = require('@hashgraph/system-contracts-forking');
```

- **`getHtsCode`**. Gets the runtime bytecode for the Solidity implementation of the HTS System Contract.
- **`getHtsStorageAt`**. Allows the user to query the state of an HTS Token as if it were a standard smart contract.
- **`getHIP719Code`**. Returns the token proxy contract bytecode for the given `address`. Based on the proxy contract defined by [HIP-719](https://hips.hedera.com/hip/hip-719).

See [`index.d.ts`](./src/index.d.ts) for more details.

At its core, the [_Hardhat plugin_](#hardhat-plugin) is supported by these functions.

## Build

This repo consists of a Foundry project and an `npm` package.
A Foundry project, to compile and test the [`HtsSystemContract.sol`](./contracts/HtsSystemContract.sol) contract.
And an `npm` package that implements both `eth_getCode` and `eth_getStorageAt` JSON-RPC methods when HTS emulation is involved together with the Hardhat plugin that uses these methods.

To compile the `HtsSystemContract`, its dependencies and the test contracts run

```console
forge build
```

There is no compilation step to build the `npm` package.
However, you can type-check it by running

```console
npm run type-check
```

The code examples and the tables for supported methods included in this `README` are automatically generated.
Run the following command to generate them

```console
npm run make:readme
```

This allow us to ensure that all examples and tables are never outdated (if we change them we just need to rerun the above command) and that the examples are executed properly (we run them on CI).

Code fences that contains a file name after the language definition, _e.g._,

````markdown
  ```solidity examples/foundry-hts/USDC.t.sol
  ```
````

or comments such as

```markdown
  <!-- !./scripts/abi-table.js out/IERC20.sol/IERC20.json out/IERC20.sol/IERC20Events.json -->
  <!-- -->
```

will be expanded with either the content of the file or, when the file descriptor starts with a `!`, with the standard output of the application.

## Tests

> [!TIP]
> The `scripts/create-token.js` file was used to deploy Tokens using HTS to `testnet` for testing purposes.

### `getHtsCode`, `getHtsStorageAt` and `getHIP719Code` Unit Tests

These tests only involve testing `getHtsCode`, `getHtsStorageAt` and `getHIP719Code` functions.
In other words, they do not use the `HtsSystemContract` bytecode, only its `storageLayout` definition. To run them, execute

```console
npm run test
```

> [!TIP]
> You may want to run the `npm` tests without the Hardhat plugin tests.
> To do so, you can use the [`--fgrep`](https://mochajs.org/#-fgrep-string-f-string) or [`--grep`](https://mochajs.org/#-grep-regexp-g-regexp) flags together with [`--invert`](https://mochajs.org/#-invert), for example
>
> ```console
> npm run test -- --grep ::plugin --invert
> ```

All top-level `mocha`'s `describe`s should be prefixed with `::` so it can be easy to filter by tests.

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

This is used to test [`HtsSystemContract`(`Json`)](./contracts/HtsSystemContractJson.sol)+[`MirrorNodeFFI`](./contracts/MirrorNodeFFI.sol) contracts.
It is the implementation used by Foundry users.

We provide a [`curl`](./test/scripts/curl) mock in the `test/scripts` folder to avoid depending on a remote Mirror Node and thus making the tests more robust.
By modifiying the `PATH` environment variable, the mocked `curl` is used instead.

```console
PATH=./test/scripts:$PATH forge test --fork-url https://testnet.hashio.io/api --fork-block-number 13890397
```

In case needed, there is a trace log of requests made by mocked `curl` in `scripts/curl.log`

```console
cat test/scripts/curl.log
```

### `HtsSystemContract` Solidity tests + JSON-RPC mock server for storage emulation (_with_ forking)

These Solidity tests are used to test both the `HtsSystemContract` and the `npm` package.
It is the implementation used by Hardhat users.

Instead of starting a `local-node` or using a remote network,
they use the [`json-rpc-mock.js`](./test/scripts/json-rpc-mock.js) script as a backend without the need for any additional services,
thus making the tests more robust.
This is the network Foundry's Anvil is forking from.

In a separate terminal run the JSON-RPC Mock Server

```console
./test/scripts/json-rpc-mock.js
```

Then run

```console
forge test --fork-url http://localhost:7546 --no-storage-caching
```

> [!IMPORTANT]
> The `--no-storage-caching` flag disables the JSON-RPC calls cache,
> which is important to make sure the `json-rpc-mock.js` is reached in each JSON-RPC call.
> See <https://book.getfoundry.sh/reference/forge/forge-test#description> for more information.

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
