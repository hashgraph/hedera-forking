// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    address alice;

    function setUp() external {
        // To be returned by the Relay
        deployCodeTo("HtsSystemContract.sol", address(0x167));
        deployCodeTo("TokenProxy.sol", USDC);

        alice = makeAddr("alice");

        deal(alice, 100 * 10e8);
        // deal(USDC, alice, 1000 * 10e8);
    }

    function test_UserBalance() external view {
        uint256 userBalance = IERC20(USDC).balanceOf(alice);
        console.log("alice balance %s", userBalance);
        // assertEq(userBalance, 1000 * 10e8);
    }
}
