# Waffle example

Simple scripts for testing waffle fixtures on the methods that requires HTS Emulation to work correctly.

## Configuration

Create `.env` file based on `.env.example`

```
OPERATOR_PRIVATE_KEY=
RELAY_ENDPOINT=
ERC20_TOKEN_ADDRESS=
```

 - `OPERATOR_PRIVATE_KEY` is your account ECDSA hex-encoded private key.
 - `RELAY_ENDPOINT` is a path to your JSON RPC Api. Hardhat's fork address should be given in order to make these tests work correctly.
 - `ERC20_TOKEN_ADDRESS` is the address of the token used for testing. We are verifying the correct behavior of the forked network, which requires some preset data. The OPERATOR_PRIVATE_KEY account must have a non-zero balance of this token on this network and be authorized to perform transfer operations.

All tests will be executed on a forked Ganache network, ensuring that the state of your original network remains unchanged.

## Setup & Install
1. First you have to start a local node with ENABLE_FORKING_SUPPORT = "true".
2. Create a fork of this network, for example using hardhat:
```bash
npx hardhat node --fork http://127.0.0.1:7546
```

3. In the project directory:
 - Run `npm install`
 - Run `npm run build`
 - Run `npm run test`

#### Dependencies

Waffle uses **ethers.js** to perform operations such as deploying Smart Contracts and sending transactions. It leverages **Mocha** and **Chai** as the foundational testing tools, while adding its own custom matchers tailored for Smart Contracts.

## Installation:
To install Waffle, you need to add the `ethereum-waffle` node module to your project. You can do this using the following command:

```shell
npm install --save-dev ethereum-waffle
```

