// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {Surl} from "surl/src/Surl.sol";

Vm constant _vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

function getTokenData(address token) returns (string memory) {
    (uint256 status, bytes memory data) = Surl.get(string.concat(
        _mirrorNodeUrl(),
        "tokens/0.0.",
        _vm.toString(uint160(token))
    ));
    require(status == 200, "Failed to get token data from the Hedera MirrorNode");
    return string(data);
}

function getAllowance(address token, address owner, address spender) returns (uint256) {
    (uint256 status, bytes memory json) = Surl.get(string.concat(
        _mirrorNodeUrl(),
        "accounts/0.0.",
        _vm.toString(_getAccountIdCached(owner)),
        "/allowances/tokens?token.id=0.0.",
        _vm.toString(uint160(token)),
        "&spender.id=0.0.",
        _vm.toString(_getAccountIdCached(spender))
    ));

    if (status == 200 && _vm.keyExistsJson(string(json), ".allowances[0].amount")) {
        return abi.decode(_vm.parseJson(string(json), ".allowances[0].amount"), (uint256));
    }
    return 0;
}

function getBalance(address token, address account) returns (uint256) {
    uint32 accountId = _getAccountIdCached(account);
    if (accountId == 0) {
        return 0;
    }
    (uint256 status, bytes memory json) = Surl.get(string.concat(
        _mirrorNodeUrl(),
        "tokens/0.0.",
        _vm.toString(uint160(token)),
        "/balances?account.id=0.0.",
        _vm.toString(accountId)
    ));
    if (status != 200) {
        return 0;
    }
    if (_vm.keyExistsJson(string(json), ".balances[0].balance")) {
        return abi.decode(_vm.parseJson(string(json), ".balances[0].balance"), (uint256));
    }

    return 0;
}

// Lets store the response somewhere in order to prevent multiple calls for the same account id
function _getAccountIdCached(address account) returns (uint32) {
    address target = address(0x167);
    uint64 pad = 0x0;
    bytes32 cachedValueSlot = bytes32(abi.encodePacked(bytes4(0xe0b490f8), pad, account));
    bytes32 cacheStatusSlot = bytes32(abi.encodePacked(bytes4(0xe0b490f9), pad, account));
    if (uint256(_vm.load(target, cacheStatusSlot)) != 0) {
        return uint32(uint256(_vm.load(target, cachedValueSlot)));
    }
    uint32 accountId = _getAccountId(account);
    _vm.store(target, bytes32(cachedValueSlot), bytes32(uint256(accountId)));
    _vm.store(target, bytes32(cacheStatusSlot), bytes32(uint256(1)));
    return accountId;
}

function _getAccountId(address account) returns (uint32) {
    (uint256 status, bytes memory json) = Surl.get(string.concat(
        _mirrorNodeUrl(),
        "accounts/",
        _vm.toString(account)
    ));
    if (status != 200) {
        return 0;
    }

    return uint32(_vm.parseUint(
        _vm.replace(abi.decode(_vm.parseJson(string(json), ".account"), (string)), "0.0.", ""))
    );
}

function _mirrorNodeUrl() view returns (string memory) {
    if (block.chainid == 295) {
        return "https://mainnet-public.mirrornode.hedera.com/api/v1/";
    }
    if (block.chainid == 296) {
        return "https://testnet.mirrornode.hedera.com/api/v1/";
    }
    if (block.chainid == 297) {
        return "https://previewnet.mirrornode.hedera.com/api/v1/";
    }

    revert("The provided chain ID is not supported by the Hedera Mirror Node library. Please use one of the supported chain IDs: 295, 296, or 297.");
}
