// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IERC20Events, IERC20} from "../src/IERC20.sol";
import {IHederaTokenService} from "../src/IHederaTokenService.sol";
import {TestSetup} from "./lib/TestSetup.sol";

interface MethodNotSupported {
    function methodNotSupported() external view returns (uint256);
}

contract LocalNodeTokenTest is Test, TestSetup, IERC20Events {
    address TOKEN_ADDRESS = 0x0000000000000000000000000000000000000408;
    address HTS_ADDRESS = 0x0000000000000000000000000000000000000167;
    function setUp() external {
        deployCodeTo("HtsSystemContractLocalNode.sol", address(HTS_ADDRESS));
        vm.allowCheatcodes(address(HTS_ADDRESS));
    }

    function test_ERC20_create() external {
        address treasury = address(0x167);
        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](0);
        IHederaTokenService.Expiry memory expiry = IHederaTokenService.Expiry(
            0, treasury, 8000000
        );
        string memory name = "USD Coin";
        string memory symbol = "USD";
        string memory memo = "memo";
        int64 maxSupply = 20000000000;
        bool freezeDefaultStatus = false;
        IHederaTokenService.HederaToken memory token = IHederaTokenService.HederaToken(
            name,
            symbol,
            treasury,
            memo,
            true,
            maxSupply,
            freezeDefaultStatus,
            keys,
            expiry
        );
        int64 initialTotalSupply = 10000000000;
        int32 decimals = 0;
        vm.prank(address(this));
        (int responseCode, address tokenAddress) =
            IHederaTokenService(address(0x167)).createFungibleToken(
            token,
                    initialTotalSupply,
                    decimals
            );
        assertEq(responseCode, 22);

    }

    function test_ERC20_name() external {
        assertEq(IERC20(TOKEN_ADDRESS).name(), "MyToken");
    }

    function test_ERC20_decimals() external {
        assertEq(IERC20(TOKEN_ADDRESS).decimals(), uint256(2));
    }
}
