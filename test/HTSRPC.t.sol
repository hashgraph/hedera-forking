// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";

contract HTSRPCTest is Test {
    /**
     * https://hashscan.io/testnet/token/0.0.429274
     */
    address USDC_testnet = 0x0000000000000000000000000000000000068cDa;

    function test_RPCETH_call_not_working() external {
        // $ cast sig 'decimals()'
        // 0x313ce567
        bytes memory result = vm.rpc("eth_call", string.concat('[{"to":"', vm.toString(USDC_testnet), '", "data":"', vm.toString(bytes(hex"313ce567")),'"}, ', '"latest"]'));
        console.logBytes(result);
    }
}
