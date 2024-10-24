// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {CommonBase} from "forge-std/Base.sol";
import "surl/Surl.sol";

contract MirrorNodeAware is CommonBase {
    using Surl for *;

    string private constant MAINNET_MIRROR_NODE_URL = "https://mainnet-public.mirrornode.hedera.com/api/v1/";
    string private constant TESTNET_MIRROR_NODE_URL = "https://testnet.mirrornode.hedera.com/api/v1/";
    string private constant PREVIEWNET_MIRROR_NODE_URL = "https://previewnet.mirrornode.hedera.com/api/v1/";

    function _getTokenStringDataFromMirrorNode(string memory field) internal returns (string memory) {
        (uint256 status, bytes memory data) = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "tokens/0.0.",
            vm.toString(uint160(address(this)))
        )).get();
        require(status == 200, "Failed to get token data from the Hedera MirrorNode");
        string memory json = string(data);
        return abi.decode(vm.parseJson(json, string(abi.encodePacked(".", field))), (string));
    }

    function _getAllowanceFromMirrorNode(uint256 ownerId, uint256 spenderId) internal returns (uint256) {
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

    function _getAccountBalanceFromMirrorNode(address account) internal returns (uint256) {
        string memory accountUrl = string(abi.encodePacked(
            _mirrorNodeUrl(),
            "accounts/",
            vm.toLowercase(vm.toString(account))
        ));
        (uint256 accountStatusCode, bytes memory accountJson) = accountUrl.get();
        if (accountStatusCode != 200) {
            return 0;
        }
        uint32 accountId = uint32(vm.parseUint(
            vm.replace(abi.decode(vm.parseJson(string(accountJson), ".account"), (string)), "0.0.", ""))
        );
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

    function _mirrorNodeUrl() private view returns (string memory) {
        if (block.chainid == 295) {
            return MAINNET_MIRROR_NODE_URL;
        }
        if (block.chainid == 296) {
            return TESTNET_MIRROR_NODE_URL;
        }
        if (block.chainid == 297) {
            return PREVIEWNET_MIRROR_NODE_URL;
        }

        return MAINNET_MIRROR_NODE_URL; // For forked network mainnet will be used as default value.
    }
}
