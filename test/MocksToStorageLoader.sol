// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {IERC20} from "../src/IERC20.sol";
import {Convert} from "./Convert.sol";

import {HtsSystemContract} from "../src/HtsSystemContract.sol";

using stdStorage for StdStorage;

contract MocksToStorageLoader is CommonBase, StdCheats {
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
        string memory path = string.concat(vm.projectRoot(), "/test/data/getAccount_", Convert.addressToString(account), ".json");
        string memory json = vm.readFile(path);
        uint256 accountId = Convert.accountIdToUint256(string(vm.parseJson(json, ".account")));
        assignEvmAccountAddress(account, accountId);
    }

    function calculateSalt(address desiredAddress, bytes memory bytecode) internal view returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), bytes32(0), keccak256(bytecode))
        );
        require(address(uint160(uint256(hash))) == desiredAddress, "Desired address cannot be achieved");
        return bytes32(0);
    }

    function deployCodeWithCreate2(bytes memory bytecode, bytes32 salt) internal returns (address) {
        address addr;
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "Deployment failed");
        return addr;
    }

    function replacePlaceholder(
        bytes memory bytecode,
        bytes memory placeholder,
        bytes32 newAddress
    ) internal pure returns (bytes memory) {
        bytes memory updatedBytecode;
        uint256 startIndex = findPlaceholderIndex(bytecode, placeholder);

        if (startIndex == type(uint256).max) {
            revert("Placeholder not found");
        }
        updatedBytecode = new bytes(startIndex + 32); // Assuming address is 32 bytes
        uint256 index;
        for (index = 0; index < startIndex; index++) {
            updatedBytecode[index] = bytecode[index];
        }
        for (uint256 i = 0; i < 32; i++) {
            updatedBytecode[startIndex + i] = newAddress[i];
        }
        uint256 placeholderLength = placeholder.length;
        uint256 remainingLength = bytecode.length - (startIndex + placeholderLength);
        for (uint256 j = 0; j < remainingLength; j++) {
            updatedBytecode[startIndex + 32 + j] = bytecode[startIndex + placeholderLength + j];
        }

        return updatedBytecode;
    }

    function findPlaceholderIndex(bytes memory bytecode, bytes memory placeholder) internal pure returns (uint256) {
        for (uint256 i = 0; i <= bytecode.length - placeholder.length; i++) {
            bool isMatching = true;
            for (uint256 j = 0; j < placeholder.length; j++) {
                if (bytecode[i + j] != placeholder[j]) {
                    isMatching = false;
                    break;
                }
            }
            if (isMatching) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function deployTokenProxyBytecode(address tokenAddress) internal {
        string memory placeholder = "6666666666666666666666666666666666666666";
        string memory bytecodePath = string.concat(vm.projectRoot(), "/src/TokenProxyBytecode.hex");
        string memory addressString = Convert.replaceSubstring(Convert.addressToString(tokenAddress), "0x", "");
        string memory updatedBytecode = Convert.replaceSubstring(vm.readFile(bytecodePath), placeholder, addressString);
        vm.etch(tokenAddress, Convert.stringToBytes(updatedBytecode));
    }

    function _loadTokenData(address tokenAddress, string memory configName) internal {
        deployTokenProxyBytecode(tokenAddress);
        string memory path = string.concat(vm.projectRoot(), "/test/data/", configName,"/getToken.json");
        string memory json = vm.readFile(path);
        string memory name = abi.decode(vm.parseJson(json, ".name"), (string));
        uint256 decimals = uint8(Convert.stringToUint256(string(vm.parseJson(json, ".decimals"))));
        string memory symbol = abi.decode(vm.parseJson(json, ".symbol"), (string));
        uint256 totalSupply = Convert.stringToUint256(string(vm.parseJson(json, ".total_supply")));

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


    function _loadAllowancesOfAnAccount(address tokenAddress, string memory configName, address ownerEVMAddress, address spenderEVMAddress) internal {
        uint256 ownerId = HtsSystemContract(HTS).getAccountId(ownerEVMAddress);
        string memory ownerIdString = Convert.uintToString(ownerId);
        uint256 spenderId = HtsSystemContract(HTS).getAccountId(spenderEVMAddress);
        string memory spenderIdString = Convert.uintToString(spenderId);
        string memory path = string.concat(vm.projectRoot(), "/test/data/", configName, "/getAllowanceForToken_0.0.", ownerIdString, "_0.0.", spenderIdString, ".json");
        uint256 allowance = 0;
        try vm.readFile(path) returns (string memory json) {
            if (vm.keyExistsJson(json, ".allowances[0].amount")) {
                allowance = abi.decode(vm.parseJson(json, ".allowances[0].amount"), (uint256));
            }
        } catch {
            console.log(string.concat("Allowances are not configured for token ", configName, " in path", path ));
        }
        stdstore
            .target(tokenAddress)
            .sig(IERC20.allowance.selector)
            .with_key(ownerEVMAddress)
            .with_key(spenderEVMAddress)
            .checked_write(allowance);
    }

    function _loadBalanceOfAnAccount(address tokenAddress, string memory configName, address accountEVMAddress) internal {
        uint256 accountId = HtsSystemContract(HTS).getAccountId(accountEVMAddress);
        string memory accountIdString = Convert.uintToString(accountId);
        string memory path = string.concat(vm.projectRoot(), "/test/data/", configName, "/getBalanceOfToken_0.0.", accountIdString, ".json");
        uint256 balance = 0;
        try vm.readFile(path) returns (string memory json) {
            if (vm.keyExistsJson(json, ".balances[0].balance")) {
                balance = abi.decode(vm.parseJson(json, ".balances[0].balance"), (uint256));
            }
        } catch {
            console.log(string.concat("Balances are not configured for token ", configName, " in path", path ));
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

    function loadToken(address tokenAddress, string memory tokenConfigName) external {
        _loadTokenData(tokenAddress, tokenConfigName);
        _loadBalanceOfAnAccount(tokenAddress, tokenConfigName, 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15);
        _loadBalanceOfAnAccount(tokenAddress, tokenConfigName, 0x0000000000000000000000000000000000000887);
        _loadAllowancesOfAnAccount(tokenAddress, tokenConfigName, 0x100000000000000000000000000000000040984f, 0x0000000000000000000000000000000000000537);
    }
}
