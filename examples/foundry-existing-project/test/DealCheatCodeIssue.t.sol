// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "src/IERC20.sol";

contract DealCheatCodeIssueTest is Test {
    address USDC_mainnet = 0x000000000000000000000000000000000006f89a;
    address user1;

    function setUp() public {
        // Add the lines below to make this test work correctly!
        deployCodeTo("HtsSystemContractInitialized.sol", address(0x167));
        vm.allowCheatcodes(address(0x167));
        // 2 lines required only.

        user1 = makeAddr("user_one");

        deal(user1, 100 * 10e8);
        deal(USDC_mainnet, user1, 1000 * 10e8);
    }

    function test_UserBalance() public {
        uint256 userBalance = IERC20(USDC_mainnet).balanceOf(user1);
        assertEq(userBalance, 1000 * 10e8);
    }
}
