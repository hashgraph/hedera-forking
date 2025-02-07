// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@hashgraph/system-contracts-forking/contracts/IERC20.sol";
import {IHederaTokenService} from "@hashgraph/system-contracts-forking/contracts/IHederaTokenService.sol";
import {HederaResponseCodes} from "@hashgraph/system-contracts-forking/contracts/HederaResponseCodes.sol";
import {console} from "hardhat/console.sol";

contract CallToken {

    event GetTokenInfo(string name, string symbol, string memo);

    function getTokenName(address tokenAddress) external view returns (string memory) {
        return IERC20(tokenAddress).name();
    }

    function invokeTransferFrom(address tokenAddress, address to, uint256 amount) external {
        // You can use `console.log` as usual
        // https://hardhat.org/tutorial/debugging-with-hardhat-network#solidity--console.log
        console.log("Transferring from %s to %s %s tokens", msg.sender, to, amount);
        IERC20(tokenAddress).transferFrom(msg.sender, to, amount);
    }

    function invokeHTSDirectly(address tokenAddress) external {
        (int64 responseCode, IHederaTokenService.TokenInfo memory tokenInfo) = IHederaTokenService(address(0x167)).getTokenInfo(tokenAddress);
        require(responseCode == HederaResponseCodes.SUCCESS, "HTS call failed");
        console.log("getTokenInfo: %s (%s) memo: %s ", tokenInfo.token.name, tokenInfo.token.symbol, tokenInfo.token.memo);
        emit GetTokenInfo(tokenInfo.token.name, tokenInfo.token.symbol, tokenInfo.token.memo);
    }
}
