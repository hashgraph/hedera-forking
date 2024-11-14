// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {TestSetup} from "./lib/TestSetup.sol";
import {HtsSystemContract} from "../src/HtsSystemContract.sol";
import {IHederaTokenService} from "../src/IHederaTokenService.sol";
import {HVM} from "../src/HVM.sol";
import {MirrorNodeLib} from "../src/MirrorNodeLib.sol";
import {HtsSystemContractFFI} from "../src/HtsSystemContractFFI.sol";

contract HTSTest is Test, TestSetup {
    using HVM for *;

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
        // In FFI mode, `getAccountId` is not needed, so we can omit this test.
        if (testMode == TestMode.FFI) {
            return;
        }

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

    function test_HTS_getAccountAddress_should_return_account_address() external {
        // https://hashscan.io/testnet/account/0.0.5176
        string memory accountId = string.concat("0.0.", vm.toString(MFCT_TREASURY));
        address accountAddress = HtsSystemContract(HTS).getAccountAddress(accountId);
        assertEq(accountAddress, address(0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9));
    }

    function test_HTS_getAccountAddress_should_revert_when_delegatecall() external {
        vm.expectRevert(bytes("htsCall: delegated call"));
        (bool revertsAsExpected, ) = HTS.delegatecall(abi.encodeWithSelector(HtsSystemContract.getAccountAddress.selector, string.concat("0.0.", vm.toString(USDC_TREASURY))));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_getTokenInfo_should_return_token_info_for_valid_token() view external {
        address token = USDC;
        (int64 responseCode, HtsSystemContract.TokenInfo memory tokenInfo) = HtsSystemContract(HTS).getTokenInfo(token);
        assertEq(responseCode, 22);
        assertEq(tokenInfo.token.treasury, address(uint160(USDC_TREASURY)));
    }

    function test_HTS_getTokenInfo_should_revert_for_invalid_token() external {
        address token = address(0);
        vm.expectRevert(bytes("getTokenInfo: invalid token"));
        HtsSystemContract(HTS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_when_staticcall_fails() external {
        address token = USDC;
        vm.mockCallRevert(
            token,
            abi.encodeWithSelector(HtsSystemContract.getTokenInfo.selector, token),
            abi.encode("some error occurring during the call")
        );
        vm.expectRevert(bytes("Failed to get token info"));
        HtsSystemContract(HTS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_when_delegatecall() external {
        vm.expectRevert(bytes("htsCall: delegated call"));
        (bool revertsAsExpected, ) = HTS.delegatecall(abi.encodeWithSelector(HtsSystemContract.getTokenInfo.selector, address(this)));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_mintToken_should_succeed_with_valid_input() external {
        address token = USDC;
        int64 amount = 1000;
        int64 initialTotalSupply = 0;
        bytes[] memory metadata = new bytes[](0);

        (int64 responseCode, int64 newTotalSupply, int64[] memory serialNumbers) = HtsSystemContract(HTS).mintToken(token, amount, metadata);
        assertEq(responseCode, 22);
        assertEq(serialNumbers.length, 0);
        assertEq(newTotalSupply, initialTotalSupply + amount);
    }

    function test_mintToken_should_revert_with_invalid_treasureAccount() external {
        address token = USDC;
        int64 amount = 1000;
        bytes[] memory metadata = new bytes[](0);

        if (HTS.code.length >= 1) {
            string memory accountId = string.concat("0.0.", vm.toString(USDC_TREASURY));
            vm.mockCall(HTS, abi.encodeWithSelector(HtsSystemContractFFI.getAccountAddress.selector, accountId), abi.encode(address(0)));
        } else {
            HVM.storeString(USDC, HVM.getSlot("treasuryAccountId"), "0.0.0");
        }

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
        int64 amount = 1000;
        int64 initialTotalSupply = 0;

        (int64 responseCodeMint, int64 newTotalSupplyAfterMint, int64[] memory serialNumbers) = HtsSystemContract(HTS).mintToken(token, amount, new bytes[](0));
        assertEq(responseCodeMint, 22);
        assertEq(serialNumbers.length, 0);
        assertEq(newTotalSupplyAfterMint, initialTotalSupply + amount);

        (int64 responseCodeBurn, int64 newTotalSupplyAfterBurn) = HtsSystemContract(HTS).burnToken(token, amount, serialNumbers);
        assertEq(responseCodeBurn, 22);
        assertEq(newTotalSupplyAfterBurn, initialTotalSupply);
    }

    function test_burnToken_should_revert_with_invalid_treasureAccount() external {
        address token = MFCT;
        int64 amount = 1000;
        int64[] memory serialNumbers = new int64[](0);

        if (HTS.code.length >= 1) {
            string memory accountId = string(abi.encodePacked("0.0.", vm.toString(MFCT_TREASURY)));
            vm.mockCall(HTS, abi.encodeWithSelector(HtsSystemContractFFI.getAccountAddress.selector, accountId), abi.encode(address(0)));
        } else {
            HVM.storeString(MFCT, HVM.getSlot("treasuryAccountId"), "0.0.0");
        }
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

    function _emptyTokenInfo() internal pure returns (IHederaTokenService.TokenInfo memory) {
        return IHederaTokenService.TokenInfo(
            IHederaTokenService.HederaToken("", "", address(0), "", false, 0, false, new IHederaTokenService.TokenKey[](0), IHederaTokenService.Expiry(0, address(0), 0)),
            0,
            false,
            false,
            false,
            new IHederaTokenService.FixedFee[](0),
            new IHederaTokenService.FractionalFee[](0),
            new IHederaTokenService.RoyaltyFee[](0),
            "");
    }
}
