// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
     * https://hashscan.io/mainnet/token/0.0.456858
     */
    address USDC_mainnet = 0x000000000000000000000000000000000006f89a;
    /**
     * https://hashscan.io/testnet/token/0.0.429274
     */
    address USDC_testnet = 0x0000000000000000000000000000000000068cDa;
    address USDC = USDC_testnet;

    function setUp() external {
        if (address(0x167).code.length <= 1) {
            console.log("HTS code empty or `0xfe`, deploying HTS locally to `0x167`");
            deployCodeTo("HtsSystemContract.sol", address(0x167));
            deployCodeTo("TokenProxy.sol", USDC);
        } else
            console.log("HTS code coming from fork (%d bytes), skip local deployment", address(0x167).code.length);

        vm.allowCheatcodes(USDC);
    }

    function test_ERC20_totalSupply() view external {
        assertEq(IERC20Metadata(USDC).totalSupply(), 49300000);
    }

    function test_ERC20_decimals() view external {
        assertEq(IERC20Metadata(USDC).decimals(), 6);
    }

    function test_ERC20_balanceOf_dealt() external {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        // assertEq(IERC20(USDC).balanceOf(bob), 0);

        deal(alice, 100 * 10e8);
        deal(USDC, alice, 1000 * 10e8);

        uint256 balance = IERC20Metadata(USDC).balanceOf(alice);
        console.log("alice's balance %s", balance);
        assertEq(balance, 1000 * 10e8);

        // Bob's balance should remain unchanged
        // assertEq(IERC20(USDC).balanceOf(bob), 0);
    }

    function test_ERC20_balanceOf_call() view external {
        address alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;

        uint256 balance = IERC20Metadata(USDC).balanceOf(alice);
        console.log("alice's balance %s", balance);
        assertEq(balance, 49300000);
    }
}