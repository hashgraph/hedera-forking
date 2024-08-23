// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "../src/IERC20.sol";

/**
 * Test using USDC, an already existing HTS Token.
 *
 * Test based on issue https://github.com/hashgraph/hedera-smart-contracts/issues/863.
 *
 * For more details about USDC on Hedera, see https://www.circle.com/en/multi-chain-usdc/hedera.
 *
 * To get USDC balances for a given account using the Mirror Node you can use
 * https://mainnet.mirrornode.hedera.com/api/v1/tokens/0.0.456858/balances?account.id=0.0.38047
 */
contract USDCTest is Test {

    /**
     * https://hashscan.io/testnet/token/0.0.429274
     * https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
     */
    address USDC = 0x0000000000000000000000000000000000068cDa;

    function setUp() external view {
        console.log("HTS code has %d bytes", address(0x167).code.length);
    }

    function test_ERC20_name() view external {
        assertEq(IERC20(USDC).name(), "USDC asdf");
    }

    function test_ERC20_decimals() view external {
        assertEq(IERC20(USDC).decimals(), 6);
    }

    function test_ERC20_totalSupply() view external {
        assertEq(IERC20(USDC).totalSupply(), 10000000000000000);
    }

    function test_ERC20_balanceOf_dealt() external {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        // assertEq(IERC20(USDC).balanceOf(bob), 0);

        deal(alice, 100 * 10e8);
        deal(USDC, alice, 1000 * 10e8);

        uint256 balance = IERC20(USDC).balanceOf(alice);
        console.log("alice's balance %s", balance);
        assertEq(balance, 1000 * 10e8);

        // Bob's balance should remain unchanged
        // assertEq(IERC20(USDC).balanceOf(bob), 0);
    }

    function test_ERC20_balanceOf_call() view external {
        address alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;

        uint256 balance = IERC20(USDC).balanceOf(alice);
        console.log("alice's balance %s", balance);
        assertEq(balance, 49300000);
    }
}