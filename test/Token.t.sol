// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TokenCreateContract} from "../src/TokenCreateContract.sol";

contract TokenTest is Test {
    /**
     * https://hashscan.io/testnet/token/0.0.4630846
     */
    address Token_testnet = 0x000000000000000000000000000000000046A93e;

    function setUp() external {
        // To be returned by the Relay
        deployCodeTo("HtsSystemContract.sol", address(0x167));
    }

    function test_DeployWrapAndCreateToken() external {
        TokenCreateContract factory = new TokenCreateContract();

        factory.createFungibleTokenPublic{value : 0.5 ether}(address(factory));
    }
}
