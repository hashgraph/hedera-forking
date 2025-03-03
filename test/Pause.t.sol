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

contract PauseTest is Test, TestSetup {

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
        hederaToken.tokenKeys[0].keyType = 0x40;
        hederaToken.tokenKeys[0].key.ed25519 = hex"5db29fb3f19f8618cc4689cf13e78a935621845d67547719faf49f65d5c367cc";
        (, token) = IHederaTokenService(HTS_ADDRESS).createFungibleToken{value: 1000}(hederaToken, 1000000, 4);
        vm.assertNotEq(token, address(0));
        to = makeAddr("bob");
    }

    function test_HTS_transferToken_success_when_not_paused() public {
        deal(token, owner, amount);
        uint256 balanceOfOwner = IERC20(token).balanceOf(owner);
        vm.prank(owner);
        IHederaTokenService(HTS_ADDRESS).transferToken(token, owner, to, int64(int256(amount)));
        assertEq(IERC20(token).balanceOf(owner), balanceOfOwner - amount);
        assertEq(IERC20(token).balanceOf(to), amount);
    }

    function test_HTS_pausing_success_with_correct_key() public {
        vm.prank(owner);
        int64 code = IHederaTokenService(HTS_ADDRESS).pauseToken(token);
        assertEq(code, HederaResponseCodes.SUCCESS);
    }

    function test_HTS_transferToken_failure_when_paused() public {
        deal(token, owner, amount);
        vm.startPrank(owner);
        IHederaTokenService(HTS_ADDRESS).pauseToken(token);
        (int64 code) = IHederaTokenService(HTS_ADDRESS).transferToken(token, owner, to, int64(int256(amount)));
        assertEq(code, HederaResponseCodes.TOKEN_IS_PAUSED);
    }
}
