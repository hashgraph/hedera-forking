// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import "surl/Surl.sol";

library MirrorNodeLib {
    using Surl for *;

    bytes private constant MAINNET_MIRROR_NODE_URL = "https://mainnet-public.mirrornode.hedera.com/api/v1/";
    bytes private constant TESTNET_MIRROR_NODE_URL = "https://testnet.mirrornode.hedera.com/api/v1/";
    bytes private constant PREVIEWNET_MIRROR_NODE_URL = "https://previewnet.mirrornode.hedera.com/api/v1/";

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getTokenStringDataFromMirrorNode(string memory field) internal returns (string memory) {
        (uint256 status, bytes memory data) = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "tokens/0.0.",
            vm.toString(uint160(address(this)))
        )).get();
        require(status == 200, "Failed to get token data from the Hedera MirrorNode");
        string memory json = string(data);
        return abi.decode(vm.parseJson(json, string(abi.encodePacked(".", field))), (string));
    }

    function getAllowanceFromMirrorNode(address ownerId, address spenderId) internal returns (uint256) {
        string memory allowancesUrl = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "accounts/0.0.",
            vm.toString(ownerId),
            "/allowances/tokens?token.id=0.0.",
            vm.toString(uint160(address(this))),
            "&spender.id=0.0.",
            vm.toString(spenderId)
        ));

        (uint256 allowancesStatusCode, bytes memory allowancesJson) = allowancesUrl.get();
        if (allowancesStatusCode == 200 && vm.keyExistsJson(string(allowancesJson), ".allowances[0].amount")) {
            return abi.decode(vm.parseJson(string(allowancesJson), ".allowances[0].amount"), (uint256));
        }
        return 0;
    }

    function getAccountBalanceFromMirrorNode(address account) internal returns (uint256) {
        uint32 accountId = getAccountIdFromMirrorNode(account);
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

    function getAccountIdFromMirrorNode(address account) internal returns (uint32) {
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

    function _mirrorNodeUrl() private view returns (string memory) {
        if (block.chainid == 295) {
            return string(MAINNET_MIRROR_NODE_URL);
        }
        if (block.chainid == 296) {
            return string(TESTNET_MIRROR_NODE_URL);
        }
        if (block.chainid == 297) {
            return string(PREVIEWNET_MIRROR_NODE_URL);
        }

        revert("The provided chain ID is not supported by the Hedera Mirror Node library. Please use one of the supported chain IDs: 295, 296, or 297.");
    }
}
