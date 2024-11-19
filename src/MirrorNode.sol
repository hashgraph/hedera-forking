// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IMirrorNodeResponses} from "./IMirrorNodeResponses.sol";

abstract contract MirrorNode is IMirrorNodeResponses {

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /**
     * @dev Requires that `token` address is a valid HTS token address.
     * That is, that is no greater than MAX value of `uint32`.
     * Technically, AccountNum is 64 bits, but here constraint them to 32 bits.
     */
    modifier isValid(address token) {
        require((uint160(token) >> 32) == 0, "Invalid token address");
        _;
    }

    function fetchTokenData(address token) external virtual returns (string memory json);

    function fetchBalance(address token, uint32 accountNum) external virtual returns (string memory json);

    function fetchAllowance(address token, uint32 ownerNum, uint32 spenderNum) external virtual returns (string memory json);

    function fetchAccount(string memory account) external virtual returns (string memory json);

    function getBalance(address token, address account) external returns (uint256) {
        uint32 accountNum = _getAccountNum(account);
        if (accountNum == 0) return 0;

        try this.fetchBalance(token, accountNum) returns (string memory json) {
            if (vm.keyExistsJson(json, ".balances[0].balance")) {
                return vm.parseJsonUint(json, ".balances[0].balance");
            }
        } catch {}
        return 0;
    }

    function getAllowance(address token, address owner, address spender) external returns (uint256) {
        uint32 ownerNum = _getAccountNum(owner);
        if (ownerNum == 0) return 0;
        uint32 spenderNum = _getAccountNum(spender);
        if (spenderNum == 0) return 0;

        try this.fetchAllowance(token, ownerNum, spenderNum) returns (string memory json) {
            if (vm.keyExistsJson(json, ".allowances[0].amount")) {
                return vm.parseJsonUint(json, ".allowances[0].amount");
            }
        } catch {}
        return 0;
    }

    // Lets store the response somewhere in order to prevent multiple calls for the same account id
    function _getAccountNum(address account) private returns (uint32) {
        if ((uint160(account) >> 32) == 0) {
            return uint32(uint160(account));
        }

        try this.fetchAccount(vm.toString(account)) returns (string memory json) {
            if (vm.keyExistsJson(json, ".account")) {
                return uint32(vm.parseUint(vm.replace(vm.parseJsonString(json, ".account"), "0.0.", "")));
            }
        } catch {}

        return 0;
    }
}
