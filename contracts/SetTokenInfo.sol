// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHederaTokenService} from "./IHederaTokenService.sol";

contract SetTokenInfo {
    // The following state variables must be in the same slot as in `HtsSystemContract.tokenType`.
    string private _tokenType;
    uint256 private __gap1;
    uint256 private __gap2;
    uint8 private _decimals;

    function setTokenInfo(string memory tokenType, IHederaTokenService.TokenInfo memory tokenInfo, int32 decimals) external {
        _tokenType = tokenType;
        _decimals = uint8(uint32(decimals));

        assembly { sstore(19, 1) }

        IHederaTokenService.TokenInfo storage _tokenInfo;
        assembly { _tokenInfo.slot := 5 }

        // Error (1834): Copying of type struct IHederaTokenService.TokenKey memory[] memory to storage is not supported in legacy (only supported by the IR pipeline).
        // Hint: try compiling with `--via-ir` (CLI) or the equivalent `viaIR: true` (Standard JSON)
        // https://docs.soliditylang.org/en/v0.8.28/ir-breaking-changes.html
        // https://github.com/ethereum/solidity/issues/3446#issuecomment-1924761902
        // _tokenInfo = tokenInfo;
        // _tokenInfo.token.tokenKeys = tokenInfo.token.tokenKeys;

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

        // The same copying issue for fee arrays
        // _tokenInfo.fixedFees = tokenInfo.fixedFees;
        // _tokenInfo.fractionalFees = tokenInfo.fractionalFees;
        // _tokenInfo.royaltyFees = tokenInfo.royaltyFees;
        for (uint256 i = 0; i < tokenInfo.fixedFees.length; i++) {
            _tokenInfo.fixedFees.push(tokenInfo.fixedFees[i]);
        }
        for (uint256 i = 0; i < tokenInfo.fractionalFees.length; i++) {
            _tokenInfo.fractionalFees.push(tokenInfo.fractionalFees[i]);
        }
        for (uint256 i = 0; i < tokenInfo.royaltyFees.length; i++) {
            _tokenInfo.royaltyFees.push(tokenInfo.royaltyFees[i]);
        }

        _tokenInfo.ledgerId = tokenInfo.ledgerId;
    }
}
