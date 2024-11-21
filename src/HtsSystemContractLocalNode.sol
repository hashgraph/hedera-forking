// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./JsonRpcCall.sol";

contract HtsSystemContractLocalNode {
    fallback (bytes calldata) external returns (bytes memory) {
        (uint256 status, bytes memory response) = JsonRpcCall.ethCall();
        return response;
    }
}
