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
        deployCodeTo("HtsSystemContractLocalNode.sol", HTS_ADDRESS);
        vm.allowCheatcodes(HTS_ADDRESS);

        (int responseCode, address tokenAddress) =
            IHederaTokenService(HTS_ADDRESS).createFungibleToken(
                tokenData("Some really really long name, just for testing purposes to prove it is not an issue", "SAMPLE"),
                int64(1000),
                int32(2)
            );

        _tokenAddress = tokenAddress;
        assertEq(responseCode, 22);
    }

    function test_ERC20_name() external view {
        assertEq(IERC20(_tokenAddress).name(), "Some really really long name, just for testing purposes to prove it is not an issue");
    }

    function test_ERC20_decimals() external view {
        assertEq(IERC20(_tokenAddress).decimals(), uint256(2));
    }

    function test_ERC20_symbol() external view {
        assertEq(IERC20(_tokenAddress).symbol(), "SAMPLE");
    }

    function test_ERC20_balanceOf() external view {
        assertEq(IERC20(_tokenAddress).balanceOf(address(0x167)), 0);
    }

    /**
     * Run the test below by:
     * 1. Allowing the operator to spend tokens from the sender's account, OR
     * 2. Turning off the allowance checks in the Hedera Token Service (HTS)
     *    - find file:
     *       hedera-node/hedera-token-service-impl/src/main/java/com/hedera/node/app/service/token/impl/validators/AllowanceValidator.java
     *    - remove the body of the function validateAllowanceLimit . Its return type is void, you can simply leave it empty.
     */

    /**
     * function test_ERC20_transfer() external {
     *   IERC20(_tokenAddress).transferFrom(address(0x67D8d32E9Bf1a9968a5ff53B87d777Aa8EBBEe69), address(0x17b2B8c63Fa35402088640e426c6709A254c7fFb), 100);
     * }
    */

    function tokenData(string memory name, string memory symbol) private pure returns (IHederaTokenService.HederaToken memory token)
    {
        address treasury = 0x67D8d32E9Bf1a9968a5ff53B87d777Aa8EBBEe69;
        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](1);
        IHederaTokenService.TokenKey memory key = IHederaTokenService.TokenKey(
            uint(1),
            IHederaTokenService.KeyValue(
                false,
                0x0000000000000000000000000000000000000000,
                bytes(""),
                bytes(""),
                0x0000000000000000000000000000000000000000
            )
        );
        keys[0] = key;
        IHederaTokenService.Expiry memory expiry = IHederaTokenService.Expiry(
            int64(1672531200), treasury, int64(31536000)
        );
        return IHederaTokenService.HederaToken(
            name,
            symbol,
            treasury,
            "Sample memo for token",
            true,
            int64(10000000000),
            false,
            keys,
            expiry
        );
    }
}
