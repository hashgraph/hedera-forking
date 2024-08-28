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
contract FungibleTokenTest is Test {

    /**
     * https://hashscan.io/testnet/token/0.0.429274
     * https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
     */
    address USDC = 0x0000000000000000000000000000000000068cDa;
    address FT = 0x000000000000000000000000000000000047b52A;

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

    function test_ERC20_balanceOf_call() external {
        address alice = 0x292c4acf9ec49aF888D4051Eb4A4dc53694D1380;
        uint256 balance = IERC20(FT).balanceOf(alice);
        console.log("alice's balance %s", balance);
        assertEq(balance, 9995);
    }

    function test_ERC20_transfer_call() external {
        address alice = 0x292c4acf9ec49aF888D4051Eb4A4dc53694D1380;
        address bob = makeAddr("bob");
        uint256 balance = IERC20(FT).balanceOf(alice);
        console.log("alice's balance %s", balance);
        assertEq(balance, 9995);
        vm.startPrank(alice);
        IERC20(FT).transfer(bob, 9992);
        vm.stopPrank();
        assertEq(IERC20(FT).balanceOf(bob), 9992);
        assertEq(IERC20(FT).balanceOf(alice), 3);
    }

    function test_ERC20_deal() external {
        address alice = 0x292c4acf9ec49aF888D4051Eb4A4dc53694D1380;
        deal(USDC, alice, 1000 * 10e8);
        assertEq(IERC20(USDC).balanceOf(alice), 1000 * 10e8);
    }
}