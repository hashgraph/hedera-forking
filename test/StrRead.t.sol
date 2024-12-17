// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {readString} from "../contracts/StrRead.sol";
import {storeString} from "../contracts/StrStore.sol";

contract StrReadTest is Test {

    function test_readString_given_short_string() public {
        bytes32 slot = keccak256(abi.encodePacked("hello"));
        string memory value = "world";
        storeString(address(this), uint256(slot), value);

        string memory result = readString(slot);
        assertEq(result, "world");
    }

    function test_readString_given_long_string() public {
        bytes32 slot = keccak256(abi.encodePacked("hello"));
        string memory value = "Very long string, just to make sure that it exceeds 31 bytes and requires more than 1 storage slot.";
        storeString(address(this), uint256(slot), value);

        string memory result = readString(slot);
        assertEq(result, value);
    }

    function test_readString_given_empty_string() public {
        bytes32 slot = keccak256(abi.encodePacked("hello"));
        string memory value = "";
        storeString(address(this), uint256(slot), value);

        string memory result = readString(slot);
        assertEq(result, "");
    }

    function test_readString_given_unoccupied_slot() public {
        bytes32 slot = keccak256(abi.encodePacked("hello"));
        string memory result = readString(slot);
        assertEq(result, "");
    }
}
