// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./JsonRpcCall.sol";

contract HtsSystemContractLocalNode {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function allowCheatcodes(address target) external {
        vm.allowCheatcodes(target);
    }

    fallback (bytes calldata) external returns (bytes memory) {
        HtsSystemContractLocalNode(address(0x167)).allowCheatcodes(address(this));
        address sender = msg.sender;
        bytes memory data = msg.data;

        string memory rpcPayload = string(abi.encodePacked(
            "{",
            '"jsonrpc":"2.0",',
            '"method":"eth_call",',
            '"params":[{"from":"', vm.toString(sender), '","to":"', vm.toString(address(0x167)), '","data":"', vm.toString(data), '"},"latest"],',
            '"id":1',
            "}"
        ));

        string memory scriptStart = 'response=$(curl -s -w "\\n%{http_code}" ';
        string memory scriptEnd = '); status=$(tail -n1 <<< "$response"); data=$(sed "$ d" <<< "$response"); cast abi-encode "response(uint256,string)" "$status" "$data";';

        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(
            scriptStart,
            '-H "Content-Type: application/json" -X POST -d \'',
            rpcPayload,
            '\' http://localhost:7546 ',
            scriptEnd
        );

        bytes memory res = vm.ffi(inputs);
        (uint256 status, bytes memory response) = abi.decode(res, (uint256, bytes));
        require(status == 200, "Wrong response status");
        return vm.parseJsonBytes(string(response), ".result");
    }
}
