// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {htsSetup} from "hedera-forking/contracts/htsSetup.sol";
import {IERC721} from "hedera-forking/contracts/IERC721.sol";

contract NFTExampleTest is Test {
    // https://hashscan.io/mainnet/token/0.0.4970613
    address NFT_mainnet = 0x00000000000000000000000000000000004bd875;

    address private user1;

    function setUp() external {
        htsSetup();

        user1 = makeAddr("user1");
        deal(NFT_mainnet, user1, 3);
    }

    function test_get_owner_of_existing_account() view external {
        // Owner of nft 2 is currently nftHolder
        assertNotEq(IERC721(NFT_mainnet).ownerOf(2), address(0));
    }

    function test_dealt_nft_assigned_to_local_account() view external {
        assertEq(IERC721(NFT_mainnet).ownerOf(3), user1);
    }
}