
// SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.17;

import {Test, Vm, console} from "forge-std/Test.sol";
import {IERC721} from "../src/IERC721.sol";

contract NFTTest is Test {
    address NFT = 0x0000000000000000000000000000000000486102;

    function setUp() external view {
        console.log("HTS code has %d bytes", address(0x167).code.length);
    }

    function test_ERC721_name() view external {
        assertEq(IERC721(NFT).name(), "Hedera NFT");
    }

    function test_ERC721_symbol() view external {
        assertEq(IERC721(NFT).symbol(), "HNFT");
    }

    function test_ERC721_ownerOf() view external {
        uint256 tokenId = 1;
        address expectedOwner = 0x292c4acf9ec49aF888D4051Eb4A4dc53694D1380;

        assertEq(IERC721(NFT).ownerOf(tokenId), expectedOwner);
    }

    function test_ERC721_balanceOf() view external {
        address owner = 0x292c4acf9ec49aF888D4051Eb4A4dc53694D1380;
        uint256 expectedBalance = 1;

        assertEq(IERC721(NFT).balanceOf(owner), expectedBalance);
    }

    function test_ERC721_transfer() external {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        uint256 tokenId = 1;
        assertEq(IERC721(NFT).balanceOf(bob), 0);
        vm.startPrank(alice);
        IERC721(NFT).transferFrom(alice, bob, tokenId);
        vm.stopPrank();
        assertEq(IERC721(NFT).ownerOf(tokenId), bob);
        assertEq(IERC721(NFT).balanceOf(bob), 1);
        assertEq(IERC721(NFT).balanceOf(alice), 0);
    }
}
