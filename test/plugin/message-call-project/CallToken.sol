// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IERC20 {
    function decimals() external view returns (uint8);
}

contract CallToken {
    function getTokenDecimals(address tokenAddress) external view returns (uint8) {
        return IERC20(tokenAddress).decimals();
    }
}
