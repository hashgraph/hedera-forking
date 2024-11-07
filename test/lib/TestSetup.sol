// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Vm} from "forge-std/Vm.sol";

import {MocksToStorageLoader} from "./MocksToStorageLoader.sol";

abstract contract TestSetup is StdCheats {
    // `vm` is private in StdCheats, so we duplicate it here
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address internal constant HTS = 0x0000000000000000000000000000000000000167;

    /**
     * https://hashscan.io/testnet/token/0.0.429274
     * https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.429274
     */
    address internal USDC = 0x0000000000000000000000000000000000068cDa;

    /**
     * https://hashscan.io/testnet/token/0.0.4730999
     * https://testnet.mirrornode.hedera.com/api/v1/tokens/0.0.4730999
     */
    address internal MFCT = 0x0000000000000000000000000000000000483077;

    /**
     * 3 test modes.
     */
    enum TestMode {
        /**
         * No forking configuration was given for testing.
         * - Code is deployed locally.
         * - Data is mocked and provided locally.
         */
        NonFork,

        /**
         * HTS/FFI using Mirror Node requests as backend.
         * To enable this mode, Foundry must be set to fork from a Hedera remote network.
         * - Code using FFI is deployed locally.
         * - Data comes from `curl` requests, which can be mocked or a Hedera remote network.
         */
        FFI,

        /**
         * HTS bytecode comes from the Hedera remote network.
         * This is usually through the Hardhat plugin,
         * but also can be through `json-rpc-mock`.
         * - Code comes from remote network.
         * - Data comes from JSON-RPC `eth_getStorageAt` calls.
         */
        JSON_RPC
    }

    TestMode internal testMode;

    MocksToStorageLoader private loader;

    function setUpMockStorageForNonFork() internal {
        console.log("HTS code has %d bytes", HTS.code.length);
        if (HTS.code.length == 0) {
            console.log("HTS code length is 0, non-fork test, code and data provided locally");
            loader = new MocksToStorageLoader(HTS);
            loader.loadHts();
            loader.loadToken(USDC, "USDC");
            loader.loadToken(MFCT, "MFCT");

            testMode = TestMode.NonFork;
        } else if (HTS.code.length == 1) {
            console.log("HTS code length is 1, forking from a remote Hedera network, HTS/FFI code with Mirror Node backend is deployed here");
            deployCodeTo("HtsSystemContractFFI.sol", HTS);
            vm.allowCheatcodes(HTS);

            testMode = TestMode.FFI;
        } else {
            console.log("HTS code length is greater than 1, HTS code comes from forked network");
            
            testMode = TestMode.JSON_RPC;
        }
    }

    function assignAccountIdsToEVMAddressesForNonFork(address firstAddress) internal {
        if (address(loader) != address(0)) {
            loader.assignEvmAccountAddress(firstAddress, 1);
        }
    }

    function assignAccountIdsToEVMAddressesForNonFork(address firstAddress, address secondAddress) internal {
        if (address(loader) != address(0)) {
            loader.assignEvmAccountAddress(firstAddress, 1);
            loader.assignEvmAccountAddress(secondAddress, 2);
        }
    }
}
