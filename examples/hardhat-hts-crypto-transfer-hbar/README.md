# HTS crypto transfer hbars example

Simple scripts to show and investigate how the crypto transfer actually works for the hbar operations on the testnet.

Requires testnet account with non-empty balance. Each test run will result in decreasing the balance.

## Configuration

Create `.env` file based on `.env.example`

```
# Alias accounts keys
TESTNET_OPERATOR_PRIVATE_KEY=
```

## Setup & Install

In the project directory:

1. Run `npm install`
2. Run `npx hardhat test`
