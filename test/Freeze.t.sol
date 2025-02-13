// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {TestSetup} from "./lib/TestSetup.sol";
import {HtsSystemContract, HTS_ADDRESS} from "../contracts/HtsSystemContract.sol";
import {IHederaTokenService} from "../contracts/IHederaTokenService.sol";
import {HederaResponseCodes} from "../contracts/HederaResponseCodes.sol";
import {IERC20} from "../contracts/IERC20.sol";
import {IERC721} from "../contracts/IERC721.sol";

contract FreezeTest is Test, TestSetup {

    address private token;
    address private owner;
    address private to;
    uint256 private amount = 4_000000;

    function setUp() external {
        setUpMockStorageForNonFork();
        IHederaTokenService.HederaToken memory hederaToken;
        hederaToken.name = "Token name";
        hederaToken.symbol = "Token symbol";
        hederaToken.treasury = makeAddr("Token treasury");
        hederaToken.tokenKeys = new IHederaTokenService.TokenKey[](1);
        owner = makeAddr("pause");
        hederaToken.tokenKeys[0].keyType = 0x4;
        (, token) = IHederaTokenService(HTS_ADDRESS).createFungibleToken{value: 1000}(hederaToken, 1000000, 4);
        vm.assertNotEq(token, address(0));

        vm.mockCall(
            token,
            abi.encodeWithSelector(HtsSystemContract.getKeyOwner.selector, token, 0x4),
            abi.encode(owner)
        );
        to = makeAddr("bob");
    }

    function test_HTS_transferToken_success_when_not_frozen() public {
        address from = makeAddr("from");
        deal(token, from, amount);
        vm.prank(from);
        IHederaTokenService(HTS_ADDRESS).transferToken(token, from, to, int64(int256(amount)));
        assertEq(IERC20(token).balanceOf(to), amount);
    }

    function test_HTS_freezing_success_with_correct_key() public {
        address from = makeAddr("bob");
        vm.startPrank(owner);
        int64 freezeCode = IHederaTokenService(HTS_ADDRESS).freezeToken(token, from);
        assertEq(freezeCode, HederaResponseCodes.SUCCESS);
        int64 unfreezeCode = IHederaTokenService(HTS_ADDRESS).unfreezeToken(token, from);
        assertEq(unfreezeCode, HederaResponseCodes.SUCCESS);
        vm.stopPrank();
    }

    function test_HTS_freezing_failure_with_incorrect_key() public {
        vm.expectRevert("freezeToken: only allowed for freezable tokens");
        vm.prank(makeAddr("bob"));
        IHederaTokenService(HTS_ADDRESS).freezeToken(token, makeAddr("alice"));
    }

    function test_HTS_transferToken_failure_when_paused() public {
        address from = makeAddr("bob");
        deal(token, from, amount);
        vm.prank(owner);
        IHederaTokenService(HTS_ADDRESS).freezeToken(token, from);
        vm.expectRevert("notFrozen: token frozen");
        vm.prank(from);
        IHederaTokenService(HTS_ADDRESS).transferToken(token, from, to, int64(int256(amount)));
    }
}
