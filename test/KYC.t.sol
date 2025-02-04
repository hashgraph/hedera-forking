// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {TestSetup} from "./lib/TestSetup.sol";
import {HTS_ADDRESS} from "../contracts/HtsSystemContract.sol";
import {IHederaTokenService} from "../contracts/IHederaTokenService.sol";
import {HederaResponseCodes} from "../contracts/HederaResponseCodes.sol";
import {IERC20} from "../contracts/IERC20.sol";
import {IERC721} from "../contracts/IERC721.sol";

contract KYCTest is Test, TestSetup {

    address private _tokenAddress;
    address private owner;

    function setUp() external {
        setUpMockStorageForNonFork();

        if (testMode == TestMode.JSON_RPC) vm.skip(true);

        IHederaTokenService.HederaToken memory token;
        token.name = "Token name";
        token.symbol = "Token symbol";
        token.treasury = makeAddr("Token treasury");
        token.tokenKeys = new IHederaTokenService.TokenKey[](1);
        owner = makeAddr("kyc");

        token.tokenKeys[0].key.contractId = owner;

        token.tokenKeys[0].keyType = 0x2;
        (, _tokenAddress) = IHederaTokenService(HTS_ADDRESS).createFungibleToken{value: 1000}(token, 1000000, 4);
        vm.assertNotEq(_tokenAddress, address(0));
    }

    function test_HTS_transferTokens_success_with_kyc() public {
        address[] memory to = new address[](1);
        to[0] = makeAddr("bob");
        uint256 amount = 4_000000;
        int64[] memory amounts = new int64[](1);
        amounts[0] = int64(int256(amount));

        uint256 balanceOfOwner = IERC20(_tokenAddress).balanceOf(owner);
        assertGt(balanceOfOwner, 0);
        assertEq(IERC20(_tokenAddress).balanceOf(to[0]), 0);

        vm.startPrank(owner);
        require (1 == 2, vm.toString( owner));
        IHederaTokenService(HTS_ADDRESS).transferTokens(_tokenAddress, to, amounts);

        assertEq(IERC20(_tokenAddress).balanceOf(owner), balanceOfOwner - amount);
        assertEq(IERC20(_tokenAddress).balanceOf(to[0]), amount);
        vm.stopPrank();
    }
}
