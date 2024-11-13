// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MirrorNodeFFI} from "../src/MirrorNodeFFI.sol";

contract MirrorNodeFFITest is Test {

    address private constant USDC = 0x0000000000000000000000000000000000068cDa;

    // https://hashscan.io/testnet/account/0.0.1421
    address private constant alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;

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
        string memory json = _mirrorNode.getBalance(address(0x12345678), alice);
        assert(!vm.keyExistsJson(json, ".balances[0].balance"));
    }

    function test_get_balance_for_existing_account() external {
        vm.skip(_skip);
        string memory json = _mirrorNode.getBalance(USDC, alice);
        uint256 amount = vm.parseJsonUint(json, ".balances[0].balance");
        assertEq(amount, 49_300_000);
    }

    function test_revert_when_get_allowance_for_invalid_token_address() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Invalid token address"));
        _mirrorNode.getAllowance(makeAddr("invalid-token-address"), makeAddr("owner"), makeAddr("spender"));
    }

    function test_revert_when_get_allowance_for_unknown_owner() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Account not found"));
        _mirrorNode.getAllowance(address(0x12345678), makeAddr("owner"), makeAddr("spender"));
    }

    function test_revert_when_get_allowance_for_unknown_spender() external {
        vm.skip(_skip);
        vm.expectRevert(bytes("Account not found"));
        _mirrorNode.getAllowance(address(0x12345678), alice, makeAddr("spender"));
    }

    function test_get_allowance_for_unknown_token() external {
        vm.skip(_skip);
        string memory json = _mirrorNode.getAllowance(address(0x12345678), alice, alice);
        assert(!vm.keyExistsJson(json, ".allowances[0].amount"));
    }

    function test_get_allowance() external {
        vm.skip(_skip);
        // https://hashscan.io/testnet/account/0.0.4233295
        address owner = address(0x000000000000000000000000000000000040984F);
        // https://hashscan.io/testnet/account/0.0.1335
        address spender = 0x0000000000000000000000000000000000000537;
        string memory json = _mirrorNode.getAllowance(address(USDC), owner, spender);
        uint256 amount = vm.parseJsonUint(json, ".allowances[0].amount");
        assertEq(amount, 5_000_000);
    }
}
