// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HtsSystemContract, HTS_ADDRESS} from "../contracts/HtsSystemContract.sol";
import {IHederaTokenService} from "../contracts/IHederaTokenService.sol";
import {IERC20} from "../contracts/IERC20.sol";
import {IHRC719} from "../contracts/IHRC719.sol";
import {TestSetup} from "./lib/TestSetup.sol";

contract HTSTest is Test, TestSetup {

    address private unknownUser;

    function setUp() external {
        setUpMockStorageForNonFork();

        unknownUser = makeAddr("unknown-user");
    }
/*
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

    function test_HTS_getTokenInfo_should_return_token_info_for_valid_token() external {
        address token = USDC;
        (int64 responseCode, HtsSystemContract.TokenInfo memory tokenInfo) = HtsSystemContract(HTS_ADDRESS).getTokenInfo(token);
        assertEq(responseCode, 22);
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
        // FreezeKey
        assertEq(tokenInfo.token.tokenKeys[2].keyType, 0x4);
        assertEq(tokenInfo.token.tokenKeys[2].key.inheritAccountKey, false);
        assertEq(tokenInfo.token.tokenKeys[2].key.contractId, address(0));
        assertEq(tokenInfo.token.tokenKeys[2].key.ed25519, hex"baa2dd1684d8445d41b22f2b2c913484a7d885cf25ce525f8bf3fe8d5c8cb85d");
        assertEq(tokenInfo.token.tokenKeys[2].key.ECDSA_secp256k1, bytes(""));
        assertEq(tokenInfo.token.tokenKeys[2].key.delegatableContractId, address(0));
        // SupplyKey
        assertEq(tokenInfo.token.tokenKeys[4].keyType, 0x10);
        assertEq(tokenInfo.token.tokenKeys[4].key.inheritAccountKey, false);
        assertEq(tokenInfo.token.tokenKeys[4].key.contractId, address(0));
        assertEq(tokenInfo.token.tokenKeys[4].key.ed25519, hex"4e4658983980d1b25a634eeeb26cb2b0f0e2e9c83263ba5b056798d35f2139a8");
        assertEq(tokenInfo.token.tokenKeys[4].key.ECDSA_secp256k1, bytes(""));
        assertEq(tokenInfo.token.tokenKeys[4].key.delegatableContractId, address(0));
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

    function test_HTS_getTokenInfo_should_return_custom_fees_for_valid_token() external {
        (int64 responseCode, HtsSystemContract.TokenInfo memory tokenInfo) = HtsSystemContract(HTS_ADDRESS).getTokenInfo(CTCF);
        assertEq(responseCode, 22);
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
        HtsSystemContract(HTS_ADDRESS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_for_invalid_token() external {
        address token = makeAddr("unknown-token");
        vm.expectRevert();
        HtsSystemContract(HTS_ADDRESS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_when_call_to_mirror_node_fails() external {
        if (TestMode.JSON_RPC == testMode) {
            // skip this test for the mock JSON-RPC, as it is not possible to simulate the mirror node error
            return;
        }

        address token = MFCT;
        vm.mockCallRevert(address(mirrorNode), abi.encode(mirrorNode.fetchTokenData.selector), abi.encode("mirror node error"));
        vm.expectRevert(abi.encode("mirror node error"));
        HtsSystemContract(HTS_ADDRESS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_when_delegatecall() external {
        vm.expectRevert(bytes("htsCall: delegated call"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.delegatecall(abi.encodeWithSelector(HtsSystemContract.getTokenInfo.selector, address(this)));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_HTS_getTokenInfo_should_revert_when_called_from_outside_of_HTS() external {
        address token = USDC;
        vm.expectRevert(bytes("redirectForToken: not supported"));
        HtsSystemContract(token).getTokenInfo(token);
    }

    function test_mintToken_should_succeed_with_valid_input() external {
        address token = USDC;
        address treasury = USDC_TREASURY;
        int64 amount = 1000;
        int64 initialTotalSupply = 10000000005000000;
        uint256 initialTreasuryBalance = IERC20(token).balanceOf(treasury);
        bytes[] memory metadata = new bytes[](0);

        (int64 responseCode, int64 newTotalSupply, int64[] memory serialNumbers) = HtsSystemContract(HTS_ADDRESS).mintToken(token, amount, metadata);
        assertEq(responseCode, 22);
        assertEq(serialNumbers.length, 0);
        assertEq(newTotalSupply, initialTotalSupply + amount);
        assertEq(IERC20(token).balanceOf(treasury), uint64(initialTreasuryBalance) + uint64(amount));
    }

    function test_mintToken_should_revert_with_invalid_treasureAccount() external {
        address token = USDC;
        int64 amount = 1000;
        bytes[] memory metadata = new bytes[](0);
        int64 initialTotalSupply = 10000000005000000;
        IHederaTokenService.TokenInfo memory tokenInfo;
        tokenInfo.token = IHederaTokenService.HederaToken(
            "USD Coin",
            "USDC",
            address(0),
            "USDC HBAR",
            false,
            initialTotalSupply + amount,
            false,
            new IHederaTokenService.TokenKey[](0),
            IHederaTokenService.Expiry(0, address(0), 0)
        );

        vm.mockCall(token, abi.encode(HtsSystemContract.getTokenInfo.selector), abi.encode(22, tokenInfo));
        vm.expectRevert(bytes("mintToken: invalid account"));
        HtsSystemContract(HTS_ADDRESS).mintToken(token, amount, metadata);
    }

    function test_mintToken_should_revert_with_invalid_token() external {
        address token = address(0);
        int64 amount = 1000;
        bytes[] memory metadata = new bytes[](0);

        vm.expectRevert(bytes("mintToken: invalid token"));
        HtsSystemContract(HTS_ADDRESS).mintToken(token, amount, metadata);
    }

    function test_mintToken_should_revert_with_invalid_amount() external {
        address token = address(0x123);
        int64 amount = 0;
        bytes[] memory metadata = new bytes[](0);

        vm.expectRevert(bytes("mintToken: invalid amount"));
        HtsSystemContract(HTS_ADDRESS).mintToken(token, amount, metadata);
    }

    function test_burnToken_should_succeed_with_valid_input() external {
        address token = MFCT;
        address treasury = MFCT_TREASURY;
        int64 amount = 1000;
        int64 initialTotalSupply = 5000;
        uint256 initialTreasuryBalance = IERC20(token).balanceOf(treasury);

        (int64 responseCodeMint, int64 newTotalSupplyAfterMint, int64[] memory serialNumbers) = HtsSystemContract(HTS_ADDRESS).mintToken(token, amount, new bytes[](0));
        assertEq(responseCodeMint, 22);
        assertEq(serialNumbers.length, 0);
        assertEq(newTotalSupplyAfterMint, initialTotalSupply + amount);
        assertEq(IERC20(token).balanceOf(treasury), uint64(initialTreasuryBalance) + uint64(amount));

        (int64 responseCodeBurn, int64 newTotalSupplyAfterBurn) = HtsSystemContract(HTS_ADDRESS).burnToken(token, amount, serialNumbers);
        assertEq(responseCodeBurn, 22);
        assertEq(newTotalSupplyAfterBurn, initialTotalSupply);
        assertEq(IERC20(token).balanceOf(treasury), uint64(initialTreasuryBalance));
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

        vm.mockCall(token, abi.encode(HtsSystemContract.getTokenInfo.selector), abi.encode(22, tokenInfo));
        vm.expectRevert(bytes("burnToken: invalid account"));
        HtsSystemContract(HTS_ADDRESS).burnToken(token, amount, serialNumbers);
    }

    function test_burnToken_should_revert_with_invalid_token() external {
        address token = address(0);
        int64 amount = 1000;
        int64[] memory serialNumbers = new int64[](0);

        vm.expectRevert(bytes("burnToken: invalid token"));
        HtsSystemContract(HTS_ADDRESS).burnToken(token, amount, serialNumbers);
    }

    function test_burnToken_should_revert_with_invalid_amount() external {
        address token = address(0x123);
        int64 amount = 0;
        int64[] memory serialNumbers = new int64[](0);

        vm.expectRevert(bytes("burnToken: invalid amount"));
        HtsSystemContract(HTS_ADDRESS).burnToken(token, amount, serialNumbers);
    }

    function test_HTS_getApproved_should_return_correct_address() external view {
        address token = CFNFTFF;
        (int64 responseCodeGetApproved, address approved) = HtsSystemContract(HTS_ADDRESS)
            .getApproved(token, 1);
        assertEq(responseCodeGetApproved, 22);
        assertEq(approved, CFNFTFF_ALLOWED_SPENDER);
    }

    function test_HTS_getApproved_should_return_nothing_when_no_approval_granted() external view {
        address token = CFNFTFF;
        (int64 responseCodeGetApproved, address approved) = HtsSystemContract(HTS_ADDRESS).getApproved(token, 2);
        assertEq(responseCodeGetApproved, 22);
        assertEq(approved, address(0));
    }

    function test_HTS_isApprovedForAll() view external {
        address token = CFNFTFF;
        (int64 isApprovedForAllResponseCode, bool isApproved) = HtsSystemContract(HTS_ADDRESS)
            .isApprovedForAll(token, CFNFTFF_TREASURY, CFNFTFF_ALLOWED_SPENDER);
        assertEq(isApprovedForAllResponseCode, 22);
        assertFalse(isApproved);
    }

    function test_HTS_getTokenCustomFees_should_return_custom_fees_for_valid_token() external {
        (
            int64 responseCode,
            HtsSystemContract.FixedFee[] memory fixedFees,
            HtsSystemContract.FractionalFee[] memory fractionalFees,
            HtsSystemContract.RoyaltyFee[] memory royaltyFees
        ) = HtsSystemContract(HTS_ADDRESS).getTokenCustomFees(CTCF);
        assertEq(responseCode, 22);

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

    function test_HTS_getTokenDefaultFreezeStatus_should_correct_value_for_valid_token() external {
        address token = CFNFTFF;
        (int64 freezeStatus, bool defaultFreeze) = HtsSystemContract(HTS_ADDRESS).getTokenDefaultFreezeStatus(token);
        assertEq(freezeStatus, 22);
        assertFalse(defaultFreeze);
    }

    function test_HTS_getTokenDefaultKycStatus_should_correct_value_for_valid_token() external {
        address token = CFNFTFF;
        (int64 kycStatus, bool defaultKyc) = HtsSystemContract(HTS_ADDRESS).getTokenDefaultKycStatus(token);
        assertEq(kycStatus, 22);
        assertFalse(defaultKyc);
    }

    function test_HTS_getTokenExpiryInfo_should_correct_value_for_valid_token() external {
        address token = CFNFTFF;
        (int64 expiryStatusCode, HtsSystemContract.Expiry memory expiry)
            = HtsSystemContract(HTS_ADDRESS).getTokenExpiryInfo(token);
        assertEq(expiryStatusCode, 22);
        assertEq(expiry.second, 1742724250000000000);
        assertEq(expiry.autoRenewAccount, address(0));
        assertEq(expiry.autoRenewPeriod, 0);
    }

    function test_HTS_getTokenKey_should_correct_key_value() external {
        address token = USDC;

        // AdminKey
        (int64 adminKeyStatusCode, HtsSystemContract.KeyValue memory adminKey)
            = HtsSystemContract(HTS_ADDRESS).getTokenKey(token, 0x1);
        assertEq(adminKeyStatusCode, 22);
        assertEq(adminKey.inheritAccountKey, false);
        assertEq(adminKey.contractId, address(0));
        assertEq(adminKey.ed25519, hex"5db29fb3f19f8618cc4689cf13e78a935621845d67547719faf49f65d5c367cc");
        assertEq(adminKey.ECDSA_secp256k1, bytes(""));
        assertEq(adminKey.delegatableContractId, address(0));
        // FreezeKey
        (int64 freezeKeyStatusCode, HtsSystemContract.KeyValue memory freezeKey)
            = HtsSystemContract(HTS_ADDRESS).getTokenKey(token, 0x4);
        assertEq(freezeKeyStatusCode, 22);
        assertEq(freezeKey.inheritAccountKey, false);
        assertEq(freezeKey.contractId, address(0));
        assertEq(freezeKey.ed25519, hex"baa2dd1684d8445d41b22f2b2c913484a7d885cf25ce525f8bf3fe8d5c8cb85d");
        assertEq(freezeKey.ECDSA_secp256k1, bytes(""));
        assertEq(freezeKey.delegatableContractId, address(0));
        // SupplyKey
        (int64 supplyKeyStatusCode, HtsSystemContract.KeyValue memory supplyKey)
            = HtsSystemContract(HTS_ADDRESS).getTokenKey(token, 0x10);
        assertEq(supplyKeyStatusCode, 22);
        assertEq(supplyKey.inheritAccountKey, false);
        assertEq(supplyKey.contractId, address(0));
        assertEq(supplyKey.ed25519, hex"4e4658983980d1b25a634eeeb26cb2b0f0e2e9c83263ba5b056798d35f2139a8");
        assertEq(supplyKey.ECDSA_secp256k1, bytes(""));
        assertEq(supplyKey.delegatableContractId, address(0));
    }

    function test_HTS_getTokenType_should_correct_token_type_for_existing_token() external {
        (int64 ftTypeStatusCode, int32 ftType) = HtsSystemContract(HTS_ADDRESS).getTokenType(USDC);
        assertEq(22, ftTypeStatusCode);
        assertEq(ftType, int32(0));

        (int64 nftTypeStatusCode, int32 nftType) = HtsSystemContract(HTS_ADDRESS).getTokenType(CFNFTFF);
        assertEq(22, nftTypeStatusCode);
        assertEq(nftType, int32(1));
    }

    function test_HTS_isToken_should_correct_is_token_info() external {
        (int64 ftIsTokenStatusCode, bool ftIsToken) = HtsSystemContract(HTS_ADDRESS).isToken(USDC);
        assertEq(22, ftIsTokenStatusCode);
        assertTrue(ftIsToken);

        (int64 nftIsTokenStatusCode, bool nftIsToken) = HtsSystemContract(HTS_ADDRESS).isToken(CFNFTFF);
        assertEq(22, nftIsTokenStatusCode);
        assertTrue(nftIsToken);

        (int64 accountIsTokenCode, bool accountIsToken) = HtsSystemContract(HTS_ADDRESS).isToken(CFNFTFF_TREASURY);
        assertEq(22, accountIsTokenCode);
        assertFalse(accountIsToken);

        (int64 randomIsTokenCode, bool randomIsToken) = HtsSystemContract(HTS_ADDRESS).isToken(address(123));
        assertEq(22, randomIsTokenCode);
        assertFalse(randomIsToken);
    } */

    function test_HTS_associations_with_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        vm.startPrank(bob);
        assertFalse(IHRC719(USDC).isAssociated());

        // Associate the token.
        int64 associationResponseCode = HtsSystemContract(HTS_ADDRESS).associateToken(bob, USDC);
        assertEq(associationResponseCode, 22);
        assertTrue(IHRC719(USDC).isAssociated());

        // Dissociate this token.
        int64 dissociationResponseCode = HtsSystemContract(HTS_ADDRESS).dissociateToken(bob, USDC);
        assertEq(associationResponseCode, 22);
        assertFalse(IHRC719(USDC).isAssociated());

        // Associate multiple tokens at once.
        assertFalse(IHRC719(MFCT).isAssociated());

        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = MFCT;
        int64 multiAssociateResponseCode = HtsSystemContract(HTS_ADDRESS).associateTokens(bob, tokens);
        assertEq(associationResponseCode, 22);
        assertTrue(IHRC719(USDC).isAssociated());
        assertTrue(IHRC719(MFCT).isAssociated());

        // Dissociate multiple tokens at once.
        int64 multiDissociateResponseCode = HtsSystemContract(HTS_ADDRESS).dissociateTokens(bob, tokens);
        assertEq(multiDissociateResponseCode, 22);
        assertFalse(IHRC719(USDC).isAssociated());
        assertFalse(IHRC719(MFCT).isAssociated());

        vm.stopPrank();
    }

    function test_HTS_associations_without_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        vm.expectRevert();
        HtsSystemContract(HTS_ADDRESS).associateToken(bob, USDC);
    }

    function test_HTS_dissociation_without_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        vm.expectRevert();
        HtsSystemContract(HTS_ADDRESS).dissociateToken(bob, USDC);
    }

    function test_HTS_mass_associations_without_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = MFCT;
        vm.expectRevert();
        HtsSystemContract(HTS_ADDRESS).associateTokens(bob, tokens);
    }

    function test_HTS_mass_dissociation_without_correct_privileges() external {
        address bob = CFNFTFF_TREASURY;
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = MFCT;
        vm.expectRevert();
        HtsSystemContract(HTS_ADDRESS).dissociateTokens(bob, tokens);
    }

    function test_HTS_get_fungible_token_info() external {
        (int64 fungibleResponseCode, HtsSystemContract.FungibleTokenInfo memory fungibleTokenInfo)
            = HtsSystemContract(HTS_ADDRESS).getFungibleTokenInfo(USDC);
        assertEq(fungibleResponseCode, 22);
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

    function test_HTS_get_non_fungible_token_info() external {
        (int64 nonFungibleResponseCode, HtsSystemContract.NonFungibleTokenInfo memory nonFungibleTokenInfo)
            = HtsSystemContract(HTS_ADDRESS).getNonFungibleTokenInfo(CFNFTFF, int64(1));
        assertEq(nonFungibleResponseCode, 22);
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
        assertEq(nonFungibleTokenInfo.tokenInfo.token.expiry.second, 1742724250000000000);
        assertEq(nonFungibleTokenInfo.tokenInfo.token.expiry.autoRenewAccount, address(0));
        assertEq(nonFungibleTokenInfo.tokenInfo.token.expiry.autoRenewPeriod, 0);
        assertEq(nonFungibleTokenInfo.tokenInfo.totalSupply, 2);
        assertEq(nonFungibleTokenInfo.tokenInfo.deleted, false);
        assertEq(nonFungibleTokenInfo.tokenInfo.defaultKycStatus, false);
        assertEq(nonFungibleTokenInfo.tokenInfo.pauseStatus, false);
        assertEq(nonFungibleTokenInfo.tokenInfo.fixedFees.length, 0);
        assertEq(nonFungibleTokenInfo.tokenInfo.fractionalFees.length, 0);
        assertEq(nonFungibleTokenInfo.tokenInfo.royaltyFees.length, 0);
        assertEq(nonFungibleTokenInfo.tokenInfo.ledgerId, testMode == TestMode.FFI ? "0x01" : "0x00");
    }
}
