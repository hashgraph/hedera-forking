// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "./lib/TestSetup.sol";
import {HTS_ADDRESS} from "../contracts/HtsSystemContract.sol";
import {IHederaTokenService} from "../contracts/IHederaTokenService.sol";
import {HederaResponseCodes} from "../contracts/HederaResponseCodes.sol";
import {IERC20} from "../contracts/IERC20.sol";

contract CreateTokenTest is Test, TestSetup {

    address private unknownUser;

    function setUp() external {
        setUpMockStorageForNonFork();

        unknownUser = makeAddr("unknown-user");
    }

    function test_createFungibleToken_should_revert_if_name_is_not_provided() external {
        IHederaTokenService.HederaToken memory token;
        vm.expectRevert(bytes("HTS: name cannot be empty"));
        IHederaTokenService(HTS_ADDRESS).createFungibleToken(token, 10000, 4);
    }

    function test_createFungibleToken_should_revert_if_symbol_is_not_provided() external {
        IHederaTokenService.HederaToken memory token;
        token.name = "Token name";
        vm.expectRevert(bytes("HTS: symbol cannot be empty"));
        IHederaTokenService(HTS_ADDRESS).createFungibleToken(token, 10000, 4);
    }

    function test_createFungibleToken_should_revert_if_treasury_is_not_provided() external {
        IHederaTokenService.HederaToken memory token;
        token.name = "Token name";
        token.symbol = "Token symbol";
        vm.expectRevert(bytes("HTS: treasury cannot be zero-address"));
        IHederaTokenService(HTS_ADDRESS).createFungibleToken(token, 10000, 4);
    }

    function test_createFungibleToken_should_revert_if_initialTotalSupply_is_negative() external {
        IHederaTokenService.HederaToken memory token;
        token.name = "Token name";
        token.symbol = "Token symbol";
        token.treasury = makeAddr("Token treasury");
        vm.expectRevert(bytes("HTS: initialTotalSupply cannot be negative"));
        IHederaTokenService(HTS_ADDRESS).createFungibleToken(token, -1, 4);
    }

    function test_createFungibleToken_should_revert_if_decimals_is_negative() external {
        IHederaTokenService.HederaToken memory token;
        token.name = "Token name";
        token.symbol = "Token symbol";
        token.treasury = makeAddr("Token treasury");
        vm.expectRevert(bytes("HTS: decimals cannot be negative"));
        IHederaTokenService(HTS_ADDRESS).createFungibleToken(token, 10000, -1);
    }

    function test_createFungibleToken() external {
        IHederaTokenService.HederaToken memory token;
        token.name = "Token name";
        token.symbol = "Token symbol";
        token.treasury = makeAddr("Token treasury");

        (int64 responseCode, address tokenAddress) = IHederaTokenService(HTS_ADDRESS).createFungibleToken(token, 10000, 4);
        vm.assertEq(responseCode, HederaResponseCodes.SUCCESS);
        vm.assertNotEq(tokenAddress, address(0));

        IHederaTokenService.FungibleTokenInfo memory fungibleTokenInfo;
        (responseCode, fungibleTokenInfo) = IHederaTokenService(HTS_ADDRESS).getFungibleTokenInfo(tokenAddress);
        vm.assertEq(responseCode, HederaResponseCodes.SUCCESS);

        vm.assertEq(fungibleTokenInfo.decimals, 4);

        IHederaTokenService.TokenInfo memory tokenInfo = fungibleTokenInfo.tokenInfo;

        vm.assertEq(tokenInfo.token.name, token.name);
        vm.assertEq(tokenInfo.token.symbol, token.symbol);
        vm.assertEq(tokenInfo.totalSupply, 10000);
        vm.assertEq(tokenInfo.fixedFees.length, 0);
        vm.assertEq(tokenInfo.fractionalFees.length, 0);
        vm.assertEq(tokenInfo.royaltyFees.length, 0);

        vm.assertEq(tokenInfo.ledgerId, "0x03");

        // Created token should be accessible through Proxy contract redirect calls
        vm.assertEq(IERC20(tokenAddress).name(), token.name);
        vm.assertEq(IERC20(tokenAddress).symbol(), token.symbol);
        vm.assertEq(IERC20(tokenAddress).decimals(), 4);
    }
}
