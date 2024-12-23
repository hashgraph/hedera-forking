// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "./IERC20.sol";
import {IHRC719} from "./IHRC719.sol";
import {IHTSDefinitions} from "../contracts/IHTSDefinitions.sol";

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
        bytes memory res = vm.ffi(inputs);
        (uint256 status, bytes memory response) = abi.decode(res, (uint256, bytes));
        require(status == 200 || status == 404, string(response));
        bytes memory result = vm.parseJsonBytes(string(response), ".result");
        _handleResult(result);
        return result;
    }

    function _handleResult(bytes memory response) private {
        bytes4 selector = bytes4(msg.data[0:4]);
        if (
            selector == IHTSDefinitions.createFungibleToken.selector ||
            selector == IHTSDefinitions.createNonFungibleToken.selector ||
            selector == IHTSDefinitions.createFungibleTokenWithCustomFees.selector ||
            selector == IHTSDefinitions.createNonFungibleTokenWithCustomFees.selector
        ) {
            (int responseCode, address tokenAddress) = abi.decode(response, (int, address));
            if (responseCode == 22) {
                string memory template = vm.replace(vm.trim(vm.readFile("./src/HIP719.bytecode.json")), "\"", "");
                string memory placeholder = "fefefefefefefefefefefefefefefefefefefefe";
                string memory addressString = vm.replace(vm.toString(tokenAddress), "0x", "");
                string memory proxyBytecode = vm.replace(template, placeholder, addressString);
                vm.etch(tokenAddress, vm.parseBytes(proxyBytecode));
            }
        }
    }

    function _getBashScript() private view returns (string memory) {
        address sender = msg.sender;
        bytes memory data = msg.data;
        if (_isViewCall()) {
            string memory rpcPayload = string(abi.encodePacked(
                "{",
                '"jsonrpc":"2.0",',
                '"method":"eth_call",',
                '"params":[{"to":"', vm.toString(address(0x167)), '","data":"', vm.toString(data), '"},"latest"],',
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
            vm.toString(address(this))
        );
    }

    function _isViewCall() private pure returns (bool) {
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
