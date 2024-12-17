// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {HtsSystemContract, HTS_ADDRESS} from "../contracts/HtsSystemContract.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC721, IERC721Events} from "../contracts/IERC721.sol";
import {IERC20Events} from "../contracts/IERC20.sol";
import {TestSetup} from "./lib/TestSetup.sol";

contract ERC721TokenTest is Test, TestSetup, IERC721Events, IERC20Events {

    function setUp() external {
        setUpMockStorageForNonFork();
    }

    function test_ERC721_name() external view {
        assertEq(IERC721(CFNFTFF).name(), "Custom Fee NFT (Fixed Fee)");
    }

    function test_ERC721_symbol() external view {
        assertEq(IERC721(CFNFTFF).symbol(), "CFNFTFF");
    }

    function test_ERC721_totalSupply() external view {
        assertEq(IERC721(CFNFTFF).totalSupply(), 2);
    }

    function test_ERC721_balanceOf() external view {
        address treasury = CFNFTFF_TREASURY;
        assertEq(IERC721(CFNFTFF).balanceOf(treasury), 2);
    }

    function test_ERC721_ownerOf() external {
        uint256 tokenId = 1;
        uint192 pad = 0x0;
        bytes32 slot = bytes32(abi.encodePacked(IERC721.ownerOf.selector, pad, uint32(tokenId)));
        vm.store(CFNFTFF, slot, bytes32(uint256(uint160(CFNFTFF_TREASURY))));

        assertEq(IERC721(CFNFTFF).ownerOf(tokenId), CFNFTFF_TREASURY);
    }

    function test_ERC721_transferFrom() external {
        address to = makeAddr("recipient");
        uint256 tokenId = 1;
        uint192 pad = 0x0;
        bytes32 slot = bytes32(abi.encodePacked(IERC721.ownerOf.selector, pad, uint32(tokenId)));
        vm.store(CFNFTFF, slot, bytes32(uint256(uint160(CFNFTFF_TREASURY))));

        vm.startPrank(CFNFTFF_TREASURY);
        vm.expectEmit(CFNFTFF);
        emit Transfer(CFNFTFF_TREASURY, to, tokenId);
        IERC721(CFNFTFF).transferFrom(CFNFTFF_TREASURY, to, tokenId);
        vm.stopPrank();

        assertEq(IERC721(CFNFTFF).ownerOf(tokenId), to);
    }

    function test_ERC721_approve() external {
        address spender = makeAddr("spender");
        uint256 tokenId = 1;
        uint192 pad = 0x0;
        bytes32 slot = bytes32(abi.encodePacked(IERC721.ownerOf.selector, pad, uint32(tokenId)));
        vm.store(CFNFTFF, slot, bytes32(uint256(uint160(CFNFTFF_TREASURY))));

        vm.startPrank(CFNFTFF_TREASURY);
        vm.expectEmit(CFNFTFF);
        emit Approval(CFNFTFF_TREASURY, spender, tokenId);
        IERC721(CFNFTFF).approve(spender, tokenId);
        vm.stopPrank();

        assertEq(IERC721(CFNFTFF).getApproved(tokenId), spender);
    }

    function test_ERC721_setApprovalForAll() external {
        address owner = CFNFTFF_TREASURY;
        address operator = makeAddr("operator");

        vm.prank(owner);
        vm.expectEmit(CFNFTFF);
        emit ApprovalForAll(owner, operator, true);
        IERC721(CFNFTFF).setApprovalForAll(operator, true);

        assertTrue(IERC721(CFNFTFF).isApprovedForAll(owner, operator));
    }

    function test_ERC721_getApproved() external {
        address approvedUser = makeAddr("approved user");
        uint256 tokenId = 1;
        uint192 pad = 0x0;
        bytes32 slot = bytes32(abi.encodePacked(IERC721.getApproved.selector, pad, uint32(tokenId)));
        vm.store(CFNFTFF, slot, bytes32(uint256(uint160(approvedUser))));

        assertEq(IERC721(CFNFTFF).getApproved(tokenId), approvedUser);
    }

    function test_ERC721_isApprovedForAll() external {
        address owner = CFNFTFF_TREASURY;
        address operator = makeAddr("operator");
        uint160 pad = 0x0;
        uint32 ownerId = HtsSystemContract(HTS_ADDRESS).getAccountId(owner);
        uint32 operatorId = HtsSystemContract(HTS_ADDRESS).getAccountId(operator);
        bytes32 slot = bytes32(abi.encodePacked(IERC721.isApprovedForAll.selector, pad, ownerId, operatorId));
        vm.store(CFNFTFF, slot, bytes32(uint256(1)));

        assertTrue(IERC721(CFNFTFF).isApprovedForAll(owner, operator));
    }
}
