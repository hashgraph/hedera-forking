## Foundry Forking Library

This library contains the code for the HtsSystemContract, which dynamically populates its storage with token data retrieved from the mirror node.

Forked networks are unable to retrieve the code of the smart contract deployed at address 0x167 on their own.  You can use the bytecode from this implementation of HTS and run your tests just as you would on non-forked networks. In order to accomplish that simply run:

```solidity
deployCodeTo("@hashgraph/hedera-forking/@foundry-forking-library/HtsSystemContract.sol", address(0x167));
```
before your tests. And that's it!

Please note that, for now, only fungible tokens are supported.
