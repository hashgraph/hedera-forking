# Hedera Fork Testing Support

## Usage

### Build

To compile the contracts

```console
forge build
```

### Test

Given we are interested in analyze Solidity traces, we can use the `forge` flag `-vvvv` to display them.
It is useful to filter to a specific test file, for example

```console
forge test --match-contract USDCTest -vvvv
```

## Use Cases

create token using launch-token

# Token bytecode

https://hips.hedera.com/hip/hip-719#specification

https://github.com/hashgraph/hedera-services/blob/fbac99e75c27bf9c70ebc78c5de94a9109ab1851/hedera-node/hedera-smart-contract-service-impl/src/main/java/com/hedera/node/app/service/contract/impl/state/DispatchingEvmFrameState.java#L96

another alternative could be something like
https://book.getfoundry.sh/cheatcodes/etch
https://book.getfoundry.sh/reference/forge-std/deployCodeTo

The `launch-token` is used to deploy new Tokens using HTS to `testnet`.
