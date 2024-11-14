// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library StringUtils {

    function slice(uint start, uint end, string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        require(end > start && end <= strBytes.length, "Invalid start or end");
        bytes memory result = new bytes(end - start);
        for (uint i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }

    function compare(string memory _a, string memory _b) public pure returns (int) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;

        uint i = 0;
        while (i + 32 <= minLength) {
            bytes32 aPart;
            bytes32 bPart;
            assembly {
                aPart := mload(add(a, add(32, i)))
                bPart := mload(add(b, add(32, i)))
            }
            if (aPart < bPart) return -1;
            else if (aPart > bPart) return 1;
            i += 32;
        }

        for (; i < minLength; i++) {
            if (a[i] < b[i]) return -1;
            else if (a[i] > b[i]) return 1;
        }

        if (a.length < b.length) return -1;
        else if (a.length > b.length) return 1;
        else return 0;
    }

    function parseUint(string memory numString) public pure returns (uint) {
        uint val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint i = 0; i < stringBytes.length; i++) {
            require(uint8(stringBytes[i]) >= 48 && uint8(stringBytes[i]) <= 57, "parseUint: invalid string");
            val = val * 10 + (uint8(stringBytes[i]) - 48);
        }
        return val;
    }
}
