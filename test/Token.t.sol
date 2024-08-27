// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "../src/IERC20.sol";

import {HtsSystemContract} from "../src/HtsSystemContract.sol";

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

    address HTS = 0x0000000000000000000000000000000000000167;

    /**
     * https://hashscan.io/testnet/token/0.0.429274
     * https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
     */
    address USDC = 0x0000000000000000000000000000000000068cDa;

    function setUp() external view {
        console.log("HTS code has %d bytes", address(0x167).code.length);
        address account = USDC;
        uint64 padding = 0x0000_0000_0000_0000;
        uint256 slot = uint256(bytes32(abi.encodePacked(IERC20.balanceOf.selector, padding, account)));
        console.log("slot %x",slot);
    }

    function test_HTS_should_revert_when_not_enough_calldata() external {
        vm.expectRevert(bytes("Not enough calldata"));
        (bool revertsAsExpected, ) = HTS.call(bytes("1234"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_should_revert_when_fallback_selector_is_not_supported() external {
        vm.expectRevert(bytes("Fallback selector not supported"));
        (bool revertsAsExpected, ) = HTS.call(bytes("123456789012345678901234567890"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_should_revert_when_calldata_token_is_not_caller() external {
        vm.expectRevert(bytes("Calldata token is not caller"));
        (bool revertsAsExpected, ) = HTS.call(bytes(hex"618dc65e9012345678901234567890123456789012345678901234567890"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
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
        assertEq(IERC20(USDC).totalSupply(), 10000000000000000);
    }

    function test_ERC20_balanceOf_dealt() private {
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

    function test_getAccountId() view external {
        // https://hashscan.io/testnet/account/0.0.1421
        address alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        uint32 accountId = HtsSystemContract(HTS).getAccountId(alice);
        assertEq(accountId, 1421);
    }
}
