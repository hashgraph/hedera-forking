// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library HederaResponseCodes {
    int32 internal constant NOT_SUPPORTED = 13;
    int32 internal constant SUCCESS = 22; // The transaction succeeded
    int32 internal constant INSUFFICIENT_ACCOUNT_BALANCE = 28;
    int32 internal constant INVALID_ACCOUNT_AMOUNTS = 48;
    int32 internal constant ACCOUNT_REPEATED_IN_ACCOUNT_AMOUNTS = 74;
    int32 internal constant INSUFFICIENT_TOKEN_BALANCE = 178;
    int32 internal constant SENDER_DOES_NOT_OWN_NFT_SERIAL_NO = 237;
    int32 internal constant SPENDER_DOES_NOT_HAVE_ALLOWANCE = 292;
    int32 internal constant MAX_ALLOWANCES_EXCEEDED = 294;
}
