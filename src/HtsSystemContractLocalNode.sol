// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "./IERC20.sol";
import {IHRC719} from "./IHRC719.sol";

contract HtsSystemContractLocalNode {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function allowCheatcodes(address target) external {
        vm.allowCheatcodes(target);
    }

    fallback (bytes calldata) external returns (bytes memory) {
        HtsSystemContractLocalNode(address(0x167)).allowCheatcodes(address(this));
        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = _getBashScript();
        require(1 == 2, inputs[2]);
        bytes memory res = vm.ffi(inputs);
        (uint256 status, bytes memory response) = abi.decode(res, (uint256, bytes));
        require(status == 200, "Wrong response status");
        return vm.parseJsonBytes(string(response), ".result");
    }

    function _getBashScript() private returns (string memory) {
        address sender = msg.sender;
        bytes memory data = msg.data;
        if (_isViewCall()) {
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
            return string.concat(
                scriptStart,
                '-H "Content-Type: application/json" -X POST -d \'',
                rpcPayload,
                '\' http://localhost:7546 ',
                scriptEnd
            );
        }
        return string.concat(
            'hedera-call ',
            vm.toString(data),
            ' ',
            vm.toString(sender),
            ' ',
            vm.toString(address(0x167)),
            ' ',
            '0x6666666' // Fixme;
        );
    }

    function _isViewCall() private returns (bool) {
        bytes4 selector = bytes4(msg.data[24:28]);
        return
            selector == IERC20.name.selector ||
            selector == IERC20.decimals.selector ||
            selector == IERC20.totalSupply.selector ||
            selector == IERC20.symbol.selector ||
            selector == IERC20.balanceOf.selector ||
            selector == IHRC719.isAssociated.selector ||
            selector == IERC20.allowance.selector
        ;
    }
}
