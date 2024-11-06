// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "./IERC20.sol";
import {console} from "hardhat/console.sol";

contract CallToken {
    function getTokenName(address tokenAddress) external view returns (string memory) {
        return IERC20(tokenAddress).name();
    }

    function invokeTransferFrom(address tokenAddress, address to, uint256 amount) external {
        // You can use `console.log` as usual
        // https://hardhat.org/tutorial/debugging-with-hardhat-network#solidity--console.log
        console.log("Transferring from %s to %s %s tokens", msg.sender, to, amount);
        IERC20(tokenAddress).transferFrom(msg.sender, to, amount);
    }
}
