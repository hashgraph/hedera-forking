## Foundry Forking Library

This library contains the code for the HtsSystemContract, which dynamically populates its storage with token data retrieved from the mirror node.

Forked networks are unable to retrieve the code of the smart contract deployed at address 0x167 on their own. You can use the bytecode from this implementation of HTS and run your tests just as you would on non-forked networks. In order to accomplish that simply run:

```solidity
deployCodeTo("HtsSystemContractInitialized.sol", address(0x167));
vm.allowCheatcodes(address(0x167));
```

before your tests.

- `deployCodeTo("HtsSystemContractInitialized.sol", address(0x167));` – Deploys our HTS contract code for forked networks to the expected address (0x167).
- `vm.allowCheatcodes(address(0x167));` – Grants this address permission to use VM tools. We use `surl` to fetch our token storage data from the MirrorNode, and `surl` requires `vm::ffi` to execute bash CLI commands for these requests. We also use the VM for type casting and JSON parsing.

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
