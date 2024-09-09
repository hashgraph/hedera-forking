// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {IERC20} from "../src/IERC20.sol";
import {Convert} from "./Convert.sol";

import {HtsSystemContract} from "../src/HtsSystemContract.sol";
import {Surl} from "surl/src/Surl.sol";

using stdStorage for StdStorage;
using Surl for string;

contract MocksToStorageLoader is CommonBase, StdCheats {
    string MIRRORNODE_URL = "https://testnet.mirrornode.hedera.com/";
    string RPC_URL = "https://testnet.hashio.io/api/";
    uint256 HTTPS_STATUS_OK = 200;

    address HTS;
    constructor(address _HTS) {
        HTS = _HTS;
    }

    function _assignStringToSlot(address target, uint256 startingSlot, string memory value) internal
    {
        if (bytes(value).length <= 31) {
            bytes32 rightPaddedSymbol;
            assembly {
                rightPaddedSymbol := mload(add(value, 32))
            }
            bytes32 storageSlotValue = bytes32(bytes(value).length * 2) | rightPaddedSymbol;
            vm.store(target, bytes32(startingSlot), storageSlotValue);
            return;
        }
        bytes memory valueBytes = bytes(value);
        uint256 length = bytes(value).length;
        bytes32 lengthLeftPadded = bytes32(length * 2 + 1);
        vm.store(target, bytes32(startingSlot), lengthLeftPadded);
        uint256 numChunks = (length + 31) / 32;
        bytes32 baseSlot = keccak256(abi.encodePacked(startingSlot));
        for (uint256 i = 0; i < numChunks; i++) {
            bytes32 chunk;
            uint256 chunkStart = i * 32;
            uint256 chunkEnd = chunkStart + 32;
            if (chunkEnd > length) {
                chunkEnd = length;
            }
            for (uint256 j = chunkStart; j < chunkEnd; j++) {
                chunk |= bytes32(valueBytes[j]) >> (8 * (j - chunkStart));
            }
            vm.store(target, bytes32(uint256(baseSlot) + i), chunk);
        }
    }

    function assignEvmAccountAddress(address account, uint256 accountId) public {
        stdstore
            .target(HTS)
            .sig(HtsSystemContract.getAccountId.selector)
            .with_key(account)
            .checked_write(accountId);
    }

    function _loadAccountData(address account) internal {
        string memory accountIdString = Convert.replaceSubstring(Convert.addressToString(account), "0x1", "0x0");
        (uint256 status, bytes memory json) = string.concat(MIRRORNODE_URL, "api/v1/accounts/", accountIdString).get();
        require(status == HTTPS_STATUS_OK);
        uint256 accountId = Convert.accountIdToUint256(string(vm.parseJson(string(json), ".account")));
        assignEvmAccountAddress(account, accountId);
    }

    function deployTokenProxyBytecode(address tokenAddress) internal {
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        (uint256 status, bytes memory json) = RPC_URL.post(headers, string.concat("{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"", Convert.addressToString(tokenAddress),"\", \"latest\"],\"id\":1}"));
        require(status == HTTPS_STATUS_OK);
        string memory updatedBytecode = abi.decode(vm.parseJson(string(json), ".result"), (string));
        vm.etch(tokenAddress, Convert.stringToBytes(string.concat("0x", updatedBytecode)));
    }

    function _loadTokenData(address tokenAddress) internal {
        string memory tokenId = Convert.addressToHederaString(tokenAddress);
        (uint256 status, bytes memory json) = string.concat(MIRRORNODE_URL, "api/v1/tokens/", tokenId).get();
        require(status == HTTPS_STATUS_OK);
        string memory data = string(json);
        deployTokenProxyBytecode(tokenAddress);
        string memory name = abi.decode(vm.parseJson(data, ".name"), (string));
        uint256 decimals = uint8(Convert.stringToUint256(string(vm.parseJson(data, ".decimals"))));
        string memory symbol = abi.decode(vm.parseJson(data, ".symbol"), (string));
        uint256 totalSupply = Convert.stringToUint256(string(vm.parseJson(data, ".total_supply")));

        stdstore
            .target(tokenAddress)
            .sig(IERC20.decimals.selector)
            .checked_write(decimals);
        stdstore
            .target(tokenAddress)
            .sig(IERC20.totalSupply.selector)
            .checked_write(totalSupply);

        // 0 - hardcoded name slot number; stdstore.find(...) fails for strings...
        _assignStringToSlot(tokenAddress, 0, name);

        // 1 - hardcoded symbol slot number; stdstore.find(...) fails for strings...
        _assignStringToSlot(tokenAddress, 1, symbol);
    }


    function _loadAllowancesOfAnAccount(address tokenAddress, address ownerEVMAddress, address spenderEVMAddress) internal {
        uint256 ownerId = HtsSystemContract(HTS).getAccountId(ownerEVMAddress);
        string memory ownerIdString = Convert.uintToString(ownerId);
        uint256 spenderId = HtsSystemContract(HTS).getAccountId(spenderEVMAddress);
        string memory spenderIdString = Convert.uintToString(spenderId);
        string memory tokenId = Convert.addressToHederaString(tokenAddress);
        (uint256 status, bytes memory json) = string.concat(MIRRORNODE_URL, "api/v1/accounts/", ownerIdString, "/allowances/tokens?token.id=", tokenId, "&spender.id=", spenderIdString).get();
        string memory data = string(json);
        uint256 allowance = 0;
        if (status == HTTPS_STATUS_OK) {
            if (vm.keyExistsJson(data, ".allowances[0].amount")) {
                allowance = abi.decode(vm.parseJson(data, ".allowances[0].amount"), (uint256));
            }
        } else {
            console.log(string.concat("Allowances are not configured for token ", tokenId));
        }
        stdstore
            .target(tokenAddress)
            .sig(IERC20.allowance.selector)
            .with_key(ownerEVMAddress)
            .with_key(spenderEVMAddress)
            .checked_write(allowance);
    }

    function _loadBalanceOfAnAccount(address tokenAddress, address accountEVMAddress) internal {
        uint256 accountId = HtsSystemContract(HTS).getAccountId(accountEVMAddress);
        string memory accountIdString = Convert.uintToString(accountId);

        string memory tokenId = Convert.addressToHederaString(tokenAddress);
        (uint256 status, bytes memory json) = string.concat(MIRRORNODE_URL, "api/v1/tokens/", tokenId, "/balances?account.id=", accountIdString).get();
        string memory data = string(json);
        uint256 balance = 0;
        if (status == HTTPS_STATUS_OK) {
            if (vm.keyExistsJson(data, ".balances[0].balance")) {
                balance = abi.decode(vm.parseJson(data, ".balances[0].balance"), (uint256));
            }
        } else {
            console.log(string.concat("Balances are not configured for token ", tokenId));
        }
        stdstore
            .target(tokenAddress)
            .sig(IERC20.balanceOf.selector)
            .with_key(accountEVMAddress)
            .checked_write(balance);
    }

    function loadHts() external {
        deployCodeTo("HtsSystemContract.sol", HTS);
        _loadAccountData(0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15);
        _loadAccountData(0x0000000000000000000000000000000000000887);
        _loadAccountData(0x0000000000000000000000000000000000000537);
        _loadAccountData(0x100000000000000000000000000000000040984f);
    }

    function loadToken(address tokenAddress) external {
        _loadTokenData(tokenAddress);
        _loadBalanceOfAnAccount(tokenAddress, 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15);
        _loadBalanceOfAnAccount(tokenAddress, 0x0000000000000000000000000000000000000887);
        _loadAllowancesOfAnAccount(tokenAddress, 0x100000000000000000000000000000000040984f, 0x0000000000000000000000000000000000000537);
    }
}
