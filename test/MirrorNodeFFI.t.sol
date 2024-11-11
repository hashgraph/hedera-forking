// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MirrorNodeFFI} from "../src/MirrorNodeFFI.sol";

contract MirrorNodeFFITest is Test {

    address private constant USDC = 0x0000000000000000000000000000000000068cDa;

    // https://hashscan.io/testnet/account/0.0.1421
    address private constant alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;

    // https://hashscan.io/testnet/account/0.0.1335
    address private constant bob = 0x0000000000000000000000000000000000000537;

    MirrorNodeFFI private _mirrorNode;

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

            _mirrorNode = new MirrorNodeFFI();
        }
    }

    function test_revert_when_get_token_data_for_invalid_token_address() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Invalid token address"));
        _mirrorNode.getTokenData(makeAddr("invalid-token-address"));
    }

    function test_revert_when_get_token_data_for_unknown_token() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Status not OK"));
        _mirrorNode.getTokenData(address(0x12345678));
    }

    function test_get_data_for_existing_token() external {
        vm.skip(_skip);
        string memory json = _mirrorNode.getTokenData(USDC);
        assertEq(vm.parseJsonString(json, ".name"), "USD Coin");
        assertEq(vm.parseJsonString(json, ".symbol"), "USDC");
        assertEq(vm.parseJsonUint(json, ".decimals"), 6);
        assertEq(vm.parseJsonUint(json, ".total_supply"), 10000000005000000);
    }

    function test_revert_when_get_balance_for_invalid_token_address() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Invalid token address"));
        _mirrorNode.getBalance(makeAddr("invalid-token-address"), makeAddr("account"));
    }

    function test_get_balance_for_unknown_account() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Account not found"));
        _mirrorNode.getBalance(address(0x12345678), makeAddr("account"));
    }

    function test_revert_when_get_balance_for_unknown_token() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Status not OK"));
        _mirrorNode.getBalance(address(0x12345678), alice);
    }

    function test_get_balance_for_existing_account() external {
        vm.skip(_skip);
        string memory json = _mirrorNode.getBalance(USDC, alice);
        uint256 amount = abi.decode(vm.parseJson(json, ".balances[0].balance"), (uint256));
        assertEq(amount, 49_300_000);
    }

    function test_revert_when_get_allowance_for_invalid_token_address() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Invalid token address"));
        _mirrorNode.getAllowance(makeAddr("invalid-token-address"), makeAddr("owner"), makeAddr("spender"));
    }

}
