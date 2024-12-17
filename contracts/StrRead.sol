// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

function readString(bytes32 slot) returns (string memory returnBuffer) {
    bytes32 lengthSlot = slot;
    bytes32 baseSlot = keccak256(abi.encodePacked(slot));

    assembly {
        let stringLength := sload(lengthSlot)
        let isShortArray := iszero(and(stringLength, 0x01))
        let decodedStringLength := div(and(stringLength, 0xFF), 2)

        // Allocate memory for the return buffer
        returnBuffer := mload(0x40)
        mstore(returnBuffer, decodedStringLength)

        switch isShortArray
        case 1 {
            // Short array
            mstore(add(returnBuffer, 0x20), and(stringLength, not(0xFF)))
            mstore(0x40, add(returnBuffer, 0x40))
        }
        default {
            // Long array
            decodedStringLength := div(stringLength, 2)
            let end := add(baseSlot, div(add(decodedStringLength, 31), 32))
            let offset := 0x20

            for { } lt(baseSlot, end) { baseSlot := add(baseSlot, 1) } {
                mstore(add(returnBuffer, offset), sload(baseSlot))
                offset := add(offset, 0x20)
            }

            mstore(0x40, add(returnBuffer, offset))
        }
    }
}
