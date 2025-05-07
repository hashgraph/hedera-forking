// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Script, VmSafe} from "forge-std/Script.sol";
import {IERC20} from "hedera-forking/IERC20.sol";
import {Hsc} from "hedera-forking/Hsc.sol";
import {Approver} from "../src/Approver.sol";

/**
 * Usage
 *
 * forge script ApproveTokenScript --sig "deployApprover()" --rpc-url testnet --broadcast
 * 
 * Notice that the `--skip-simulation` is not needed because there is no HTS involved in this step.
 * 
 * forge script ApproveTokenScript --sig "run(address,address)" $TOKEN_ADDR $APPROVER --rpc-url testnet --broadcast --skip-simulation
 * 
 * where $APPROVER is the address returned in the previous step.
 */
contract ApproveTokenScript is Script {
    uint256 private PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

    function deployApprover() external returns (Approver approver) {
        vm.startBroadcast(PRIVATE_KEY);
        approver = new Approver();
        vm.stopBroadcast();
    }

    function run(address tokenAddress, address approver) external returns (address payable account) {
        Hsc.htsSetup();

        vm.startBroadcast(PRIVATE_KEY);
        Approver(approver).associate(tokenAddress);

        IERC20(tokenAddress).transfer(approver, 50000);

        VmSafe.Wallet memory wallet = vm.createWallet("wallet");
        account = payable(wallet.addr);
        account.transfer(1 ether); // 1 HBAR

        Approver(approver).approve(tokenAddress, account, 400_0000);

        vm.stopBroadcast();
    }
}
