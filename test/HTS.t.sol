// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HederaResponseCodes} from "../contracts/HederaResponseCodes.sol";
import {HtsSystemContract, HTS_ADDRESS} from "../contracts/HtsSystemContract.sol";
import {IHederaTokenService} from "../contracts/IHederaTokenService.sol";
import {IERC20} from "../contracts/IERC20.sol";
import {IERC721} from "../contracts/IERC721.sol";
import {IHRC719} from "../contracts/IHRC719.sol";
import {TestSetup} from "./lib/TestSetup.sol";

contract HTSTest is Test, TestSetup {

    address private unknownUser;

    function setUp() external {
        setUpMockStorageForNonFork();

        unknownUser = makeAddr("unknown-user");
    }

    function test_HTS_should_revert_when_not_enough_calldata() external {
        vm.expectRevert(bytes("fallback: not enough calldata"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.call(bytes("1234"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_should_revert_when_fallback_selector_is_not_supported() external {
        vm.expectRevert(bytes("fallback: unsupported selector"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.call(bytes("123456789012345678901234567890"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_should_revert_when_calldata_token_is_not_caller() external {
        vm.expectRevert(bytes("fallback: token is not caller"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.call(bytes(hex"618dc65e9012345678901234567890123456789012345678901234567890"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_getAccountId_should_return_account_number() view external {
        // https://hashscan.io/testnet/account/0.0.1421
        address alice = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(alice);
        assertEq(accountId, testMode != TestMode.JSON_RPC
            ? uint32(bytes4(keccak256(abi.encodePacked(alice))))
            : 1421
        );

        accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(unknownUser);
        assertEq(accountId, testMode != TestMode.JSON_RPC
            ? uint32(bytes4(keccak256(abi.encodePacked(unknownUser))))
            : uint32(uint160(unknownUser))
        );
    }

    function test_HTS_should_revert_when_delegatecall_getAccountId() external {
        vm.expectRevert(bytes("htsCall: delegated call"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.delegatecall(abi.encodeWithSelector(HtsSystemContract.getAccountId.selector, address(this)));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_getTokenInfo_should_return_token_info_for_valid_token() external view {
        address token = USDC;
        (int64 responseCode, IHederaTokenService.TokenInfo memory tokenInfo) = IHederaTokenService(HTS_ADDRESS).getTokenInfo(token);

        assertEq(responseCode, HederaResponseCodes.SUCCESS);
        assertEq(tokenInfo.token.name, "USD Coin");
        assertEq(tokenInfo.token.symbol, "USDC");
        assertEq(tokenInfo.token.treasury, address(0x0000000000000000000000000000000000001438));
        assertEq(tokenInfo.token.memo, "USDC HBAR");
        assertEq(tokenInfo.token.tokenSupplyType, false);
        assertEq(tokenInfo.token.maxSupply, 0);
        assertEq(tokenInfo.token.freezeDefault, false);
        assertEq(tokenInfo.token.tokenKeys.length, 7);
        // AdminKey
        assertEq(tokenInfo.token.tokenKeys[0].keyType, 0x1);
        assertEq(tokenInfo.token.tokenKeys[0].key.inheritAccountKey, false);
        assertEq(tokenInfo.token.tokenKeys[0].key.contractId, address(0));
        assertEq(tokenInfo.token.tokenKeys[0].key.ed25519, hex"5db29fb3f19f8618cc4689cf13e78a935621845d67547719faf49f65d5c367cc");
        assertEq(tokenInfo.token.tokenKeys[0].key.ECDSA_secp256k1, bytes(""));
        assertEq(tokenInfo.token.tokenKeys[0].key.delegatableContractId, address(0));
        assertEq(HtsSystemContract(HTS_ADDRESS).getKeyOwner(token, 0x1), 0xF287CfB303322B6dCDA77ce0824Bd1a3fA5d0e47);
        // FreezeKey
        assertEq(tokenInfo.token.tokenKeys[2].keyType, 0x4);
        assertEq(tokenInfo.token.tokenKeys[2].key.inheritAccountKey, false);
        assertEq(tokenInfo.token.tokenKeys[2].key.contractId, address(0));
        assertEq(tokenInfo.token.tokenKeys[2].key.ed25519, hex"baa2dd1684d8445d41b22f2b2c913484a7d885cf25ce525f8bf3fe8d5c8cb85d");
        assertEq(tokenInfo.token.tokenKeys[2].key.ECDSA_secp256k1, bytes(""));
        assertEq(tokenInfo.token.tokenKeys[2].key.delegatableContractId, address(0));
        assertEq(HtsSystemContract(HTS_ADDRESS).getKeyOwner(token, 0x4), 0x6c273d045CC8219F98e7F5944B49Ae1e2fdA1449);
        // SupplyKey
        assertEq(tokenInfo.token.tokenKeys[4].keyType, 0x10);
        assertEq(tokenInfo.token.tokenKeys[4].key.inheritAccountKey, false);
        assertEq(tokenInfo.token.tokenKeys[4].key.contractId, address(0));
        assertEq(tokenInfo.token.tokenKeys[4].key.ed25519, hex"4e4658983980d1b25a634eeeb26cb2b0f0e2e9c83263ba5b056798d35f2139a8");
        assertEq(tokenInfo.token.tokenKeys[4].key.ECDSA_secp256k1, bytes(""));
        assertEq(tokenInfo.token.tokenKeys[4].key.delegatableContractId, address(0));
        assertEq(HtsSystemContract(HTS_ADDRESS).getKeyOwner(token, 0x10), 0x4bc2a5E2099e0536C7B21610BD5A0E1EFbb032A0);
        // Expiry
        assertEq(tokenInfo.token.expiry.second, 1706825707000718000);
        assertEq(tokenInfo.token.expiry.autoRenewAccount, address(0));
        assertEq(tokenInfo.token.expiry.autoRenewPeriod, 0);
        assertEq(tokenInfo.totalSupply, 10000000005000000);
        assertEq(tokenInfo.deleted, false);
        assertEq(tokenInfo.defaultKycStatus, false);
        assertEq(tokenInfo.pauseStatus, false);
        assertEq(tokenInfo.fixedFees.length, 0);
        assertEq(tokenInfo.fractionalFees.length, 0);
        assertEq(tokenInfo.royaltyFees.length, 0);
        assertEq(tokenInfo.ledgerId, testMode == TestMode.FFI ? "0x01" : "0x00");
    }

    function test_HTS_getTokenInfo_should_return_custom_fees_for_valid_token() external view {
        (int64 responseCode, IHederaTokenService.TokenInfo memory tokenInfo) = IHederaTokenService(HTS_ADDRESS).getTokenInfo(CTCF);
        assertEq(responseCode, HederaResponseCodes.SUCCESS);
        assertEq(tokenInfo.token.name, "Crypto Token with Custom Fees");
        assertEq(tokenInfo.token.symbol, "CTCF");
        assertEq(tokenInfo.token.memo, "");
        assertEq(tokenInfo.token.tokenSupplyType, false);
        assertEq(tokenInfo.token.maxSupply, 0);

        assertEq(tokenInfo.fixedFees.length, 3);

        assertEq(tokenInfo.fixedFees[0].feeCollector, 0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9);
        assertEq(tokenInfo.fixedFees[0].amount, 1);
        assertEq(tokenInfo.fixedFees[0].tokenId, address(0));
        assertEq(tokenInfo.fixedFees[0].useHbarsForPayment, true);
        assertEq(tokenInfo.fixedFees[0].useCurrentTokenForPayment, false);

        assertEq(tokenInfo.fixedFees[1].feeCollector, 0x0000000000000000000000000000000000000D89);
        assertEq(tokenInfo.fixedFees[1].amount, 2);
        assertEq(tokenInfo.fixedFees[1].tokenId, 0x0000000000000000000000000000000000068cDa);
        assertEq(tokenInfo.fixedFees[1].useHbarsForPayment, false);
        assertEq(tokenInfo.fixedFees[1].useCurrentTokenForPayment, false);

        assertEq(tokenInfo.fixedFees[2].feeCollector, 0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9);
        assertEq(tokenInfo.fixedFees[2].amount, 3);
        assertEq(tokenInfo.fixedFees[2].tokenId, CTCF);
        assertEq(tokenInfo.fixedFees[2].useHbarsForPayment, false);
        assertEq(tokenInfo.fixedFees[2].useCurrentTokenForPayment, true);

        assertEq(tokenInfo.fractionalFees.length, 2);

        assertEq(tokenInfo.fractionalFees[0].netOfTransfers, false);
        assertEq(tokenInfo.fractionalFees[0].numerator, 1);
        assertEq(tokenInfo.fractionalFees[0].denominator, 100);
        assertEq(tokenInfo.fractionalFees[0].minimumAmount, 3);
        assertEq(tokenInfo.fractionalFees[0].maximumAmount, 4);
        assertEq(tokenInfo.fractionalFees[0].feeCollector, 0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9);

        assertEq(tokenInfo.fractionalFees[1].netOfTransfers, true);
        assertEq(tokenInfo.fractionalFees[1].numerator, 5);
        assertEq(tokenInfo.fractionalFees[1].denominator, 100);
        assertEq(tokenInfo.fractionalFees[1].minimumAmount, 3);
        assertEq(tokenInfo.fractionalFees[1].maximumAmount, 4);
        assertEq(tokenInfo.fractionalFees[1].feeCollector, 0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9);

        assertEq(tokenInfo.royaltyFees.length, 0);
    }

    function test_HTS_getTokenInfo_should_revert_for_empty_token_address() external {
        address token = address(0);
        vm.expectRevert(bytes("getTokenInfo: invalid token"));
        IHederaTokenService(HTS_ADDRESS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_for_invalid_token() external {
        address token = makeAddr("unknown-token");
        vm.expectRevert();
        IHederaTokenService(HTS_ADDRESS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_when_call_to_mirror_node_fails() external {
        if (TestMode.JSON_RPC == testMode) {
            // skip this test for the mock JSON-RPC, as it is not possible to simulate the mirror node error
            return;
        }

        address token = MFCT;
        vm.mockCallRevert(address(mirrorNode), abi.encode(mirrorNode.fetchTokenData.selector), abi.encode("mirror node error"));
        vm.expectRevert(abi.encode("mirror node error"));
        IHederaTokenService(HTS_ADDRESS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_when_delegatecall() external {
        vm.expectRevert(bytes("htsCall: delegated call"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.delegatecall(abi.encodeWithSelector(IHederaTokenService.getTokenInfo.selector, address(this)));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_getTokenInfo_should_revert_when_called_from_outside_of_HTS() external {
        address token = USDC;
        vm.expectRevert(bytes("redirectForToken: not supported"));
        IHederaTokenService(token).getTokenInfo(token);
    }

    function test_mintToken_should_succeed_with_valid_input() external {
        address token = USDC;
        address treasury = USDC_TREASURY;
        int64 amount = 1000;
        int64 initialTotalSupply = 10000000005000000;
        uint256 initialTreasuryBalance = IERC20(token).balanceOf(treasury);
        bytes[] memory metadata = new bytes[](0);

        (int64 responseCode, int64 newTotalSupply, int64[] memory serialNumbers) = IHederaTokenService(HTS_ADDRESS).mintToken(token, amount, metadata);
        assertEq(responseCode, HederaResponseCodes.SUCCESS);
        assertEq(serialNumbers.length, 0);
        assertEq(newTotalSupply, initialTotalSupply + amount);
        assertEq(IERC20(token).balanceOf(treasury), uint64(initialTreasuryBalance) + uint64(amount));
        assertEq(IERC20(token).totalSupply(), uint256(int256(newTotalSupply)));

        (int64 responseCodeGet, IHederaTokenService.TokenInfo memory tokenInfo) = IHederaTokenService(HTS_ADDRESS).getTokenInfo(token);
        assertEq(responseCodeGet, HederaResponseCodes.SUCCESS);

        assertEq(tokenInfo.totalSupply, newTotalSupply);
    }

    function test_mintToken_should_revert_with_invalid_treasureAccount() external {
        address token = USDC;
        int64 amount = 1000;
        bytes[] memory metadata = new bytes[](0);
        int64 initialTotalSupply = 10000000005000000;
        IHederaTokenService.TokenInfo memory tokenInfo;
        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](1);
        keys[0].keyType = 0x10; // Supply key
        keys[0].key.contractId = msg.sender;
        tokenInfo.token = IHederaTokenService.HederaToken(
            "USD Coin",
            "USDC",
            address(0),
            "USDC HBAR",
            false,
            initialTotalSupply + amount,
            false,
            keys,
            IHederaTokenService.Expiry(0, address(0), 0)
        );

        vm.mockCall(
            token,
            abi.encode(IHederaTokenService.getTokenInfo.selector),
            abi.encode(HederaResponseCodes.SUCCESS, tokenInfo)
        );
        vm.expectRevert(bytes("mintToken: invalid account"));
        IHederaTokenService(HTS_ADDRESS).mintToken(token, amount, metadata);
    }

    function test_mintToken_should_fail_with_no_supplyKey() external {
        address token = USDC;
        int64 amount = 1000;
        bytes[] memory metadata = new bytes[](0);
        int64 initialTotalSupply = 10000000005000000;
        IHederaTokenService.TokenInfo memory tokenInfo;
        tokenInfo.token = IHederaTokenService.HederaToken(
            "USD Coin",
            "USDC",
            msg.sender,
            "USDC HBAR",
            false,
            initialTotalSupply + amount,
            false,
            new IHederaTokenService.TokenKey[](0),
            IHederaTokenService.Expiry(0, address(0), 0)
        );

        vm.mockCall(
            token,
            abi.encode(IHederaTokenService.getTokenInfo.selector),
            abi.encode(HederaResponseCodes.SUCCESS, tokenInfo)
        );
        vm.mockCall(
            token,
            abi.encodeWithSelector(HtsSystemContract.getKeyOwner.selector, token, 0x10),
            abi.encode(address(0))
        );
        (int64 code, , ) = IHederaTokenService(HTS_ADDRESS).mintToken(token, amount, metadata);
        assertEq(code, HederaResponseCodes.TOKEN_HAS_NO_SUPPLY_KEY);
    }

    function test_mintToken_should_revert_with_invalid_token() external {
        address token = address(0);
        int64 amount = 1000;
        bytes[] memory metadata = new bytes[](0);

        vm.expectRevert(bytes("getTokenInfo: invalid token"));
        IHederaTokenService(HTS_ADDRESS).mintToken(token, amount, metadata);
    }

    function test_mintToken_should_revert_with_invalid_amount() external {
        int64 amount = 0;
        bytes[] memory metadata = new bytes[](0);

        vm.expectRevert(bytes("mintToken: invalid amount"));
        IHederaTokenService(HTS_ADDRESS).mintToken(USDC, amount, metadata);
    }

    function test_burnToken_should_succeed_with_valid_input() external {
        address token = USDC;
        address treasury = USDC_TREASURY;
        int64 amount = 1000;
        int64 initialTotalSupply = int64(int256(IERC20(token).totalSupply()));
        uint256 initialTreasuryBalance = IERC20(token).balanceOf(treasury);

        (int64 responseCodeMint, int64 newTotalSupplyAfterMint, int64[] memory serialNumbers) = IHederaTokenService(HTS_ADDRESS).mintToken(token, amount, new bytes[](0));
        assertEq(responseCodeMint, HederaResponseCodes.SUCCESS);
        assertEq(serialNumbers.length, 0);
        assertEq(newTotalSupplyAfterMint, initialTotalSupply + amount);
        assertEq(IERC20(token).balanceOf(treasury), uint64(initialTreasuryBalance) + uint64(amount));

        (int64 responseCodeBurn, int64 newTotalSupplyAfterBurn) = IHederaTokenService(HTS_ADDRESS).burnToken(token, amount, serialNumbers);
        assertEq(responseCodeBurn, HederaResponseCodes.SUCCESS);
        assertEq(newTotalSupplyAfterBurn, initialTotalSupply);
        assertEq(IERC20(token).balanceOf(treasury), uint64(initialTreasuryBalance));

        (int64 responseCodeGet, IHederaTokenService.TokenInfo memory tokenInfo) = IHederaTokenService(HTS_ADDRESS).getTokenInfo(token);
        assertEq(responseCodeGet, HederaResponseCodes.SUCCESS);

        assertEq(tokenInfo.totalSupply, newTotalSupplyAfterBurn);
    }

    function test_burnToken_should_revert_with_invalid_treasureAccount() external {
        address token = MFCT;
        int64 amount = 1000;
        int64 initialTotalSupply = 5000;
        int64[] memory serialNumbers = new int64[](0);
        IHederaTokenService.TokenInfo memory tokenInfo;
        tokenInfo.token = IHederaTokenService.HederaToken(
            "My Crypto Token is the name which the string length is greater than 31",
            "Token symbol must be exactly 32!",
            address(0),
            "",
            false,
            initialTotalSupply + amount,
            false,
            new IHederaTokenService.TokenKey[](0),
            IHederaTokenService.Expiry(0, address(0), 0)
        );

        vm.mockCall(
            token,
            abi.encode(IHederaTokenService.getTokenInfo.selector),
            abi.encode(HederaResponseCodes.SUCCESS, tokenInfo)
        );
        vm.mockCall(
            token,
            abi.encodeWithSelector(HtsSystemContract.getKeyOwner.selector, MFCT, 0x10),
            abi.encode(msg.sender)
        );
        vm.expectRevert(bytes("burnToken: invalid account"));
        IHederaTokenService(HTS_ADDRESS).burnToken(token, amount, serialNumbers);
    }

    function test_burnToken_should_revert_with_no_supplier() external {
        address token = MFCT;
        int64 amount = 1000;
        int64 initialTotalSupply = 5000;
        int64[] memory serialNumbers = new int64[](0);
        IHederaTokenService.TokenInfo memory tokenInfo;
        tokenInfo.token = IHederaTokenService.HederaToken(
            "My Crypto Token is the name which the string length is greater than 31",
            "Token symbol must be exactly 32!",
            address(0),
            "",
            false,
            initialTotalSupply + amount,
            false,
            new IHederaTokenService.TokenKey[](0),
            IHederaTokenService.Expiry(0, address(0), 0)
        );

        vm.mockCall(
            token,
            abi.encode(IHederaTokenService.getTokenInfo.selector),
            abi.encode(HederaResponseCodes.SUCCESS, tokenInfo)
        );
        (int64 code, ) = IHederaTokenService(HTS_ADDRESS).burnToken(token, amount, serialNumbers);
        assertEq(code, HederaResponseCodes.TOKEN_HAS_NO_SUPPLY_KEY);
    }

    function test_burnToken_should_revert_with_invalid_token() external {
        address token = address(0);
        int64 amount = 1000;
        int64[] memory serialNumbers = new int64[](0);

        vm.expectRevert(bytes("getTokenInfo: invalid token"));
        IHederaTokenService(HTS_ADDRESS).burnToken(token, amount, serialNumbers);
    }

    function test_burnToken_should_revert_with_invalid_amount() external {
        int64 amount = 0;
        int64[] memory serialNumbers = new int64[](0);

        vm.expectRevert(bytes("burnToken: invalid amount"));
        IHederaTokenService(HTS_ADDRESS).burnToken(USDC, amount, serialNumbers);
    }

    function test_HTS_getApproved_should_return_correct_address() external view {
        address token = CFNFTFF;
        (int64 responseCodeGetApproved, address approved) = HtsSystemContract(HTS_ADDRESS)
            .getApproved(token, 1);
        assertEq(responseCodeGetApproved, HederaResponseCodes.SUCCESS);
        assertEq(approved, CFNFTFF_ALLOWED_SPENDER);
    }

    function test_HTS_getApproved_should_return_nothing_when_no_approval_granted() external view {
        address token = CFNFTFF;
        (int64 responseCodeGetApproved, address approved) = HtsSystemContract(HTS_ADDRESS).getApproved(token, 2);
        assertEq(responseCodeGetApproved, HederaResponseCodes.SUCCESS);
        assertEq(approved, address(0));
    }

    function test_HTS_isApprovedForAll() view external {
        address token = CFNFTFF;
        (int64 isApprovedForAllResponseCode, bool isApproved) = HtsSystemContract(HTS_ADDRESS)
            .isApprovedForAll(token, CFNFTFF_TREASURY, CFNFTFF_ALLOWED_SPENDER);
        assertEq(isApprovedForAllResponseCode, HederaResponseCodes.SUCCESS);
        assertFalse(isApproved);
    }

    function test_HTS_getTokenCustomFees_should_return_custom_fees_for_valid_token() external view {
        (
            int64 responseCode,
            IHederaTokenService.FixedFee[] memory fixedFees,
            IHederaTokenService.FractionalFee[] memory fractionalFees,
            IHederaTokenService.RoyaltyFee[] memory royaltyFees
        ) = IHederaTokenService(HTS_ADDRESS).getTokenCustomFees(CTCF);
        assertEq(responseCode, HederaResponseCodes.SUCCESS);

        assertEq(fixedFees.length, 3);

        assertEq(fixedFees[0].feeCollector, 0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9);
        assertEq(fixedFees[0].amount, 1);
        assertEq(fixedFees[0].tokenId, address(0));
        assertEq(fixedFees[0].useHbarsForPayment, true);
        assertEq(fixedFees[0].useCurrentTokenForPayment, false);

        assertEq(fixedFees[1].feeCollector, 0x0000000000000000000000000000000000000D89);
        assertEq(fixedFees[1].amount, 2);
        assertEq(fixedFees[1].tokenId, 0x0000000000000000000000000000000000068cDa);
        assertEq(fixedFees[1].useHbarsForPayment, false);
        assertEq(fixedFees[1].useCurrentTokenForPayment, false);

        assertEq(fixedFees[2].feeCollector, 0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9);
        assertEq(fixedFees[2].amount, 3);
        assertEq(fixedFees[2].tokenId, CTCF);
        assertEq(fixedFees[2].useHbarsForPayment, false);
        assertEq(fixedFees[2].useCurrentTokenForPayment, true);

        assertEq(fractionalFees.length, 2);

        assertEq(fractionalFees[0].netOfTransfers, false);
        assertEq(fractionalFees[0].numerator, 1);
        assertEq(fractionalFees[0].denominator, 100);
        assertEq(fractionalFees[0].minimumAmount, 3);
        assertEq(fractionalFees[0].maximumAmount, 4);
        assertEq(fractionalFees[0].feeCollector, 0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9);

        assertEq(fractionalFees[1].netOfTransfers, true);
        assertEq(fractionalFees[1].numerator, 5);
        assertEq(fractionalFees[1].denominator, 100);
        assertEq(fractionalFees[1].minimumAmount, 3);
        assertEq(fractionalFees[1].maximumAmount, 4);
        assertEq(fractionalFees[1].feeCollector, 0xa3612A87022a4706FC9452C50abd2703ac4Fd7d9);

        assertEq(royaltyFees.length, 0);
    }

    function test_HTS_getTokenDefaultFreezeStatus_should_return_correct_value_for_valid_token() external view {
        address token = CFNFTFF;
        (int64 freezeStatus, bool defaultFreeze) = IHederaTokenService(HTS_ADDRESS).getTokenDefaultFreezeStatus(token);
        assertEq(freezeStatus, HederaResponseCodes.SUCCESS);
        assertFalse(defaultFreeze);
    }

    function test_HTS_getTokenDefaultKycStatus_should_return_correct_value_for_valid_token() external view {
        address token = CFNFTFF;
        (int64 kycStatus, bool defaultKyc) = IHederaTokenService(HTS_ADDRESS).getTokenDefaultKycStatus(token);
        assertEq(kycStatus, HederaResponseCodes.SUCCESS);
        assertFalse(defaultKyc);
    }

    function test_HTS_getTokenExpiryInfo_should_return_correct_value_for_valid_token() external view {
        (int64 expiryStatusCode, IHederaTokenService.Expiry memory expiry)
            = IHederaTokenService(HTS_ADDRESS).getTokenExpiryInfo(USDC);
        assertEq(expiryStatusCode, HederaResponseCodes.SUCCESS);
        assertEq(expiry.second, 1706825707000718000);
        assertEq(expiry.autoRenewAccount, address(0));
        assertEq(expiry.autoRenewPeriod, 0);
    }

    function test_HTS_getTokenKey_should_return_correct_key_value() external view {
        address token = USDC;

        // AdminKey
        (int64 adminKeyStatusCode, IHederaTokenService.KeyValue memory adminKey)
            = IHederaTokenService(HTS_ADDRESS).getTokenKey(token, 0x1);
        assertEq(adminKeyStatusCode, HederaResponseCodes.SUCCESS);
        assertEq(adminKey.inheritAccountKey, false);
        assertEq(adminKey.contractId, address(0));
        assertEq(adminKey.ed25519, hex"5db29fb3f19f8618cc4689cf13e78a935621845d67547719faf49f65d5c367cc");
        assertEq(adminKey.ECDSA_secp256k1, bytes(""));
        assertEq(adminKey.delegatableContractId, address(0));
        // FreezeKey
        (int64 freezeKeyStatusCode, IHederaTokenService.KeyValue memory freezeKey)
            = IHederaTokenService(HTS_ADDRESS).getTokenKey(token, 0x4);
        assertEq(freezeKeyStatusCode, HederaResponseCodes.SUCCESS);
        assertEq(freezeKey.inheritAccountKey, false);
        assertEq(adminKey.contractId, address(0));
        assertEq(freezeKey.ed25519, hex"baa2dd1684d8445d41b22f2b2c913484a7d885cf25ce525f8bf3fe8d5c8cb85d");
        assertEq(freezeKey.ECDSA_secp256k1, bytes(""));
        assertEq(freezeKey.delegatableContractId, address(0));
        // SupplyKey
        (int64 supplyKeyStatusCode, IHederaTokenService.KeyValue memory supplyKey)
            = IHederaTokenService(HTS_ADDRESS).getTokenKey(token, 0x10);
        assertEq(supplyKeyStatusCode, HederaResponseCodes.SUCCESS);
        assertEq(supplyKey.inheritAccountKey, false);
        assertEq(adminKey.contractId, address(0));
        assertEq(supplyKey.ed25519, hex"4e4658983980d1b25a634eeeb26cb2b0f0e2e9c83263ba5b056798d35f2139a8");
        assertEq(supplyKey.ECDSA_secp256k1, bytes(""));
        assertEq(supplyKey.delegatableContractId, address(0));
    }

    function test_HTS_getTokenType_should_return_correct_token_type_for_existing_token() external view {
        (int64 ftTypeStatusCode, int32 ftType) = IHederaTokenService(HTS_ADDRESS).getTokenType(USDC);
        assertEq(ftTypeStatusCode, HederaResponseCodes.SUCCESS);
        assertEq(ftType, int32(0));

        (int64 nftTypeStatusCode, int32 nftType) = IHederaTokenService(HTS_ADDRESS).getTokenType(CFNFTFF);
        assertEq(nftTypeStatusCode, HederaResponseCodes.SUCCESS);
        assertEq(nftType, int32(1));
    }

    function test_HTS_isToken_should_return_correct_is_token_info() external view {
        (int64 ftIsTokenStatusCode, bool ftIsToken) = IHederaTokenService(HTS_ADDRESS).isToken(USDC);
        assertEq(ftIsTokenStatusCode, HederaResponseCodes.SUCCESS);
        assertTrue(ftIsToken);

        (int64 nftIsTokenStatusCode, bool nftIsToken) = IHederaTokenService(HTS_ADDRESS).isToken(CFNFTFF);
        assertEq(nftIsTokenStatusCode, HederaResponseCodes.SUCCESS);
        assertTrue(nftIsToken);

        (int64 accountIsTokenCode, bool accountIsToken) = IHederaTokenService(HTS_ADDRESS).isToken(CFNFTFF_TREASURY);
        assertEq(accountIsTokenCode, HederaResponseCodes.SUCCESS);
        assertFalse(accountIsToken);

        (int64 randomIsTokenCode, bool randomIsToken) = IHederaTokenService(HTS_ADDRESS).isToken(address(123));
        assertEq(randomIsTokenCode, HederaResponseCodes.SUCCESS);
        assertFalse(randomIsToken);
    }

    function test_HTS_associations_with_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        vm.startPrank(bob); // https://book.getfoundry.sh/cheatcodes/prank
        assertFalse(IHRC719(USDC).isAssociated());

        // Associate the token.
        int64 associationResponseCode = IHederaTokenService(HTS_ADDRESS).associateToken(bob, USDC);
        assertEq(associationResponseCode, HederaResponseCodes.SUCCESS);
        assertTrue(IHRC719(USDC).isAssociated());

        // Dissociate this token.
        int64 dissociationResponseCode = IHederaTokenService(HTS_ADDRESS).dissociateToken(bob, USDC);
        assertEq(dissociationResponseCode, HederaResponseCodes.SUCCESS);
        assertFalse(IHRC719(USDC).isAssociated());

        // Associate multiple tokens at once.
        assertFalse(IHRC719(MFCT).isAssociated());

        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = MFCT;
        int64 multiAssociateResponseCode = IHederaTokenService(HTS_ADDRESS).associateTokens(bob, tokens);
        assertEq(multiAssociateResponseCode, HederaResponseCodes.SUCCESS);
        assertTrue(IHRC719(USDC).isAssociated());
        assertTrue(IHRC719(MFCT).isAssociated());

        // Dissociate multiple tokens at once.
        int64 multiDissociateResponseCode = IHederaTokenService(HTS_ADDRESS).dissociateTokens(bob, tokens);
        assertEq(multiDissociateResponseCode, HederaResponseCodes.SUCCESS);
        assertFalse(IHRC719(USDC).isAssociated());
        assertFalse(IHRC719(MFCT).isAssociated());

        vm.stopPrank();
    }

    function test_HTS_associations_without_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        vm.expectRevert();
        IHederaTokenService(HTS_ADDRESS).associateToken(bob, USDC);
    }

    function test_HTS_dissociation_without_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        vm.expectRevert();
        IHederaTokenService(HTS_ADDRESS).dissociateToken(bob, USDC);
    }

    function test_HTS_mass_associations_without_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = MFCT;
        vm.expectRevert();
        IHederaTokenService(HTS_ADDRESS).associateTokens(bob, tokens);
    }

    function test_HTS_mass_dissociation_without_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = MFCT;
        vm.expectRevert();
        IHederaTokenService(HTS_ADDRESS).dissociateTokens(bob, tokens);
    }

    function test_HTS_get_fungible_token_info() external view {
        (int64 fungibleResponseCode, IHederaTokenService.FungibleTokenInfo memory fungibleTokenInfo)
            = IHederaTokenService(HTS_ADDRESS).getFungibleTokenInfo(USDC);
        assertEq(fungibleResponseCode, HederaResponseCodes.SUCCESS);
        assertEq(fungibleTokenInfo.decimals, 6);
        assertEq(fungibleTokenInfo.tokenInfo.token.name, "USD Coin");
        assertEq(fungibleTokenInfo.tokenInfo.token.symbol, "USDC");
        assertEq(fungibleTokenInfo.tokenInfo.token.treasury, address(0x0000000000000000000000000000000000001438));
        assertEq(fungibleTokenInfo.tokenInfo.token.memo, "USDC HBAR");
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenSupplyType, false);
        assertEq(fungibleTokenInfo.tokenInfo.token.maxSupply, 0);
        assertEq(fungibleTokenInfo.tokenInfo.token.freezeDefault, false);
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys.length, 7);

        // AdminKey
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[0].keyType, 0x1);
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.inheritAccountKey, false);
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.contractId, address(0));
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.ed25519, hex"5db29fb3f19f8618cc4689cf13e78a935621845d67547719faf49f65d5c367cc");
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.ECDSA_secp256k1, bytes(""));
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.delegatableContractId, address(0));
        // FreezeKey
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[2].keyType, 0x4);
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[2].key.inheritAccountKey, false);
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[2].key.contractId, address(0));
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[2].key.ed25519, hex"baa2dd1684d8445d41b22f2b2c913484a7d885cf25ce525f8bf3fe8d5c8cb85d");
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[2].key.ECDSA_secp256k1, bytes(""));
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[2].key.delegatableContractId, address(0));
        // SupplyKey
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[4].keyType, 0x10);
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[4].key.inheritAccountKey, false);
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[4].key.contractId, address(0));
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[4].key.ed25519, hex"4e4658983980d1b25a634eeeb26cb2b0f0e2e9c83263ba5b056798d35f2139a8");
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[4].key.ECDSA_secp256k1, bytes(""));
        assertEq(fungibleTokenInfo.tokenInfo.token.tokenKeys[4].key.delegatableContractId, address(0));
        // Expiry
        assertEq(fungibleTokenInfo.tokenInfo.token.expiry.second, 1706825707000718000);
        assertEq(fungibleTokenInfo.tokenInfo.token.expiry.autoRenewAccount, address(0));
        assertEq(fungibleTokenInfo.tokenInfo.token.expiry.autoRenewPeriod, 0);
        assertEq(fungibleTokenInfo.tokenInfo.totalSupply, 10000000005000000);
        assertEq(fungibleTokenInfo.tokenInfo.deleted, false);
        assertEq(fungibleTokenInfo.tokenInfo.defaultKycStatus, false);
        assertEq(fungibleTokenInfo.tokenInfo.pauseStatus, false);
        assertEq(fungibleTokenInfo.tokenInfo.fixedFees.length, 0);
        assertEq(fungibleTokenInfo.tokenInfo.fractionalFees.length, 0);
        assertEq(fungibleTokenInfo.tokenInfo.royaltyFees.length, 0);
        assertEq(fungibleTokenInfo.tokenInfo.ledgerId, testMode == TestMode.FFI ? "0x01" : "0x00");
    }

    function test_HTS_get_non_fungible_token_info() external view {
        (int64 nonFungibleResponseCode, IHederaTokenService.NonFungibleTokenInfo memory nonFungibleTokenInfo)
            = IHederaTokenService(HTS_ADDRESS).getNonFungibleTokenInfo(CFNFTFF, int64(1));
        assertEq(nonFungibleResponseCode, HederaResponseCodes.SUCCESS);
        assertEq(nonFungibleTokenInfo.serialNumber, int64(1));
        assertEq(nonFungibleTokenInfo.ownerId, CFNFTFF_TREASURY);
        assertEq(nonFungibleTokenInfo.spenderId, CFNFTFF_ALLOWED_SPENDER);
        assertEq(nonFungibleTokenInfo.tokenInfo.token.name, "Custom Fee NFT (Fixed Fee)");
        assertEq(nonFungibleTokenInfo.tokenInfo.token.symbol, "CFNFTFF");
        assertEq(nonFungibleTokenInfo.tokenInfo.token.treasury, CFNFTFF_TREASURY);
        assertEq(nonFungibleTokenInfo.tokenInfo.token.memo, "");
        assertEq(nonFungibleTokenInfo.tokenInfo.token.tokenSupplyType, true);
        assertEq(nonFungibleTokenInfo.tokenInfo.token.maxSupply, 2);
        assertEq(nonFungibleTokenInfo.tokenInfo.token.freezeDefault, false);
        assertEq(nonFungibleTokenInfo.tokenInfo.token.tokenKeys.length, 7);

        // AdminKey
        assertEq(nonFungibleTokenInfo.tokenInfo.token.tokenKeys[0].keyType, 0x1);
        assertEq(nonFungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.inheritAccountKey, false);
        assertEq(nonFungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.contractId, address(0));
        assertEq(nonFungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.ed25519, bytes(""));
        assertEq(nonFungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.ECDSA_secp256k1, hex"0242b7c3beea2af6dfcc874c41d1332463407e283f602ce8ef2cbe324823561b6f");
        assertEq(nonFungibleTokenInfo.tokenInfo.token.tokenKeys[0].key.delegatableContractId, address(0));

        // Expiry
        assertEq(nonFungibleTokenInfo.tokenInfo.token.expiry.autoRenewAccount, address(0));
        assertEq(nonFungibleTokenInfo.tokenInfo.totalSupply, 2);
        assertEq(nonFungibleTokenInfo.tokenInfo.deleted, false);
        assertEq(nonFungibleTokenInfo.tokenInfo.defaultKycStatus, false);
        assertEq(nonFungibleTokenInfo.tokenInfo.pauseStatus, false);
        assertEq(nonFungibleTokenInfo.tokenInfo.fixedFees.length, 0);
        assertEq(nonFungibleTokenInfo.tokenInfo.fractionalFees.length, 0);
        assertEq(nonFungibleTokenInfo.tokenInfo.royaltyFees.length, 0);
        assertEq(nonFungibleTokenInfo.tokenInfo.ledgerId, testMode == TestMode.FFI ? "0x01" : "0x00");
    }

    function test_HTS_transferToken() external {
        // https://hashscan.io/testnet/account/0.0.1421
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address to = makeAddr("bob");
        uint256 amount = 4_000000;

        uint256 balanceOfOwner = IERC20(USDC).balanceOf(owner);
        assertGt(balanceOfOwner, 0);
        assertEq(IERC20(USDC).balanceOf(to), 0);

        vm.prank(owner);
        vm.expectEmit(USDC);
        emit IERC20.Transfer(owner, to, amount);
        IHederaTokenService(HTS_ADDRESS).transferToken(USDC, owner, to, int64(int256(amount)));

        assertEq(IERC20(USDC).balanceOf(owner), balanceOfOwner - amount);
        assertEq(IERC20(USDC).balanceOf(to), amount);
    }

    function test_HTS_transferFrom() external {
        // https://hashscan.io/testnet/account/0.0.1421
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address to = makeAddr("bob");
        uint256 amount = 4_000000;

        uint256 balanceOfOwner = IERC20(USDC).balanceOf(owner);
        assertGt(balanceOfOwner, 0);
        assertEq(IERC20(USDC).balanceOf(to), 0);

        vm.prank(owner);
        vm.expectEmit(USDC);
        emit IERC20.Transfer(owner, to, amount);
        IHederaTokenService(HTS_ADDRESS).transferFrom(USDC, owner, to, amount);

        assertEq(IERC20(USDC).balanceOf(owner), balanceOfOwner - amount);
        assertEq(IERC20(USDC).balanceOf(to), amount);
    }

    function test_HTS_transferToken_insufficient_balance() external {
        // https://hashscan.io/testnet/account/0.0.1421
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        uint256 amount = 300_000000;
        address to = makeAddr("bob");
        uint256 balanceOfOwner = IERC20(USDC).balanceOf(owner);
        assertGt(balanceOfOwner, 0);
        assertEq(IERC20(USDC).balanceOf(to), 0);
        vm.prank(owner);
        vm.expectRevert();
        IHederaTokenService(HTS_ADDRESS).transferFrom(USDC, owner, to, amount);
    }

    function test_HTS_transferNFT() external {
        address to = makeAddr("recipient");
        uint256 serialId = 1;
        vm.startPrank(CFNFTFF_TREASURY);
        vm.expectEmit(CFNFTFF);
        emit IERC721.Transfer(CFNFTFF_TREASURY, to, serialId);
        IHederaTokenService(HTS_ADDRESS).transferNFT(CFNFTFF, CFNFTFF_TREASURY, to, int64(int256(serialId)));
        vm.stopPrank();
        assertEq(IERC721(CFNFTFF).ownerOf(serialId), to);
    }

    function test_HTS_transferFromNFT() external {
        address to = makeAddr("recipient");
        uint256 serialId = 1;
        vm.startPrank(CFNFTFF_TREASURY);
        vm.expectEmit(CFNFTFF);
        emit IERC721.Transfer(CFNFTFF_TREASURY, to, serialId);
        IHederaTokenService(HTS_ADDRESS).transferFromNFT(CFNFTFF, CFNFTFF_TREASURY, to, serialId);
        vm.stopPrank();
        assertEq(IERC721(CFNFTFF).ownerOf(serialId), to);
    }

    function test_HTS_transferTokens_success() public {
        // https://hashscan.io/testnet/account/0.0.1421
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address[] memory to = new address[](1);
        to[0] = makeAddr("bob");
        uint256 amount = 4_000000;
        int64[] memory amounts = new int64[](1);
        amounts[0] = int64(int256(amount));

        uint256 balanceOfOwner = IERC20(USDC).balanceOf(owner);
        assertGt(balanceOfOwner, 0);
        assertEq(IERC20(USDC).balanceOf(to[0]), 0);

        vm.prank(owner);
        vm.expectEmit(USDC);
        emit IERC20.Transfer(owner, to[0], amount);
        IHederaTokenService(HTS_ADDRESS).transferTokens(USDC, to, amounts);

        assertEq(IERC20(USDC).balanceOf(owner), balanceOfOwner - amount);
        assertEq(IERC20(USDC).balanceOf(to[0]), amount);
    }

    function test_HTS_transferTokens_invalid_token_address() public {
        // https://hashscan.io/testnet/account/0.0.1421
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address[] memory to = new address[](1);
        to[0] = makeAddr("bob");
        int64[] memory amounts = new int64[](1);
        amounts[0] = 4_000000;
        vm.prank(owner);
        vm.expectRevert("getTokenInfo: invalid token");
        IHederaTokenService(HTS_ADDRESS).transferTokens(address(0), to, amounts);
    }

    function test_HTS_transferTokens_inconsistent_input() public {
        // https://hashscan.io/testnet/account/0.0.1421
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address[] memory to = new address[](1);
        to[0] = makeAddr("bob");
        int64[] memory amounts = new int64[](2);
        amounts[0] = 3_000000;
        amounts[1] = 1_000000;
        vm.prank(owner);
        vm.expectRevert("transferTokens: inconsistent input");
        IHederaTokenService(HTS_ADDRESS).transferTokens(USDC, to, amounts);
    }

    function test_HTS_transferTokens_missing_recipients() public {
        // https://hashscan.io/testnet/account/0.0.1421
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address[] memory to = new address[](0);
        int64[] memory amounts = new int64[](1);
        amounts[0] = 3_000000;
        vm.prank(owner);
        vm.expectRevert("transferTokens: missing recipients");
        IHederaTokenService(HTS_ADDRESS).transferTokens(USDC, to, amounts);
    }

    function test_HTS_transferNFTs_for_allowed_user() external {
        uint256[] memory serialId = new uint256[](1);
        serialId[0] = 1;
        address[] memory from = new address[](1);
        from[0] = CFNFTFF_TREASURY;
        address[] memory to = new address[](1);
        to[0] = makeAddr("recipient");
        vm.startPrank(CFNFTFF_TREASURY);
        vm.expectEmit(CFNFTFF);
        emit IERC721.Transfer(CFNFTFF_TREASURY, to[0], serialId[0]);
        IHederaTokenService(HTS_ADDRESS).transferNFT(CFNFTFF, from[0], to[0], int64(int256(serialId[0])));
        vm.stopPrank();
        assertEq(IERC721(CFNFTFF).ownerOf(serialId[0]), to[0]);
    }

    function test_HTS_transferNFT_fail_when_not_allowed() external {
        address from = makeAddr("bob");
        address to = makeAddr("recipient");
        uint256 serialId = 2;
        vm.startPrank(from);
        vm.expectRevert();
        IHederaTokenService(HTS_ADDRESS).transferNFT(CFNFTFF, from, to, int64(int256(serialId)));
        vm.stopPrank();
    }

    function test_HTS_allowance_from_remote() external view {
        // https://hashscan.io/testnet/account/0.0.4233295
        address owner = address(0x000000000000000000000000000000000040984F);
        // https://hashscan.io/testnet/account/0.0.1335
        address spender = 0x0000000000000000000000000000000000000537;
        (int64 responseCode, uint256 allowance) = IHederaTokenService(HTS_ADDRESS).allowance(USDC, owner, spender);
        assertEq(responseCode, HederaResponseCodes.SUCCESS);
        assertEq(allowance, 5_000000);
    }

    function test_HTS_allowance_empty() external {
        // https://hashscan.io/testnet/account/0.0.4233295
        address owner = address(0x000000000000000000000000000000000040984F);
        address spender = makeAddr("alice");
        (int64 responseCode, uint256 allowance) = IHederaTokenService(HTS_ADDRESS).allowance(USDC, owner, spender);
        assertEq(responseCode, HederaResponseCodes.SUCCESS);
        assertEq(allowance, 0);
    }

    function test_HTS_approveNFT() external {
        address token = CFNFTFF;
        address newSpender = makeAddr("NEW_SPENDER");
        assertNotEq(IERC721(token).getApproved(1), newSpender);
        vm.prank(CFNFTFF_TREASURY);
        vm.expectEmit(token);
        emit IERC721.Approval(CFNFTFF_TREASURY, newSpender, 1);
        int64 responseCodeApprove = IHederaTokenService(HTS_ADDRESS).approveNFT(token, newSpender, 1);
        assertEq(responseCodeApprove, HederaResponseCodes.SUCCESS);
        assertEq(IERC721(token).getApproved(1), newSpender);
    }

    function test_HTS_approve() external {
        address owner = makeAddr("alice");
        address spender = makeAddr("bob");
        uint256 amount = 4_000000;
        assertEq(IERC20(USDC).allowance(owner, spender), 0);
        vm.prank(owner);
        vm.expectEmit(USDC);
        emit IERC20.Approval(owner, spender, amount);
        int64 responseCodeApprove = IHederaTokenService(HTS_ADDRESS).approve(USDC, spender, amount);
        assertEq(responseCodeApprove, HederaResponseCodes.SUCCESS);
        assertEq(IERC20(USDC).allowance(owner, spender), amount);
    }

    function test_HTS_setIsApprovedForAll() external {
        address operator = makeAddr("operator");
        assertFalse(IERC721(CFNFTFF).isApprovedForAll(CFNFTFF_TREASURY, operator));
        vm.prank(CFNFTFF_TREASURY);
        vm.expectEmit(CFNFTFF);
        emit IERC721.ApprovalForAll(CFNFTFF_TREASURY, operator, true);
        int64 setApprovalForAllResponseCode = IHederaTokenService(HTS_ADDRESS)
            .setApprovalForAll(CFNFTFF, operator, true);
        assertEq(setApprovalForAllResponseCode, HederaResponseCodes.SUCCESS);
        assertTrue(IERC721(CFNFTFF).isApprovedForAll(CFNFTFF_TREASURY, operator));
    }

    function test_HTS_cryptoTransfer() external {
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address bob = makeAddr("bob");
        address alice = makeAddr("alice");
        uint256 amountToBob = 1_000000;
        uint256 amountToAlice = 3_000000;
        address token = USDC;
        IHederaTokenService.AccountAmount memory transfer1 = IHederaTokenService.AccountAmount(
            owner,
            -int64(uint64(amountToBob + amountToAlice)),
            false
        );
        IHederaTokenService.AccountAmount memory transfer2 = IHederaTokenService.AccountAmount(
            bob,
            int64(uint64(amountToBob)),
            false
        );
        IHederaTokenService.AccountAmount memory transfer3 = IHederaTokenService.AccountAmount(
            alice,
            int64(uint64(amountToAlice)),
            false
        );
        IHederaTokenService.TokenTransferList[] memory tokenTransfers = new IHederaTokenService.TokenTransferList[](1);
        IHederaTokenService.TransferList memory hbarTransfers;
        IHederaTokenService.AccountAmount[] memory transfers = new IHederaTokenService.AccountAmount[](3);
        tokenTransfers[0] = IHederaTokenService.TokenTransferList(
            token,
            transfers,
            new IHederaTokenService.NftTransfer[](0)
        );
        tokenTransfers[0].transfers[0] = transfer1;
        tokenTransfers[0].transfers[1] = transfer2;
        tokenTransfers[0].transfers[2] = transfer3;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, token);
        emit IERC20.Transfer(owner, bob, amountToBob);
        vm.expectEmit(true, true, true, true, token);
        emit IERC20.Transfer(owner, alice, amountToAlice);
        int64 responseCode = IHederaTokenService(HTS_ADDRESS).cryptoTransfer(hbarTransfers, tokenTransfers);
        assertEq(responseCode, HederaResponseCodes.SUCCESS);
        assertEq(IERC20(token).balanceOf(bob), amountToBob);
        assertEq(IERC20(token).balanceOf(alice), amountToAlice);
    }

    function test_HTS_cryptoTransfer_non_payable_hbar_transfer_without_vm_cheats_fail() external {
        vm.skip(testMode != TestMode.JSON_RPC);
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address recipient = makeAddr("recipient1");
        uint256 amount = 1 ether;
        IHederaTokenService.AccountAmount memory transferFrom = IHederaTokenService.AccountAmount(
            owner,
            -int64(uint64(amount)),
            false
        );
        IHederaTokenService.AccountAmount memory transferTo = IHederaTokenService.AccountAmount(
            recipient,
            int64(uint64(amount)),
            false
        );
        IHederaTokenService.TransferList memory transferList;
        transferList.transfers = new IHederaTokenService.AccountAmount[](2);
        transferList.transfers[0] = transferFrom;
        transferList.transfers[1] = transferTo;
        vm.deal(owner, amount + 100);
        vm.prank(owner);
        vm.expectRevert("cryptoTransfer: hbar transfer is not supported without vm cheatcodes in forked network");
        IHederaTokenService(HTS_ADDRESS).cryptoTransfer(
            transferList,
            new IHederaTokenService.TokenTransferList[](0)
        );
    }

    function test_HTS_cryptoTransfer_hbar() external {
        vm.skip(testMode == TestMode.JSON_RPC);
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        uint256 hbarToRecipient1 = 1 ether;
        uint256 hbarToRecipient2 = 2 ether;
        IHederaTokenService.AccountAmount memory transfer1 = IHederaTokenService.AccountAmount(
            owner,
            -int64(uint64(hbarToRecipient1 + hbarToRecipient2)),
            false
        );
        IHederaTokenService.AccountAmount memory transfer2 = IHederaTokenService.AccountAmount(
            recipient1,
            int64(uint64(hbarToRecipient1)),
            false
        );
        IHederaTokenService.AccountAmount memory transfer3 = IHederaTokenService.AccountAmount(
            recipient2,
            int64(uint64(hbarToRecipient2)),
            false
        );
        IHederaTokenService.TransferList memory transferList;
        transferList.transfers = new IHederaTokenService.AccountAmount[](3);
        transferList.transfers[0] = transfer1;
        transferList.transfers[1] = transfer2;
        transferList.transfers[2] = transfer3;
        vm.deal(owner, hbarToRecipient1 + hbarToRecipient2 + 100);
        uint256 initialOwnerBalance = address(owner).balance;
        uint256 initialRecipient1Balance = address(recipient1).balance;
        uint256 initialRecipient2Balance = address(recipient2).balance;
        assertGt(initialOwnerBalance, hbarToRecipient1 + hbarToRecipient2);
        assertEq(initialRecipient1Balance, 0);
        assertEq(initialRecipient2Balance, 0);
        vm.prank(owner);
        int64 code = IHederaTokenService(HTS_ADDRESS).cryptoTransfer(
            transferList,
            new IHederaTokenService.TokenTransferList[](0)
        );
        assertEq(code, HederaResponseCodes.SUCCESS);

        assertEq(address(recipient1).balance, initialRecipient1Balance + hbarToRecipient1);
        assertEq(address(recipient2).balance, initialRecipient2Balance + hbarToRecipient2);
        assertEq(address(owner).balance, initialOwnerBalance - hbarToRecipient1 - hbarToRecipient2);
    }

    function test_HTS_cryptoTransfer_test_invalid_sender() external {
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");
        uint256 hbarToRecipient = 1 ether;
        IHederaTokenService.AccountAmount memory transfer1 = IHederaTokenService.AccountAmount(
            sender,
            -int64(uint64(hbarToRecipient)),
            false
        );
        IHederaTokenService.AccountAmount memory transfer2 = IHederaTokenService.AccountAmount(
            recipient,
            int64(uint64(hbarToRecipient)),
            false
        );
        IHederaTokenService.TransferList memory transferList;
        transferList.transfers = new IHederaTokenService.AccountAmount[](2);
        transferList.transfers[0] = transfer1;
        transferList.transfers[1] = transfer2;
        vm.deal(owner, hbarToRecipient);
        vm.deal(sender, hbarToRecipient);
        vm.prank(owner);
        int64 code = IHederaTokenService(HTS_ADDRESS).cryptoTransfer(
            transferList,
            new IHederaTokenService.TokenTransferList[](0)
        );
        assertEq(code, HederaResponseCodes.SPENDER_DOES_NOT_HAVE_ALLOWANCE);
    }

    function test_HTS_cryptoTransfer_test_reject_insufficient_balance() external {
        address owner = 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15;
        address recipient = makeAddr("recipient");
        uint256 hbarToRecipient = 1 ether;
        vm.deal(owner, 0.5 ether); // Not enough
        IHederaTokenService.AccountAmount memory transfer1 = IHederaTokenService.AccountAmount(
            owner,
            -int64(uint64(hbarToRecipient)),
            false
        );
        IHederaTokenService.AccountAmount memory transfer2 = IHederaTokenService.AccountAmount(
            recipient,
            int64(uint64(hbarToRecipient)),
            false
        );
        IHederaTokenService.TransferList memory transferList;
        transferList.transfers = new IHederaTokenService.AccountAmount[](2);
        transferList.transfers[0] = transfer1;
        transferList.transfers[1] = transfer2;
        vm.prank(owner);
        int64 code = IHederaTokenService(HTS_ADDRESS).cryptoTransfer(
            transferList,
            new IHederaTokenService.TokenTransferList[](0)
        );
        assertEq(code, HederaResponseCodes.INSUFFICIENT_ACCOUNT_BALANCE);
    }
}
