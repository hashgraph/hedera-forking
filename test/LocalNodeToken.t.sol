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
    address _tokenAddress;
    address HTS_ADDRESS = 0x0000000000000000000000000000000000000167;
    function setUp() external {
        deployCodeTo("HtsSystemContractLocalNode.sol", address(HTS_ADDRESS));
        vm.allowCheatcodes(address(HTS_ADDRESS));
        address treasury = 0x0000000000000000000000000000000000000167;
        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](0);
        IHederaTokenService.Expiry memory expiry = IHederaTokenService.Expiry(
            0, treasury, int64(31536000)
        );
        IHederaTokenService.HederaToken memory token = IHederaTokenService.HederaToken(
            "Sample Token",
            "STKN",
            treasury,
            "Sample memo for token",
            true,
            int64(20000000000),
            false,
            keys,
            expiry
        );
        (int responseCode, address tokenAddress) =
            IHederaTokenService(address(0x167)).createFungibleToken(
                token,
                int64(1000000),
                int32(0)
            );

        _tokenAddress = tokenAddress;
        assertEq(responseCode, 22);
    }

    function test_ERC20_name() external {
        assertEq(IERC20(_tokenAddress).name(), "Sample Token");
    }

    function test_ERC20_decimals() external {
        assertEq(IERC20(_tokenAddress).decimals(), uint256(2));
    }
}
