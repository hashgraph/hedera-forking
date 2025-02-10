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

    address private token;
    address private owner;
    address private to;
    uint256 private amount = 4_000000;

    function setUp() external {
        setUpMockStorageForNonFork();

        if (testMode == TestMode.JSON_RPC) vm.skip(true);

        IHederaTokenService.HederaToken memory hederaToken;
        hederaToken.name = "Token name";
        hederaToken.symbol = "Token symbol";
        hederaToken.treasury = makeAddr("Token treasury");
        hederaToken.tokenKeys = new IHederaTokenService.TokenKey[](1);
        owner = makeAddr("kyc");

        hederaToken.tokenKeys[0].key.contractId = owner;

        hederaToken.tokenKeys[0].keyType = 0x2;
        (, token) = IHederaTokenService(HTS_ADDRESS).createFungibleToken{value: 1000}(hederaToken, 1000000, 4);
        vm.assertNotEq(token, address(0));
        to = makeAddr("bob");
    }

    function test_HTS_transferToken_success_with_kyc() public {
        deal(token, owner, amount);
        uint256 balanceOfOwner = IERC20(token).balanceOf(owner);
        vm.prank(owner);
        IHederaTokenService(HTS_ADDRESS).transferToken(token, owner, to, int64(int256(amount)));
        assertEq(IERC20(token).balanceOf(owner), balanceOfOwner - amount);
        assertEq(IERC20(token).balanceOf(to), amount);
    }

    function test_ERC20_transferToken_success_with_kyc() public {
        deal(token, owner, amount);
        uint256 balanceOfOwner = IERC20(token).balanceOf(owner);
        vm.prank(owner);
        IERC20(token).transfer(to, amount);
        assertEq(IERC20(token).balanceOf(owner), balanceOfOwner - amount);
        assertEq(IERC20(token).balanceOf(to), amount);
    }

    function test_HTS_transferToken_failure_without_kyc() public {
        address from = makeAddr("from");
        deal(token, from, amount);
        vm.prank(from);
        vm.expectRevert("kyc: no kyc granted");
        IHederaTokenService(HTS_ADDRESS).transferToken(token, from, to, int64(int256(amount)));
    }

    function test_ERC20_transferToken_failure_without_kyc() public {
        address from = makeAddr("from");
        deal(token, from, amount);
        vm.prank(from);
        vm.expectRevert("__redirectForToken: no kyc granted");
        IERC20(token).transfer(to, amount);
    }

    function test_HTS_transferToken_success_with_kyc_granted() public {
        address from = makeAddr("from");
        deal(token, from, amount);
        uint256 balanceOfFrom = IERC20(token).balanceOf(from);
        vm.prank(owner);

        IHederaTokenService(HTS_ADDRESS).grantTokenKyc(token, from);
        vm.prank(from);
        IHederaTokenService(HTS_ADDRESS).transferToken(token, from, to, int64(int256(amount)));


        assertEq(IERC20(token).balanceOf(from), balanceOfFrom - amount);
        assertEq(IERC20(token).balanceOf(to), amount);
    }
}
