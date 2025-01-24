// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHederaTokenService} from "./IHederaTokenService.sol";

contract SetTokenInfo {
    // The state variables must be in the same slot as in `HtsSystemContract.tokenType`.
    string private _tokenType;
    // uint256 private __gap1;
    // uint256 private __gap2;
    uint8 private _decimals;
    uint256 private __gap3;
    IHederaTokenService.TokenInfo private _tokenInfo;

    function setTokenInfo(string memory tokenType, IHederaTokenService.TokenInfo memory tokenInfo, int32 decimals) external {
        _tokenType = tokenType;
        _decimals = uint8(uint32(decimals));

        assembly { sstore(16, 1) }

        // The assignment
        //
        // _tokenInfo = tokenInfo;
        //
        // cannot be used directly because it triggers the following compilation error
        //
        // Error (1834): Copying of type struct IHederaTokenService.TokenKey memory[] memory to storage is not supported in legacy (only supported by the IR pipeline).
        // Hint: try compiling with `--via-ir` (CLI) or the equivalent `viaIR: true` (Standard JSON)
        //
        // More specifically, the assigment
        //
        // _tokenInfo.token.tokenKeys = tokenInfo.token.tokenKeys;
        //
        // triggers the above error as well.
        //
        // Array assignments from memory to storage are not supported in legacy codegen https://github.com/ethereum/solidity/issues/3446#issuecomment-1924761902.
        // And using the `--via-ir` flag as mentioned above increases compilation time substantially
        // That is why we are better off copying the struct to storage manually.

        _tokenInfo.token.name = tokenInfo.token.name;
        _tokenInfo.token.symbol = tokenInfo.token.symbol;
        _tokenInfo.token.treasury = tokenInfo.token.treasury;
        _tokenInfo.token.memo = tokenInfo.token.memo;
        _tokenInfo.token.tokenSupplyType = tokenInfo.token.tokenSupplyType;
        _tokenInfo.token.maxSupply = tokenInfo.token.maxSupply;
        _tokenInfo.token.freezeDefault = tokenInfo.token.freezeDefault;

        for (uint256 i = 0; i < tokenInfo.token.tokenKeys.length; i++) {
            _tokenInfo.token.tokenKeys.push(tokenInfo.token.tokenKeys[i]);
        }

        _tokenInfo.token.expiry = tokenInfo.token.expiry;

        _tokenInfo.totalSupply = tokenInfo.totalSupply;
        _tokenInfo.deleted = tokenInfo.deleted;
        _tokenInfo.defaultKycStatus = tokenInfo.defaultKycStatus;
        _tokenInfo.pauseStatus = tokenInfo.pauseStatus;

        // The same copying issue as mentioned above for fee arrays.
        // _tokenInfo.fixedFees = tokenInfo.fixedFees;
        for (uint256 i = 0; i < tokenInfo.fixedFees.length; i++) {
            _tokenInfo.fixedFees.push(tokenInfo.fixedFees[i]);
        }
        // _tokenInfo.fractionalFees = tokenInfo.fractionalFees;
        for (uint256 i = 0; i < tokenInfo.fractionalFees.length; i++) {
            _tokenInfo.fractionalFees.push(tokenInfo.fractionalFees[i]);
        }
        // _tokenInfo.royaltyFees = tokenInfo.royaltyFees;
        for (uint256 i = 0; i < tokenInfo.royaltyFees.length; i++) {
            _tokenInfo.royaltyFees.push(tokenInfo.royaltyFees[i]);
        }

        _tokenInfo.ledgerId = tokenInfo.ledgerId;
    }
}
