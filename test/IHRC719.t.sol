// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {TestSetup} from "./lib/TestSetup.sol";
import {IHRC719} from "src/IHRC719.sol";


contract IHRC719TokenAssociationTest is Test, TestSetup {
    function setUp() external {
        setUpMockStorageForNonFork();
    }

    function test_IHRC719_isAssociated() external {
        address msgSender = makeAddr("msgSender");
        assignAccountIdsToEVMAddressesForNonFork(msgSender);

        vm.prank(msgSender);
        assertEq(IHRC719(USDC).isAssociated(), false);
    }

    function test_IHRC719_associate() external {
        address msgSender = makeAddr("msgSender");
        assignAccountIdsToEVMAddressesForNonFork(msgSender);

        vm.startPrank(msgSender);
        assertEq(IHRC719(USDC).associate(), 1);
        assertEq(IHRC719(USDC).isAssociated(), true);
        vm.stopPrank();
    }

    function test_IHRC719_dissociate() external {
        address msgSender = makeAddr("msgSender");
        assignAccountIdsToEVMAddressesForNonFork(msgSender);

        vm.startPrank(msgSender);
        assertEq(IHRC719(USDC).dissociate(), 1);
        assertEq(IHRC719(USDC).isAssociated(), false);
        vm.stopPrank();
    }

     function test_IHRC719_associate_then_dissociate() external {
        address msgSender = makeAddr("msgSender");
        assignAccountIdsToEVMAddressesForNonFork(msgSender);

        vm.startPrank(msgSender);
        assertEq(IHRC719(USDC).associate(), 1);
        assertEq(IHRC719(USDC).isAssociated(), true);
        assertEq(IHRC719(USDC).dissociate(), 1);
        assertEq(IHRC719(USDC).isAssociated(), false);
        vm.stopPrank();
    }
    
    function test_IHRC719_different_accounts() external {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        assignAccountIdsToEVMAddressesForNonFork(alice, bob);

        vm.startPrank(alice);
        assertEq(IHRC719(USDC).associate(), 1);
        assertEq(IHRC719(USDC).isAssociated(), true);
        
        vm.startPrank(bob);
        assertEq(IHRC719(USDC).isAssociated(), false);
        assertEq(IHRC719(USDC).associate(), 1);
        assertEq(IHRC719(USDC).isAssociated(), true);

        vm.startPrank(alice);
        assertEq(IHRC719(USDC).dissociate(), 1);
        assertEq(IHRC719(USDC).isAssociated(), false);

        vm.stopPrank();
    }
}
