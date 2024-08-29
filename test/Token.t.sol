// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/IERC20.sol";

interface MethodNotSupported {
    function methodNotSupported() external view returns (uint256);
}

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
contract TokenTest is Test {

    /**
     * https://hashscan.io/testnet/token/0.0.429274
     * https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
     */
    address USDC = 0x0000000000000000000000000000000000068cDa;

    function setUp() external view {
        console.log("HTS code has %d bytes", address(0x167).code.length);
    }

    function test_ERC20_name() view external {
        assertEq(IERC20(USDC).name(), "USD Coin");
    }

    function test_ERC20_large_name() view external {
        address customToken = 0x0000000000000000000000000000000000483077;
        assertEq(IERC20(customToken).name(), "My Crypto Token is the name which the string length is greater than 31");
    }

    function test_ERC20_symbol() view external {
        assertEq(IERC20(USDC).symbol(), "USDC");
    }

    function test_ERC20_decimals() view external {
        assertEq(IERC20(USDC).decimals(), 6);
    }

    function test_ERC20_totalSupply() view external {
        assertEq(IERC20(USDC).totalSupply(), 10000000005000000);
    }

    function test_ERC20_should_revert_for_method_not_supported() external {
        vm.expectRevert(bytes("redirectForToken: not supported"));
        MethodNotSupported(USDC).methodNotSupported();
    }

    function test_ERC20_balanceOf_deal() external {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        assertEq(IERC20(USDC).balanceOf(bob), 0);

        deal(USDC, alice, 1000 * 10e8);

        uint256 balance = IERC20(USDC).balanceOf(alice);
        console.log("alice's balance %s", balance);
        assertEq(balance, 1000 * 10e8);

        // Bob's balance should remain unchanged
        assertEq(IERC20(USDC).balanceOf(bob), 0);
    }

    function test_ERC20_balanceOf_should_return_zero_for_non_existent_account() external {
        address alice = makeAddr("alice");
        uint256 balance = IERC20(USDC).balanceOf(alice);
        assertEq(balance, 0);
    }

    function test_ERC20_balanceOf_call() view external {
        // https://hashscan.io/testnet/account/0.0.1421
        address alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        uint256 balance = IERC20(USDC).balanceOf(alice);
        console.log("alice's balance %s", balance);
        assertEq(balance, 49_300000);

        // https://hashscan.io/testnet/account/0.0.2183
        address bob = 0x0000000000000000000000000000000000000887;
        balance = IERC20(USDC).balanceOf(bob);
        console.log("bob's balance %s", balance);
        assertEq(balance, 366_000000);
    }

    function test_ERC20_allowance() view external {
        // https://hashscan.io/testnet/account/0.0.4233295
        address owner = address(0x100000000000000000000000000000000040984f);
        // https://hashscan.io/testnet/account/0.0.1335
        address spender = 0x0000000000000000000000000000000000000537;
        assertEq(IERC20(USDC).allowance(owner, spender), 5_000000);
    }

    function test_ERC20_allowance_empty() external {
        // https://hashscan.io/testnet/account/0.0.4233295
        address owner = address(0x100000000000000000000000000000000040984f);
        address spender = makeAddr("alice");
        assertEq(IERC20(USDC).allowance(owner, spender), 0);
    }
}
