// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

/**
 * @dev This library provides utility functions originally from the Surl library.
 *
 * The original Surl library can be found at: https://github.com/memester-xyz/surl
 *
 * We have inlined the necessary functionality from Surl instead of using it as a submodule
 * to keep dependencies lean and avoid unnecessary submodule cloning. Using Surl as a submodule
 * previously required pulling multiple additional dependencies, including an outdated version of
 * Foundry (v1.3.0) and other libraries such as forge-std, solidity-stringutils, and ds-test.
 *
 * By inlining the required code, we reduce dependency bloat and improve maintainability.
 */
library Surl {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /**
     * @notice Performs an HTTP GET request to the specified URL.
     * @dev Uses the HEVM cheat code to execute a cURL command via `ffi`.
     *
     * The request is executed as a shell command, capturing both the HTTP response body
     * and the status code. The response is formatted to be ABI-encoded before returning.
     *
     * @param url The target URL to send the GET request to.
     * @return status The HTTP status code returned by the request.
     * @return data The response body as raw bytes.
     */
    function get(string memory url) internal returns (uint256 status, bytes memory data) {
        string memory scriptStart = 'response=$(curl -s -w "\\n%{http_code}" ';
        string memory scriptEnd = '); status=$(tail -n1 <<< "$response"); data=$(sed "$ d" <<< "$response");data=$(echo "$data" | tr -d "\\n"); cast abi-encode "response(uint256,string)" "$status" "$data";';
        string memory curlParams = "";
        curlParams = string.concat(curlParams, " -X  GET ");
        string memory quotedURL = string.concat('"', url, '"');
        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(scriptStart, curlParams, quotedURL, scriptEnd);
        bytes memory res = vm.ffi(inputs);
        (status, data) = abi.decode(res, (uint256, bytes));
    }
}
