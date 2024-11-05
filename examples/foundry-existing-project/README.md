## Sample Usage

This repository is based on the example Smart Contract referenced in this [issue](https://github.com/hashgraph/hedera-smart-contracts/issues/863).

## Fixing Your Tests

To set up and fix your Foundry tests with Hedera forking, follow these steps:

1. **Install the Hedera Forking Library**:
   ```shell
   forge install git@github.com:hashgraph/hedera-forking.git
   ```

2. **Add Setup Code in Your Test Files**:
   Include the following lines in the setup phase of your tests to deploy the required contract code and enable cheat codes:

   ```solidity
   deployCodeTo("HtsSystemContractInitialized.sol", address(0x167));
   vm.allowCheatcodes(address(0x167));
   ```

## Running the Tests

This repository provides an example of using the Hedera forking library. To run the tests and observe the setup in action, use the following command:

```shell
FOUNDRY_PROFILE=forking forge test --fork-url "https://mainnet.hashio.io/api" --chain 295
```
