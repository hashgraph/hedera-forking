// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.12;

interface IHTS {
    function redirectForToken(address token, bytes memory data) external view returns (uint256);
}
