// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {Surl} from "surl/src/Surl.sol";
import {IMirrorNode} from "./IMirrorNode.sol";
import {HtsSystemContract, HTS_ADDRESS} from "./HtsSystemContract.sol";

contract MirrorNodeFFI is IMirrorNode {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getTokenData(address token) external returns (string memory) {
        require((uint160(token) >> 32) == 0, "Invalid token address");
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "tokens/0.0.",
            vm.toString(uint160(token))
        ));
        require(status == 200, "Status not OK");
        return string(json);
    }

    function getBalance(address token, address account) external returns (string memory) {
        require((uint160(token) >> 32) == 0, "Invalid token address");
        uint32 accountId = _getAccountIdCached(account);
        require(accountId != 0, "Account not found");
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "tokens/0.0.",
            vm.toString(uint160(token)),
            "/balances?account.id=0.0.",
            vm.toString(accountId)
        ));
        require(status == 200, "Status not OK");
        return string(json);
    }

    function getAllowance(address token, address owner, address spender) external returns (string memory) {
        require((uint160(token) >> 32) == 0, "Invalid token address");
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "accounts/0.0.",
            vm.toString(_getAccountIdCached(owner)),
            "/allowances/tokens?token.id=0.0.",
            vm.toString(uint160(token)),
            "&spender.id=0.0.",
            vm.toString(_getAccountIdCached(spender))
        ));
        require(status == 200);
        return string(json);
    }

    // Lets store the response somewhere in order to prevent multiple calls for the same account id
    function _getAccountIdCached(address account) private returns (uint32) {
        uint32 selector = uint32(HtsSystemContract.getAccountId.selector);
        uint64 pad = 0x0;
        bytes32 cachedValueSlot = bytes32(abi.encodePacked(selector + 1, pad, account));
        bytes32 cacheStatusSlot = bytes32(abi.encodePacked(selector + 2, pad, account));
        if (uint256(vm.load(HTS_ADDRESS, cacheStatusSlot)) != 0) {
            return uint32(uint256(vm.load(HTS_ADDRESS, cachedValueSlot)));
        }
        uint32 accountId = _getAccountId(account);
        vm.store(HTS_ADDRESS, bytes32(cachedValueSlot), bytes32(uint256(accountId)));
        vm.store(HTS_ADDRESS, bytes32(cacheStatusSlot), bytes32(uint256(1)));
        return accountId;
    }

    function _getAccountId(address account) private returns (uint32) {
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "accounts/",
            vm.toString(account)
        ));
        if (status != 200) {
            return 0;
        }

        return uint32(vm.parseUint(vm.replace(vm.parseJsonString(string(json), ".account"), "0.0.", "")));
    }

    function _mirrorNodeUrl() private view returns (string memory) {
        if (block.chainid == 295) {
            return "https://mainnet-public.mirrornode.hedera.com/api/v1/";
        }
        if (block.chainid == 296) {
            return "https://testnet.mirrornode.hedera.com/api/v1/";
        }
        if (block.chainid == 297) {
            return "https://previewnet.mirrornode.hedera.com/api/v1/";
        }

        revert("The provided chain ID is not supported by the Hedera Mirror Node library. Please use one of the supported chain IDs: 295, 296, or 297.");
    }
}
