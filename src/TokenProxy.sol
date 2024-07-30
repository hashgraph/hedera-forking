// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.12;

import {console} from "forge-std/Test.sol";
import {IHTS} from "./lib/IHTS.sol";

contract TokenProxy {
 fallback() external payable {
     address precompileAddress = address(0x167);
        // console.log("pre is %s", precompileAddress);
        // console.logBytes(msg.data);
        // IHTS(precompileAddress).redirectForToken(0xfefeFEFeFEFEFEFEFeFefefefefeFEfEfefefEfe, msg.data);
     assembly {
         mstore(0, 0x618dc65eFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFE)
         calldatacopy(32, 0, calldatasize())


         let result := call(gas(), precompileAddress, 0, 8, add(24, calldatasize()), 0, 0)
         let size := returndatasize()
         returndatacopy(0, 0, size)
         switch result
             case 0 { revert(0, size) }
             default { return(0, size) }
     }
 }
}
