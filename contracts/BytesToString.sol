// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0;

function bytesToString(bytes memory data) pure returns (string memory) {
    bytes memory HEX_SYMBOLS = "0123456789abcdef";
    bytes memory buffer = new bytes(2 + data.length * 2);
    buffer[0] = "0";
    buffer[1] = "x";
    for (uint i = 0; i < data.length; i++) {
        buffer[2 + i * 2] = HEX_SYMBOLS[uint8(data[i]) >> 4];
        buffer[3 + i * 2] = HEX_SYMBOLS[uint8(data[i]) & 0x0f];
    }
    return string(buffer);
}
