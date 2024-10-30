## Foundry Forking Library

This library contains the code for the HtsSystemContract, which dynamically populates its storage with token data retrieved from the mirror node.

Forked networks are unable to retrieve the code of the smart contract deployed at address 0x167 on their own.  You can use the bytecode from this implementation of HTS and run your tests just as you would on non-forked networks. In order to accomplish that simply run:

```solidity
address htsAddress = 0x0000000000000000000000000000000000000167;
deployCodeTo("HtsSystemContractInitialized.sol", htsAddress);
vm.allowCheatcodes(htsAddress);
```
before your tests. And that's it!

Please note that, for now, only fungible tokens are supported.

## Tests

This repository contains a sample usage of this library. To see how it's working run:
```shell
forge test  --fork-url "https://testnet.hashio.io/api" --chain 296
```
Testnet addresses are used for testing purposes and may stop working after a reset.

## Requirements

To use this library in your tests, you need to enable `ffi`. You can do this by adding the following lines to your `.toml` file:

```toml
[profile.default]
ffi = true
```

Alternatively, you can add the `--ffi` flag to your execution script. This is necessary because our library uses `surl`, which relies on `ffi` to make requests.
