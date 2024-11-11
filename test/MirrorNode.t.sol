// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../src/MirrorNode.sol" as MirrorNode;

contract MirrorNodeTest is Test {

    address private constant USDC = 0x0000000000000000000000000000000000068cDa;

    bool private _skip;

    function setUp() external {
        try vm.activeFork() {
            _skip = true;
            console.log("Active fork detected, this test runs only in non-forked mode");
        } catch {
            _skip = false;
            vm.chainId(296);

            string memory PATH = vm.envString("PATH");
            vm.setEnv("PATH", string.concat("./scripts:", PATH));
        }
    }

    function test_get_balance_for_unknown_account() external {
        vm.skip(_skip);
        uint amount = MirrorNode.getBalance(USDC, makeAddr("user"));
        assertEq(amount, 0);
    }

    function test_get_balance_for_existing_account() external {
        vm.skip(_skip);
        // https://hashscan.io/testnet/account/0.0.1421
        address alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        uint amount = MirrorNode.getBalance(USDC, alice);
        assertEq(amount, 49_300_000);
    }
}
