// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {storeString, storeBytes, storeUint, storeInt, storeBool, storeAddress, storeBytes32} from "../src/StrStore.sol";

contract StrStoreTest is Test {

    C private _c;

    function setUp() external {
        _c = new C();
    }

    function storeStringTest(string memory value) private {
        storeString(address(_c), 0, value);
        assertEq(_c.name(), value);

        storeString(address(_c), 2, value);
        assertEq(_c.symbol(), value);

        assertEq(_c.gap(), 0);
    }

    function storeBytesTest(bytes memory value) private {
        storeBytes(address(_c), 3, value);
        assertEq(_c.someBytes(), value);

        assertEq(_c.someInt(), 0);

        storeBytes(address(_c), 5, value);
        assertEq(_c.someOtherBytes(), value);
    }

    function storeUintTest(uint256 value) private {
        storeUint(address(_c), 1, value);
        assertEq(_c.gap(), value);
        assertEq(_c.name(), "");
        assertEq(_c.symbol(), "");
    }

    function storeIntTest(int256 value) private {
        storeInt(address(_c), 4, value);
        assertEq(_c.someInt(), value);
        assertEq(_c.someBytes(), new bytes(0));
        assertEq(_c.someOtherBytes(), new bytes(0));

        storeInt(address(_c), 9, value);
        assertEq(_c.someOtherInt(), value);
    }

    function storeBoolTest(bool value) private {
        storeBool(address(_c), 6, value);
        assertEq(_c.someBool(), value);
        assertEq(_c.someBytes32(), bytes32(0));
        assertEq(_c.someOtherBytes(), new bytes(0));
    }

    function storeAddressTest(address value) private {
        storeAddress(address(_c), 8, value);
        assertEq(_c.someAddress(), value);
        assertEq(_c.someOtherInt(), 0);
        assertEq(_c.someBytes32(), bytes32(0));
    }

    function storeBytes32Test(bytes32 value) private {
        storeBytes32(address(_c), 7, value);
        assertEq(_c.someBytes32(), value);
        assertEq(_c.someBool(), false);
        assertEq(_c.someAddress(), address(0));
    }

    // Strings

    function test_store_string_empty_string() external {
        storeStringTest("");
    }

    function test_store_string_single_char() external {
        storeStringTest("a");
    }

    function test_store_string_some_string() external {
        storeStringTest("some string");
    }

    function test_store_string_with_len_32() external {
        storeStringTest("01234567890123456789012345678901");
    }

    function test_store_string_with_len_gt_32() external {
        storeStringTest("01234567890123456789012345678901 some string");
    }

    function test_store_string_with_len_64() external {
        storeStringTest("0123456789012345678901234567890101234567890123456789012345678901");
    }

    function test_store_string_with_len_gt_64() external {
        storeStringTest("0123456789012345678901234567890101234567890123456789012345678901 some string");
    }

    // Bytes

    function test_store_bytes_empty() external {
        storeBytesTest(bytes(""));
    }

    function test_store_bytes_some_bytes() external {
        storeBytesTest(bytes("some bytes"));
    }

    function test_store_bytes_some_other_bytes() external {
        storeBytesTest(abi.encodePacked(bytes32(0)));
    }

    // Unsigned integers

    function test_store_uint_zero() external {
        storeUintTest(0);
    }

    function test_store_uint_max() external {
        storeUintTest(type(uint256).max);
    }

    // Integers

    function test_store_int_zero() external {
        storeIntTest(0);
    }

    function test_store_int_max() external {
        storeIntTest(type(int256).max);
    }

    function test_store_int_min() external {
        storeIntTest(type(int256).min);
    }

    // Booleans
    function test_store_bool_true() external {
        storeBoolTest(true);
    }

    function test_store_bool_false() external {
        storeBoolTest(false);
    }

    // Addresses

    function test_store_address_zero() external {
        storeAddressTest(address(0));
    }

    function test_store_address_some_address() external {
        storeAddressTest(address(0x1234567890123456789012345678901234567890));
    }

    // Bytes32

    function test_store_bytes32_zero() external {
        storeBytes32Test(bytes32(0));
    }

    function test_store_bytes32_some_bytes32() external {
        storeBytes32Test(bytes32("some bytes32"));
    }
}

contract C {
    string public name;
    uint256 public gap;
    string public symbol;
    bytes public someBytes;
    int256 public someInt;
    bytes public someOtherBytes;
    bool public someBool;
    bytes32 public someBytes32;
    address public someAddress;
    int256 public someOtherInt;
}
