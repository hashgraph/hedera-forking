// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";

library JsonRpcCall {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function ethCall() internal returns (uint256 status, bytes memory response) {
        bytes memory txData = _getTransactionData();
        string memory rpcPayload = _buildRpcPayload(txData);
        return _sendRpcRequest(rpcPayload);
    }

    function _getTransactionData() private view returns (bytes memory) {
        address sender = msg.sender;
        uint256 value = msg.value;
        bytes memory data = msg.data;

        return abi.encodePacked(
            "{",
            '"jsonrpc":"2.0",',
            '"method":"eth_call",',
            '"params":[{"from":"', _toHex(sender), '","to":"', _toHex(address(this)), '","value":"0x', _toHex(value), '","data":"0x', _bytesToHex(data), '"},"latest"],',
            '"id":1',
            "}"
        );
    }

    function _buildRpcPayload(bytes memory txData) private pure returns (string memory) {
        return string(txData);
    }

    function _sendRpcRequest(string memory rpcPayload) private returns (uint256 status, bytes memory response) {
        string memory scriptStart = 'response=$(curl -s -w "\\n%{http_code}" ';
        string memory scriptEnd = '); status=$(tail -n1 <<< "$response"); data=$(sed "$ d" <<< "$response"); cast abi-encode "response(uint256,string)" "$status" "$data";';

        string[] memory inputs;
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(
            scriptStart,
            '-H "Content-Type: application/json" -X POST -d \'',
            rpcPayload,
            '\' http://localhost:7456 ',
            scriptEnd
        );

        bytes memory res = vm.ffi(inputs);

        (status, response) = abi.decode(res, (uint256, bytes));
    }

    function _toHex(address addr) private pure returns (string memory) {
        return _bytesToHex(abi.encodePacked(addr));
    }

    function _toHex(uint256 value) private pure returns (string memory) {
        bytes memory buffer = new bytes(32);
        assembly {
            mstore(add(buffer, 32), value)
        }
        return _bytesToHex(buffer);
    }

    function _bytesToHex(bytes memory data) private pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory hexData = new bytes(data.length * 2);
        for (uint256 i = 0; i < data.length; i++) {
            hexData[i * 2] = hexChars[uint8(data[i] >> 4)];
            hexData[i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }
        return string(hexData);
    }
}
