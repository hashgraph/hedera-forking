// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {storeString} from "../src/StrStore.sol";

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
}

contract C {
    string public name;
    uint256 public gap;
    string public symbol;
}