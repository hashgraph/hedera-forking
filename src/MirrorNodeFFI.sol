// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {Surl} from "surl/src/Surl.sol";
import {MirrorNode} from "./MirrorNode.sol";
import {HtsSystemContract, HTS_ADDRESS} from "./HtsSystemContract.sol";

contract MirrorNodeFFI is MirrorNode {

    function fetchTokenData(address token) isValid(token) external override returns (string memory) {
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "tokens/0.0.",
            vm.toString(uint160(token))
        ));
        require(status == 200, "Status not OK");
        return string(json);
    }

    function fetchBalance(address token, uint32 accountNum) isValid(token) external override returns (string memory) {
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "tokens/0.0.",
            vm.toString(uint160(token)),
            "/balances?account.id=0.0.",
            vm.toString(accountNum)
        ));
        require(status == 200);
        return string(json);
    }

    function fetchAllowance(address token, uint32 ownerNum, uint32 spenderNum) isValid(token) external override returns (string memory) {
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "accounts/0.0.",
            vm.toString(ownerNum),
            "/allowances/tokens?token.id=0.0.",
            vm.toString(uint160(token)),
            "&spender.id=0.0.",
            vm.toString(spenderNum)
        ));
        require(status == 200);
        return string(json);
    }


    function fetchAccount(address account) external override returns (string memory) {
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "accounts/",
            vm.toString(account)
        ));
        require(status == 200);
        return string(json);
    }

    function fetchAccount(string memory idOrAliasOrEvmAddress) external override returns (string memory) {
        (uint256 status, bytes memory json) = Surl.get(string.concat(
            _mirrorNodeUrl(),
            "accounts/",
            idOrAliasOrEvmAddress
        ));
        require(status == 200);
        return string(json);
    }

    function _mirrorNodeUrl() private view returns (string memory url) {
        if (block.chainid == 295) {
            url = "https://mainnet-public.mirrornode.hedera.com/api/v1/";
        } else if (block.chainid == 296) {
            url = "https://testnet.mirrornode.hedera.com/api/v1/";
        } else if (block.chainid == 297) {
            url = "https://previewnet.mirrornode.hedera.com/api/v1/";
        } else {
            revert("The provided chain ID is not supported by the Hedera Mirror Node library. Please use one of the supported chain IDs: 295, 296, or 297.");
        }
    }
}
