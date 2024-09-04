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
}
