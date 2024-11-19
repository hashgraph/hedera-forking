// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HtsSystemContract, HTS_ADDRESS} from "../src/HtsSystemContract.sol";
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

    function test_HTS_getTokenInfo_should_return_token_info_for_valid_token() external {
        if (TestMode.JSON_RPC == testMode) {
            // skip this test for the mock JSON-RPC (will be handled in another PR for the hardhat solution)
            return;
        }
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
        assertEq(tokenInfo.token.tokenKeys[0].key.ed25519, bytes("5db29fb3f19f8618cc4689cf13e78a935621845d67547719faf49f65d5c367cc"));
        assertEq(tokenInfo.token.tokenKeys[0].key.ECDSA_secp256k1, bytes(""));
        assertEq(tokenInfo.token.tokenKeys[0].key.delegatableContractId, address(0));
        // FreezeKey
        assertEq(tokenInfo.token.tokenKeys[2].keyType, 0x4);
        assertEq(tokenInfo.token.tokenKeys[2].key.inheritAccountKey, false);
        assertEq(tokenInfo.token.tokenKeys[2].key.contractId, address(0));
        assertEq(tokenInfo.token.tokenKeys[2].key.ed25519, bytes("baa2dd1684d8445d41b22f2b2c913484a7d885cf25ce525f8bf3fe8d5c8cb85d"));
        assertEq(tokenInfo.token.tokenKeys[2].key.ECDSA_secp256k1, bytes(""));
        assertEq(tokenInfo.token.tokenKeys[2].key.delegatableContractId, address(0));
        // SupplyKey
        assertEq(tokenInfo.token.tokenKeys[4].keyType, 0x10);
        assertEq(tokenInfo.token.tokenKeys[4].key.inheritAccountKey, false);
        assertEq(tokenInfo.token.tokenKeys[4].key.contractId, address(0));
        assertEq(string(tokenInfo.token.tokenKeys[4].key.ed25519), "4e4658983980d1b25a634eeeb26cb2b0f0e2e9c83263ba5b056798d35f2139a8");
        assertEq(string(tokenInfo.token.tokenKeys[4].key.ECDSA_secp256k1), "");
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

    function test_HTS_getTokenInfo_should_revert_for_invalid_token() external {
        address token = address(0);
        vm.expectRevert(bytes("getTokenInfo: invalid token"));
        HtsSystemContract(HTS_ADDRESS).getTokenInfo(token);
    }

    function test_HTS_getTokenInfo_should_revert_when_delegatecall() external {
        vm.expectRevert(bytes("htsCall: delegated call"));
        (bool revertsAsExpected, ) = HTS_ADDRESS.delegatecall(abi.encodeWithSelector(HtsSystemContract.getTokenInfo.selector, address(this)));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }
}
