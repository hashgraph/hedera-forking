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

    MocksToStorageLoader private loader;

    /**
     * 3 modes
     */
    function setUpMockStorageForNonFork() internal {
        console.log("HTS code has %d bytes", HTS.code.length);
        if (HTS.code.length == 0) {
            console.log("HTS code length is 0, non-fork test, code and data provided locally");
            loader = new MocksToStorageLoader(HTS);
            loader.loadHts();
            loader.loadToken(USDC, "USDC");
            loader.loadToken(MFCT, "MFCT");
        } else if (HTS.code.length == 1) {
            console.log("HTS code length is 1, forking from a remote Hedera network, HTS code with Mirror Node backend is deployed here");
            deployCodeTo("HtsSystemContractInitialized.sol", HTS);
            vm.allowCheatcodes(HTS);
        } else {
            console.log("HTS code length is greater than 1, HTS code comes from `json-rpc-mock`");
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
