// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

function slice(uint start, uint end, string memory str) pure returns (string memory) {
    bytes memory strBytes = bytes(str);
    require(end > start && end <= strBytes.length, "Invalid start or end");
    bytes memory result = new bytes(end - start);
    for (uint i = start; i < end; i++) {
        result[i - start] = strBytes[i];
    }
    return string(result);
}

function parseUint(string memory numString) pure returns (uint) {
    uint val = 0;
    bytes memory stringBytes = bytes(numString);
    for (uint i = 0; i < stringBytes.length; i++) {
        require(uint8(stringBytes[i]) >= 48 && uint8(stringBytes[i]) <= 57, "parseUint: invalid string");
        val = val * 10 + (uint8(stringBytes[i]) - 48);
    }
    return val;
}
