// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IMirrorNode {
    function getTokenData(address token) external returns (string memory json);

    function getBalance(address token, address account) external returns (string memory json);

    function getAllowance(address token, address owner, address spender) external returns (string memory json);
}
