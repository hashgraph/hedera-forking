// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IERC20Events, IERC20} from "../contracts/IERC20.sol";
import {IHTSDefinitions} from "../contracts/IHTSDefinitions.sol";
import {TestSetup} from "./lib/TestSetup.sol";

contract LocalNodeTokenTest is Test, TestSetup, IERC20Events {
    address _tokenAddress;
    address HTS_ADDRESS = 0x0000000000000000000000000000000000000167;

    function setUp() external {
        if (!_hederaCallExists()) return;
        deployCodeTo("HtsSystemContractLocalNode.sol", HTS_ADDRESS);
        vm.allowCheatcodes(HTS_ADDRESS);

        (int responseCode, address tokenAddress) =
            IHTSDefinitions(HTS_ADDRESS).createFungibleToken(
                tokenData("Some really really long name, just for testing purposes to prove it is not an issue", "SAMPLE"),
                int64(1000),
                int32(2)
            );

        _tokenAddress = tokenAddress;
        assertEq(responseCode, 22);
    }

    modifier hasInstalledHederaCall() {
        vm.skip(!_hederaCallExists());
        _;
    }

    function test_ERC20_name() hasInstalledHederaCall external {
        assertEq(IERC20(_tokenAddress).name(), "Some really really long name, just for testing purposes to prove it is not an issue");
    }

    function test_ERC20_decimals() hasInstalledHederaCall external {
        assertEq(IERC20(_tokenAddress).decimals(), uint256(2));
    }

    function test_ERC20_symbol() hasInstalledHederaCall external {
        assertEq(IERC20(_tokenAddress).symbol(), "SAMPLE");
    }

    function test_ERC20_balanceOf() hasInstalledHederaCall external {
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
     * function test_ERC20_transfer() hasInstalledHederaCall external {
     *   IERC20(_tokenAddress).transferFrom(address(0x67D8d32E9Bf1a9968a5ff53B87d777Aa8EBBEe69), address(0x17b2B8c63Fa35402088640e426c6709A254c7fFb), 100);
     * }
    */

    function tokenData(string memory name, string memory symbol) private pure returns (IHTSDefinitions.HederaToken memory token)
    {
        address treasury = 0x67D8d32E9Bf1a9968a5ff53B87d777Aa8EBBEe69;
        IHTSDefinitions.TokenKey[] memory keys = new IHTSDefinitions.TokenKey[](1);
        IHTSDefinitions.TokenKey memory key = IHTSDefinitions.TokenKey(
            uint(1),
            IHTSDefinitions.KeyValue(
                false,
                0x0000000000000000000000000000000000000000,
                bytes(""),
                bytes(""),
                0x0000000000000000000000000000000000000000
            )
        );
        keys[0] = key;
        IHTSDefinitions.Expiry memory expiry = IHTSDefinitions.Expiry(
            int64(1672531200), treasury, int64(31536000)
        );
        return IHTSDefinitions.HederaToken(
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

    function _hederaCallExists() private returns (bool) {
        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = "command -v -- hedera-call &> /dev/null && echo true || echo false";
        bytes memory result = vm.ffi(inputs);
        return keccak256(result) == keccak256(bytes("true"));
    }
}
