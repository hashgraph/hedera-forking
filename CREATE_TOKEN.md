# How Create and Delete HTS Tokens Work

Hedera Token Services provide several methods to create both Fungible and Non-Fungible Tokens.
Each method providing different capabilities for token creation.
The following is the list of methods to create tokens.

```solidity
/// Creates a Fungible Token with the specified properties
/// @param token the basic properties of the token being created
/// @param initialTotalSupply Specifies the initial supply of tokens to be put in circulation. The
/// initial supply is sent to the Treasury Account. The supply is in the lowest denomination possible.
/// @param decimals the number of decimal places a token is divisible by
/// @return responseCode The response code for the status of the request. SUCCESS is 22.
/// @return tokenAddress the created token's address
function createFungibleToken(
    HederaToken memory token,
    int64 initialTotalSupply,
    int32 decimals
) external payable returns (int64 responseCode, address tokenAddress);

/// Creates a Fungible Token with the specified properties
/// @param token the basic properties of the token being created
/// @param initialTotalSupply Specifies the initial supply of tokens to be put in circulation. The
/// initial supply is sent to the Treasury Account. The supply is in the lowest denomination possible.
/// @param decimals the number of decimal places a token is divisible by.
/// @param fixedFees list of fixed fees to apply to the token
/// @param fractionalFees list of fractional fees to apply to the token
/// @return responseCode The response code for the status of the request. SUCCESS is 22.
/// @return tokenAddress the created token's address
function createFungibleTokenWithCustomFees(
    HederaToken memory token,
    int64 initialTotalSupply,
    int32 decimals,
    FixedFee[] memory fixedFees,
    FractionalFee[] memory fractionalFees
) external payable returns (int64 responseCode, address tokenAddress);

/// Creates an Non Fungible Unique Token with the specified properties
/// @param token the basic properties of the token being created
/// @return responseCode The response code for the status of the request. SUCCESS is 22.
/// @return tokenAddress the created token's address
function createNonFungibleToken(HederaToken memory token)
    external
    payable
    returns (int64 responseCode, address tokenAddress);

/// Creates an Non Fungible Unique Token with the specified properties
/// @param token the basic properties of the token being created
/// @param fixedFees list of fixed fees to apply to the token
/// @param royaltyFees list of royalty fees to apply to the token
/// @return responseCode The response code for the status of the request. SUCCESS is 22.
/// @return tokenAddress the created token's address
function createNonFungibleTokenWithCustomFees(
    HederaToken memory token,
    FixedFee[] memory fixedFees,
    RoyaltyFee[] memory royaltyFees
) external payable returns (int64 responseCode, address tokenAddress);
```

On the other hand, the method to delete an HTS token, either Fungible or Non-Fungible is the following

```solidity
/// Operation to delete token
/// @param token The token address to be deleted
/// @return responseCode The response code for the status of the request. SUCCESS is 22.
function deleteToken(address token) external returns (int64 responseCode);
```

The main goal of this document is to describe how to enable token creation and deletion on HTS emulation.

## What about Forking from a Remove Network?

The introducion of token creation opens the door for a new capability.
Using the HTS emulation **without** forking.

## High-level Specification

The following auxiliary definitions are needed.
See <https://github.com/hashgraph/hedera-smart-contracts/issues/1026> for more details.

```solidity
interface IHtsFungibleToken is IERC20, IHRC719 {}
interface IHtsNonFungibleToken is IERC721, IHRC719 {}
```

All token creation methods receive a `token`, which refers to the `HederaToken` used to configure the initial values of the token being created.
They return a `tokenAddress`, which will be the address of the newly created token.

A successful call to any token creation method should have the following effect

- The associated bytecode of `tokenAddress` should be that of the Proxy Contract as defined by [HIP719 &sect; _Specification_](https://hips.hedera.com/hip/hip-719). Note that the `tokenAddress` should be embedded into the bytecode as noted by the HIP.
- The balance of the `token.treasury` should be `totalSupply`.
- The `token.treasury` address should be associated to the token.
- The token should not have any other balances nor associations.
- A non-fungible token should not have any minted NFT.
- An immediate call to `IHederaTokenService(0x167).getTokenInfo(tokenAddress)` should return `token`.
- All methods in either `IHtsFungibleToken(tokenAddress)` or `IHtsNonFungibleToken(tokenAddress)` should be available to invoke.

## Foundry library

When

## Hardhat plugin

How to encode a create token message into a storage slot request?
