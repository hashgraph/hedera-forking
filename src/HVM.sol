// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

library HVM {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getSlot(string memory field) pure internal returns (uint256) {
        bytes32 search = keccak256(abi.encodePacked(field));
        if (search == keccak256(abi.encodePacked("name"))) return 0;
        if (search == keccak256(abi.encodePacked("symbol"))) return 1;
        if (search == keccak256(abi.encodePacked("decimals"))) return 2;
        if (search == keccak256(abi.encodePacked("totalSupply"))) return 3;
        if (search == keccak256(abi.encodePacked("maxSupply"))) return 4;
        if (search == keccak256(abi.encodePacked("freezeDefault"))) return 5;
        if (search == keccak256(abi.encodePacked("supplyType"))) return 6;
        if (search == keccak256(abi.encodePacked("pauseStatus"))) return 7;
        if (search == keccak256(abi.encodePacked("adminKey"))) return 8;
        if (search == keccak256(abi.encodePacked("feeScheduleKey"))) return 10;
        if (search == keccak256(abi.encodePacked("freezeKey"))) return 12;
        if (search == keccak256(abi.encodePacked("kycKey"))) return 14;
        if (search == keccak256(abi.encodePacked("pauseKey"))) return 16;
        if (search == keccak256(abi.encodePacked("supplyKey"))) return 18;
        if (search == keccak256(abi.encodePacked("wipeKey"))) return 20;
        if (search == keccak256(abi.encodePacked("expiryTimestamp"))) return 22;
        if (search == keccak256(abi.encodePacked("autoRenewAccount"))) return 23;
        if (search == keccak256(abi.encodePacked("autoRenewPeriod"))) return 24;
        if (search == keccak256(abi.encodePacked("customFees"))) return 25;
        if (search == keccak256(abi.encodePacked("deleted"))) return 29;
        if (search == keccak256(abi.encodePacked("memo"))) return 30;
        if (search == keccak256(abi.encodePacked("treasuryAccountId"))) return 31;
        if (search == keccak256(abi.encodePacked("initialized"))) return 32;
        if (search == keccak256(abi.encodePacked("initializedAllowances"))) return 33;
        if (search == keccak256(abi.encodePacked("initializedBalances"))) return 34;
        revert("Making an attempt to get slot number for an unknown field");
    }

    function storeString(address target, uint256 startingSlot, string memory value) internal {
        if (bytes(value).length == 0) {
            vm.store(target, bytes32(startingSlot), bytes32(0));
            return;
        }

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

    function storeUint(address target, uint256 slot, uint256 value) internal {
        bytes32 uintData = bytes32(value);
        vm.store(target, bytes32(slot), uintData);
    }

    function storeBool(address target, uint256 slot, bool value) internal {
        bytes32 boolData = value ? bytes32(uint256(1)) : bytes32(uint256(0));
        vm.store(target, bytes32(slot), boolData);
    }

    function storeAddress(address target, uint256 slot, address value) internal {
        bytes32 addressData = bytes32(uint256(uint160(value)));
        vm.store(target, bytes32(slot), addressData);
    }
}
