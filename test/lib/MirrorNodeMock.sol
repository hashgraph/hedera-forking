// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {MirrorNode} from "../../src/MirrorNode.sol";

contract MirrorNodeMock is MirrorNode {

    mapping (address => string) private _symbolOf;

    function deployHIP719Proxy(address token, string memory symbol) external {
        string memory template = vm.replace(vm.trim(vm.readFile("./@hts-forking/src/HIP719.bytecode.json")), "\"", "");
        string memory placeholder = "fefefefefefefefefefefefefefefefefefefefe";
        string memory addressString = vm.replace(vm.toString(token), "0x", "");
        string memory proxyBytecode = vm.replace(template, placeholder, addressString);
        vm.etch(token, vm.parseBytes(proxyBytecode));

        _symbolOf[token] = symbol;
    }

    function fetchTokenData(address token) isValid(token) external override view returns (string memory) {
        string memory symbol = _symbolOf[token];
        string memory path = string.concat("./@hts-forking/test/data/", symbol, "/getToken.json");
        return vm.readFile(path);
    }

    function fetchBalance(address token, uint32 accountNum) isValid(token) external override view returns (string memory) {
        string memory symbol = _symbolOf[token];
        string memory accountId = vm.toString(accountNum);
        string memory path = string.concat("./@hts-forking/test/data/", symbol, "/getBalanceOfToken_0.0.", accountId, ".json");
        return vm.readFile(path);
    }

    function fetchAllowance(address token, uint32 ownerNum, uint32 spenderNum) isValid(token) external override view returns (string memory) {
        string memory symbol = _symbolOf[token];
        string memory ownerId = vm.toString(ownerNum);
        string memory spenderId = vm.toString(spenderNum);
        string memory path = string.concat("./@hts-forking/test/data/", symbol, "/getAllowanceForToken_0.0.", ownerId, "_0.0.", spenderId, ".json");
        return vm.readFile(path);
    }

    function fetchAccount(string memory account) external override view returns (string memory) {
        string memory path = string.concat("./@hts-forking/test/data/getAccount_", vm.toLowercase(account), ".json");
        return vm.readFile(path);
    }

    function fetchTokenRelationshipOfAccount(string memory idOrAliasOrEvmAddress, address token) external override view returns (string memory) {
        string memory symbol = _symbolOf[token];
        string memory path = string.concat("./@hts-forking/test/data/", symbol, "/getTokenRelationship_", vm.toLowercase(idOrAliasOrEvmAddress), ".json");
        return vm.readFile(path);
    }
}
