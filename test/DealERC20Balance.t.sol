// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "../src/IERC20.sol";
import {TestSetup} from "./lib/TestSetup.sol";

contract DealCheatCodeIssueTest is Test, TestSetup {
    address user1;

    function setUp() public {
        setUpMockStorageForNonFork();

        user1 = makeAddr("user1");

        deal(user1, 100 * 10e8);
        deal(USDC, user1, 1000 * 10e8);
    }

    function test_UserBalance() view public {
        uint256 userBalance = IERC20(USDC).balanceOf(user1);
        assertEq(userBalance, 1000 * 10e8);
    }
}
