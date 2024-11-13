// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import "surl/src/Surl.sol";

library MirrorNodeLib {
    using Surl for *;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getTokenData() internal returns (string memory) {
        (uint256 status, bytes memory data) = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "tokens/0.0.",
            vm.toString(uint160(address(this)))
        )).get();
        require(status == 200, "Failed to get token data from the Hedera MirrorNode");
        return string(data);
    }

    function getAllowance(address owner, address spender) internal returns (uint256) {
        string memory allowancesUrl = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "accounts/0.0.",
            vm.toString(getAccountIdCached(owner)),
            "/allowances/tokens?token.id=0.0.",
            vm.toString(uint160(address(this))),
            "&spender.id=0.0.",
            vm.toString(getAccountIdCached(spender))
        ));

        (uint256 allowancesStatusCode, bytes memory allowancesJson) = allowancesUrl.get();
        if (allowancesStatusCode == 200 && vm.keyExistsJson(string(allowancesJson), ".allowances[0].amount")) {
            return abi.decode(vm.parseJson(string(allowancesJson), ".allowances[0].amount"), (uint256));
        }
        return 0;
    }

    function getAccountBalance(address account) internal returns (uint256) {
        uint32 accountId = getAccountIdCached(account);
        if (accountId == 0) {
            return 0;
        }
        string memory balancesUrl = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "tokens/0.0.",
            vm.toString(uint160(address(this))),
            "/balances?account.id=0.0.",
            vm.toString(accountId)
        ));
        (uint256 balancesStatusCode, bytes memory balancesJson) = balancesUrl.get();
        if (balancesStatusCode != 200) {
            return 0;
        }
        if (vm.keyExistsJson(string(balancesJson), ".balances[0].balance")) {
            return abi.decode(vm.parseJson(string(balancesJson), ".balances[0].balance"), (uint256));
        }

        return 0;
    }
    // Lets store the response somewhere in order to prevent multiple calls for the same account id
    function getAccountIdCached(address account) internal returns (uint32) {
        address target = address(0x167);
        uint64 pad = 0x0;
        bytes32 cachedValueSlot = bytes32(abi.encodePacked(bytes4(0xe0b490f8), pad, account));
        bytes32 cacheStatusSlot = bytes32(abi.encodePacked(bytes4(0xe0b490f9), pad, account));
        if (uint256(vm.load(target, cacheStatusSlot)) != 0) {
            return uint32(uint256(vm.load(target, cachedValueSlot)));
        }
        uint32 accountId = getAccountId(account);
        vm.store(target, bytes32(cachedValueSlot), bytes32(uint256(accountId)));
        vm.store(target, bytes32(cacheStatusSlot), bytes32(uint256(1)));
        return accountId;
    }

    function getAccountId(address account) internal returns (uint32) {
        string memory accountUrl = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "accounts/",
            vm.toLowercase(vm.toString(account))
        ));
        (uint256 accountStatusCode, bytes memory accountJson) = accountUrl.get();
        if (accountStatusCode != 200) {
            return 0;
        }

        return uint32(vm.parseUint(
            vm.replace(abi.decode(vm.parseJson(string(accountJson), ".account"), (string)), "0.0.", ""))
        );
    }

    function getAccountAddress(string memory accountId) internal returns (address) {
        if (bytes(accountId).length == 0) {
            return address(0);
        }

        string memory accountUrl = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "accounts/",
            accountId
        ));
        (uint256 accountStatusCode, bytes memory accountJson) = accountUrl.get();
        if (accountStatusCode != 200) {
            return address(0);
        }

        return abi.decode(vm.parseJson(string(accountJson), ".evm_address"), (address));
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
