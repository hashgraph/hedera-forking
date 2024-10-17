// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "./IERC20.sol";

contract CallToken {
    function getTokenName(address tokenAddress) external view returns (string memory) {
        return IERC20(tokenAddress).name();
    }
}
