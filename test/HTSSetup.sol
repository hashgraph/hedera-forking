// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

import {HtsSystemContract} from "../src/HtsSystemContract.sol";
    using stdStorage for StdStorage;

contract HTSSetup is Test {

    address HTS = 0x0000000000000000000000000000000000000167;

    function extractNumberFromAccountId(string memory input) public pure returns (uint256) {
        bytes memory strBytes = bytes(input);
        uint256 num = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] >= "0" && strBytes[i] <= "9") {
                num = num * 10 + (uint8(strBytes[i]) - 48);
            }
        }

        return num;
    }

    function setUpHTS() internal {
        console.log("HTS code has %d bytes", HTS.code.length);
        if (HTS.code.length == 0) {
            console.log("HTS code empty, deploying HTS locally to `0x167`");
            deployCodeTo("HtsSystemContract.sol", HTS);
            string memory path = string.concat(vm.projectRoot(), "/test/data/getAccount_0x4d1c823b5f15be83fdf5adaf137c2a9e0e78fe15.json");
            string memory json = vm.readFile(path);
            uint256 accountId = extractNumberFromAccountId(string(vm.parseJson(json, ".account")));
            stdstore
                .target(HTS)
                .sig(HtsSystemContract.getAccountId.selector)
                .with_key(0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15)
                .checked_write(accountId);
        }
    }
}