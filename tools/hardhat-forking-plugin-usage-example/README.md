# Hashgraph Forking Plugin for HardHat - Usage Example

This example demonstrates how to use the Hedera plugin in the smart contract development process with HardHat.

## Configuration

To begin, you need to start the HardHat fork, which enables the use of the `hardhat_setStorageAt` and `hardhat_setCode` methods:

```bash
npx hardhat node --fork https://testnet.hashio.io/api
```

## Running Tests

To execute the tests, first install the necessary dependencies:

```bash
npm install
```

Then run the tests with the following command:

```bash
npx hardhat test
```
