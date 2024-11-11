// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HtsSystemContract, HTS_ADDRESS} from "../src/HtsSystemContract.sol";
import {TestSetup} from "./lib/TestSetup.sol";

contract HTSTest is Test, TestSetup {

    function setUp() external {
        setUpMockStorageForNonFork();
    }

    function test_HTS_should_revert_when_not_enough_calldata() external {
        vm.expectRevert(bytes("fallback: not enough calldata"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.call(bytes("1234"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_should_revert_when_fallback_selector_is_not_supported() external {
        vm.expectRevert(bytes("fallback: unsupported selector"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.call(bytes("123456789012345678901234567890"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_should_revert_when_calldata_token_is_not_caller() external {
        vm.expectRevert(bytes("fallback: token is not caller"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.call(bytes(hex"618dc65e9012345678901234567890123456789012345678901234567890"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_getAccountId_should_return_account_number() view external {
        // In FFI mode, `getAccountId` is not needed, so we can omit this test.
        if (testMode != TestMode.JSON_RPC) {
            return;
        }

        // https://hashscan.io/testnet/account/0.0.1421
        address alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(alice);
        assertEq(accountId, 1421);
    }

    function test_HTS_should_revert_when_delegatecall_getAccountId() external {
        vm.expectRevert(bytes("htsCall: delegated call"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.delegatecall(abi.encodeWithSelector(HtsSystemContract.getAccountId.selector, address(this)));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }
}
