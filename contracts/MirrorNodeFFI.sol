// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {Surl} from "surl/src/Surl.sol";
import {MirrorNode} from "./MirrorNode.sol";
import {HtsSystemContract, HTS_ADDRESS} from "./HtsSystemContract.sol";
import {storeString} from "./StrStore.sol";

/**
 * Fetches Token data from the Mirror Node through Foundry's FFI.
 *
 * For the endpoints that support it, fetches data honoring the current `block.number`.
 * The `block.number` can be specified either in the CLI with the
 * `--fork-block-number <block-number>` CLI option or using
 * Foundry's `vm.(create/select|createSelect|roll)Fork` methods.
 * But it is always a valid block in the forked network.
 */
contract MirrorNodeFFI is MirrorNode {

    /**
     * @dev Cache of responses by `endpoint`.
     * See `_get` method for details.
     */
    mapping (string endpoint => string response) private _responses;

    function fetchTokenData(address token) isValid(token) external override returns (string memory) {
        return _get(string.concat(
            "tokens/0.0.",
            vm.toString(uint160(token))
        ));
    }

    function fetchBalance(address token, uint32 accountNum) isValid(token) external override returns (string memory) {
        return _get(string.concat(
            "tokens/0.0.",
            vm.toString(uint160(token)),
            "/balances?account.id=0.0.",
            vm.toString(accountNum),
            _getBlockQueryParam()
        ));
    }

    function fetchAllowance(address token, uint32 ownerNum, uint32 spenderNum) isValid(token) external override returns (string memory) {
        return _get(string.concat(
            "accounts/0.0.",
            vm.toString(ownerNum),
            "/allowances/tokens?token.id=0.0.",
            vm.toString(uint160(token)),
            "&spender.id=0.0.",
            vm.toString(spenderNum)
        ));
    }

    function fetchAccount(string memory idOrAliasOrEvmAddress) external override returns (string memory) {
        return _get(string.concat(
            "accounts/",
            idOrAliasOrEvmAddress,
            "?transactions=false"
        ));
    }

    function fetchTokenRelationshipOfAccount(string memory idOrAliasOrEvmAddress, address token) external override returns (string memory) {
        return _get(string.concat(
            "accounts/",
            idOrAliasOrEvmAddress,
            "/tokens?token.id=0.0.",
            vm.toString(uint160(token))
        ));
    }

    /**
     * @dev Returns the block information by given number.
     *
     * Uses Mirror Node `/api/v1/blocks/` endpoint.
     */
    function fetchBlock(uint256 blockNumber) external returns (string memory) {
        return _get(string.concat(
            "blocks/",
            vm.toString(blockNumber)
        ));
    }

    /**
     * @dev Returns the timestamp query filter according to the current `block.number`.
     */
    function _getBlockQueryParam() private returns (string memory) {
        string memory json = this.fetchBlock(block.number);
        string memory timestamp = vm.parseJsonString(json, ".timestamp.to");
        return string.concat("&timestamp=", timestamp);
    }

    /**
     * @dev Sends the request specified by `endpoint` to the currently selected Mirror Node.
     *
     * This method caches a successful (`200`) or not found (`404`) response in its own storage.
     * This is specially helpful when requesting block information.
     */
    function _get(string memory endpoint) private returns (string memory json) {
        json = _responses[endpoint];
        if (bytes(json).length == 0) {
            (uint256 status, bytes memory result) = Surl.get(string.concat(_mirrorNodeUrl(), endpoint));
            json = string(result);
            require(status == 200 || status == 404, json);

            // `_responses[endpoint] = json;`
            // To avoid `EvmError: StateChangeDuringStaticCall`
            uint256 slot;
            assembly { slot := _responses.slot }
            storeString(address(this), uint256(keccak256(abi.encodePacked(endpoint, slot))), json);
        }
    }

    /**
     * @dev Returns the currently selected Mirror Node base URL.
     */
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