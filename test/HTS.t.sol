// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "./lib/TestSetup.sol";
import {HtsSystemContract} from "../src/HtsSystemContract.sol";
import {IHederaTokenService} from "../src/IHederaTokenService.sol";

contract HTSTest is Test, TestSetup {

    function setUp() external {
        setUpMockStorageForNonFork();
    }

    function test_HTS_should_revert_when_not_enough_calldata() external {
        vm.expectRevert(bytes("fallback: not enough calldata"));
        (bool revertsAsExpected, ) = HTS.call(bytes("1234"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_should_revert_when_fallback_selector_is_not_supported() external {
        vm.expectRevert(bytes("fallback: unsupported selector"));
        (bool revertsAsExpected, ) = HTS.call(bytes("123456789012345678901234567890"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_should_revert_when_calldata_token_is_not_caller() external {
        vm.expectRevert(bytes("fallback: token is not caller"));
        (bool revertsAsExpected, ) = HTS.call(bytes(hex"618dc65e9012345678901234567890123456789012345678901234567890"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_getAccountId_should_return_account_number() view external {
        // https://hashscan.io/testnet/account/0.0.1421
        address alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        uint32 accountId = HtsSystemContract(HTS).getAccountId(alice);
        assertEq(accountId, 1421);
    }

    function test_HTS_should_revert_when_delegatecall_getAccountId() external {
        vm.expectRevert(bytes("htsCall: delegated call"));
        (bool revertsAsExpected, ) = HTS.delegatecall(abi.encodeWithSelector(HtsSystemContract.getAccountId.selector, address(this)));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_mintToken_should_succeed_with_valid_input() external {
        address token = USDC;
        address treasury = USDC_TREASURY;
        int64 amount = 1000;
        int64 initialTotalSupply = 0;
        bytes[] memory metadata = new bytes[](0);
        IHederaTokenService.TokenInfo memory tokenInfo = IHederaTokenService.TokenInfo(
            IHederaTokenService.HederaToken(
                "USDC",
                "USDC",
                treasury,
                "",
                false,
                initialTotalSupply + amount,
                false,
                new IHederaTokenService.TokenKey[](0),
                IHederaTokenService.Expiry(0, address(0), 0)
            ),
            initialTotalSupply,
            false,
            false,
            false,
            new IHederaTokenService.FixedFee[](0),
            new IHederaTokenService.FractionalFee[](0),
            new IHederaTokenService.RoyaltyFee[](0),
            ""
        );

        vm.mockCall(HTS, abi.encodeWithSelector(HtsSystemContract._mockTokenInfo.selector), abi.encode(tokenInfo));
        (int64 responseCode, int64 newTotalSupply, int64[] memory serialNumbers) = HtsSystemContract(HTS).mintToken(token, amount, metadata);
        assertEq(responseCode, 22);
        assertEq(serialNumbers.length, 0);
        assertEq(newTotalSupply, initialTotalSupply + amount);
    }

    function test_mintToken_should_revert_with_invalid_treasureAccount() external {
        address token = USDC;
        int64 amount = 1000;
        bytes[] memory metadata = new bytes[](0);
        int64 totalSupply = 10000000005000000;
        IHederaTokenService.TokenInfo memory tokenInfo = IHederaTokenService.TokenInfo(
            IHederaTokenService.HederaToken(
                "USDC",
                "USDC",
                address(0),
                "",
                false,
                totalSupply + amount,
                false,
                new IHederaTokenService.TokenKey[](0),
                IHederaTokenService.Expiry(0, address(0), 0)
            ),
            totalSupply,
            false,
            false,
            false,
            new IHederaTokenService.FixedFee[](0),
            new IHederaTokenService.FractionalFee[](0),
            new IHederaTokenService.RoyaltyFee[](0),
            ""
        );

        vm.mockCall(HTS, abi.encodeWithSelector(HtsSystemContract._mockTokenInfo.selector), abi.encode(tokenInfo));

        vm.expectRevert(bytes("mintToken: invalid account"));
        HtsSystemContract(HTS).mintToken(token, amount, metadata);
    }

    function test_mintToken_should_revert_with_invalid_token() external {
        address token = address(0);
        int64 amount = 1000;
        bytes[] memory metadata = new bytes[](0);

        vm.expectRevert(bytes("mintToken: invalid token"));
        HtsSystemContract(HTS).mintToken(token, amount, metadata);
    }

    function test_mintToken_should_revert_with_invalid_amount() external {
        address token = address(0x123);
        int64 amount = 0;
        bytes[] memory metadata = new bytes[](0);

        vm.expectRevert(bytes("mintToken: invalid amount"));
        HtsSystemContract(HTS).mintToken(token, amount, metadata);
    }

    function test_burnToken_should_succeed_with_valid_input() external {
        address token = MFCT;
        address treasury = MFCT_TREASURY;
        int64 amount = 1000;
        int64 initialTotalSupply = 0;
        IHederaTokenService.TokenInfo memory tokenInfo = IHederaTokenService.TokenInfo(
            IHederaTokenService.HederaToken(
                "MFCT",
                "MFCT",
                treasury,
                "",
                false,
                initialTotalSupply + amount,
                false,
                new IHederaTokenService.TokenKey[](0),
                IHederaTokenService.Expiry(0, address(0), 0)
            ),
            initialTotalSupply,
            false,
            false,
            false,
            new IHederaTokenService.FixedFee[](0),
            new IHederaTokenService.FractionalFee[](0),
            new IHederaTokenService.RoyaltyFee[](0),
            ""
        );

        vm.mockCall(HTS, abi.encodeWithSelector(HtsSystemContract._mockTokenInfo.selector), abi.encode(tokenInfo));
        (int64 responseCodeMint, int64 newTotalSupplyAfterMint, int64[] memory serialNumbers) = HtsSystemContract(HTS).mintToken(token, amount, new bytes[](0));
        assertEq(responseCodeMint, 22);
        assertEq(serialNumbers.length, 0);
        assertEq(newTotalSupplyAfterMint, initialTotalSupply + amount);

        vm.mockCall(HTS, abi.encodeWithSelector(HtsSystemContract._mockTokenInfo.selector), abi.encode(tokenInfo));
        (int64 responseCodeBurn, int64 newTotalSupplyAfterBurn) = HtsSystemContract(HTS).burnToken(token, amount, serialNumbers);
        assertEq(responseCodeBurn, 22);
        assertEq(newTotalSupplyAfterBurn, initialTotalSupply);
    }

    function test_burnToken_should_revert_with_invalid_treasureAccount() external {
        address token = MFCT;
        int64 amount = 1000;
        int64 initialTotalSupply = 0;
        int64[] memory serialNumbers = new int64[](0);
        IHederaTokenService.TokenInfo memory tokenInfo = IHederaTokenService.TokenInfo(
            IHederaTokenService.HederaToken(
                "MFCT",
                "MFCT",
                address(0),
                "",
                false,
                initialTotalSupply + amount,
                false,
                new IHederaTokenService.TokenKey[](0),
                IHederaTokenService.Expiry(0, address(0), 0)
            ),
            initialTotalSupply,
            false,
            false,
            false,
            new IHederaTokenService.FixedFee[](0),
            new IHederaTokenService.FractionalFee[](0),
            new IHederaTokenService.RoyaltyFee[](0),
            ""
        );

        vm.mockCall(HTS, abi.encodeWithSelector(HtsSystemContract._mockTokenInfo.selector), abi.encode(tokenInfo));

        vm.expectRevert(bytes("burnToken: invalid account"));
        HtsSystemContract(HTS).burnToken(token, amount, serialNumbers);
    }

    function test_burnToken_should_revert_with_invalid_token() external {
        address token = address(0);
        int64 amount = 1000;
        int64[] memory serialNumbers = new int64[](0);

        vm.expectRevert(bytes("burnToken: invalid token"));
        HtsSystemContract(HTS).burnToken(token, amount, serialNumbers);
    }

    function test_burnToken_should_revert_with_invalid_amount() external {
        address token = address(0x123);
        int64 amount = 0;
        int64[] memory serialNumbers = new int64[](0);

        vm.expectRevert(bytes("burnToken: invalid amount"));
        HtsSystemContract(HTS).burnToken(token, amount, serialNumbers);
    }
}
