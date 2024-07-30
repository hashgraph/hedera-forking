// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TokenCreateContract} from "../src/wrap/TokenCreateContract.sol";

contract CounterScript is Script {
    function setUp() external {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_PK");
        console.log("Executing transaction under `%s`", vm.addr(deployerPrivateKey));
        // vm.startBroadcast(deployerPrivateKey);

        address treasury = vm.addr(deployerPrivateKey);
        // TokenCreateContract.createFungibleTokenPublic(treasury);

        // vm.stopBroadcast();
    }
}
