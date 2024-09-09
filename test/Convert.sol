// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

library Convert {
    function addressToString(address _addr) public pure returns (string memory) {
        bytes20 value = bytes20(_addr);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i] & 0x0f))];
        }
        bytes memory bStr = bytes(string(str));
        for (uint i = 0; i < bStr.length; i++) {
            if (uint8(bStr[i]) >= 65 && uint8(bStr[i]) <= 90) {
                bStr[i] = bytes1(uint8(bStr[i]) + 32);
            }
        }
        return string(bStr);
    }

    function accountIdToUint256(string memory input) public pure returns (uint256) {
        bytes memory strBytes = bytes(input);
        uint256 num = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] >= "0" && strBytes[i] <= "9") {
                num = num * 10 + (uint8(strBytes[i]) - 48);
            }
        }

        return num;
    }

    function uintToString(uint _i) public pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function stringToUint256(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        require(b.length > 0, "Input string is empty");

        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] < 0x30 || b[i] > 0x39) continue;
            uint256 digit = uint256(uint8(b[i])) - 48;
            result = result * 10 + digit;
        }

        return result;
    }

    function replaceSubstring(
        string memory original,
        string memory target,
        string memory replacement
    ) public pure returns (string memory) {
        bytes memory originalBytes = bytes(original);
        bytes memory targetBytes = bytes(target);
        bytes memory replacementBytes = bytes(replacement);
        bytes memory resultBytes = new bytes(originalBytes.length);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < originalBytes.length; i++) {
            bool isMatching = true;
            if (i + targetBytes.length <= originalBytes.length) {
                for (uint256 j = 0; j < targetBytes.length; j++) {
                    if (originalBytes[i + j] != targetBytes[j]) {
                        isMatching = false;
                        break;
                    }
                }
                if (isMatching) {
                    for (uint256 k = 0; k < replacementBytes.length; k++) {
                        resultBytes[resultIndex++] = replacementBytes[k];
                    }
                    i += targetBytes.length - 1;
                } else {
                    resultBytes[resultIndex++] = originalBytes[i];
                }
            } else {
                resultBytes[resultIndex++] = originalBytes[i];
            }
        }
        bytes memory finalResult = new bytes(resultIndex);
        for (uint256 i = 0; i < resultIndex; i++) {
            finalResult[i] = resultBytes[i];
        }

        return string(finalResult);
    }

    function stringToBytes(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length >= 2 && ss[0] == '0' && ss[1] == 'x', "Hex string must start with 0x");
        uint256 len = (ss.length - 2) / 2;
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; ++i) {
            result[i] = bytes1(Convert.charToBytes(uint8(ss[2 + i * 2])) * 16 + Convert.charToBytes(uint8(ss[3 + i * 2])));
        }
        return result;
    }

    function charToBytes(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= '0' && bytes1(c) <= '9') {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= 'a' && bytes1(c) <= 'f') {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= 'A' && bytes1(c) <= 'F') {
            return 10 + c - uint8(bytes1('A'));
        }
        revert("Invalid hex character");
    }

    function addressToHederaString(address tokenAddress) public pure returns (string memory) {
        uint256 rawAddress = uint256(uint160(tokenAddress));
        uint256 shard = 0;
        uint256 realm = 0;
        uint256 token = rawAddress;
        return string(abi.encodePacked(uintToString(shard), ".", uintToString(realm), ".", uintToString(token)));
    }
}
