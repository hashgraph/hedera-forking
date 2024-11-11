// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IMirrorNode} from "../../src/IMirrorNode.sol";

contract MirrorNodeMock is IMirrorNode {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    mapping (address => string) private _symbolOf;

    function deployHIP719Proxy(address token, string memory symbol) external {
        string memory template = vm.replace(vm.trim(vm.readFile("./@hts-forking/src/HIP719.bytecode.json")), "\"", "");
        string memory placeholder = "fefefefefefefefefefefefefefefefefefefefe";
        string memory addressString = vm.replace(vm.toString(token), "0x", "");
        string memory proxyBytecode = vm.replace(template, placeholder, addressString);
        vm.etch(token, vm.parseBytes(proxyBytecode));

        _symbolOf[token] = symbol;
    }

    function getTokenData(address token) external view returns (string memory) {
        string memory symbol = _symbolOf[token];
        string memory path = string.concat("./@hts-forking/test/data/", symbol, "/getToken.json");
        return vm.readFile(path);
    }

    function getBalance(address token, address account) external returns (string memory) {
        string memory symbol = _symbolOf[token];
        string memory accountId = vm.toString(_getAccountId(account));
        string memory path = string.concat("./@hts-forking/test/data/", symbol, "/getBalanceOfToken_0.0.", accountId, ".json");
        return vm.readFile(path);
    }

    function getAllowance(address token, address owner, address spender) external returns (string memory) {
        string memory symbol = _symbolOf[token];
        string memory ownerId = vm.toString(_getAccountId(owner));
        string memory spenderId = vm.toString(_getAccountId(spender));
        string memory path = string.concat("./@hts-forking/test/data/", symbol, "/getAllowanceForToken_0.0.", ownerId, "_0.0.", spenderId, ".json");
        return vm.readFile(path);
    }

    function _getAccountId(address account) private returns (uint32) {
        string memory path = string.concat("./@hts-forking/test/data/getAccount_", vm.toLowercase(vm.toString(account)), ".json");
        uint256 accountId;
        if (vm.isFile(path)) {
            string memory json = vm.readFile(path);
            accountId = vm.parseUint(vm.replace(abi.decode(vm.parseJson(json, ".account"), (string)), "0.0.", ""));
        } else {
            accountId = uint160(account);
        }
        return uint32(accountId);
        // assignEvmAccountAddress(account, accountId);
    }

    // function assignEvmAccountAddress(address account, uint256 accountId) public {
    //     stdstore
    //         .target(HTS)
    //         .sig(HtsSystemContract.getAccountId.selector)
    //         .with_key(account)
    //         .checked_write(accountId);
    // }
}
