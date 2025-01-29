// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {htsSetup} from "hedera-forking/contracts/htsSetup.sol";
import {IERC721} from "hedera-forking/contracts/IERC721.sol";

contract NFTConsoleExampleTest is Test {
    function setUp() external {
        htsSetup();
    }

    function test_using_console_log() view external {
        // https://hashscan.io/mainnet/token/0.0.5083205
        address NFT_mainnet = 0x00000000000000000000000000000000004d9045;

        string memory name = IERC721(NFT_mainnet).name();
        string memory symbol = IERC721(NFT_mainnet).symbol();
        string memory tokenURI = IERC721(NFT_mainnet).tokenURI(1);
        assertEq(name, "THE BARKANEERS");
        assertEq(symbol, "BARKANEERS");
        assertEq(tokenURI, "ipfs://bafkreif4hpsgflzzvd7c4abx5u5xwrrjl7wkimbjtndvkxodklxdam5upm");
        console.log("name: %s, symbol: %s, tokenURI: %s", name, symbol, tokenURI);
    }
}
