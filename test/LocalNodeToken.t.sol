// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IERC20Events, IERC20} from "../src/IERC20.sol";
import {IHederaTokenService} from "../src/IHederaTokenService.sol";
import {TestSetup} from "./lib/TestSetup.sol";

interface MethodNotSupported {
    function methodNotSupported() external view returns (uint256);
}

/**
 * HTS for Fungible Token methods test.
 * Fungible Token must implement the ERC20 standard.
 *
 * These tests use USDC, an already existing HTS Token.
 *
 * Test based on issue https://github.com/hashgraph/hedera-smart-contracts/issues/863.
 *
 * For more details about USDC on Hedera, see https://www.circle.com/en/multi-chain-usdc/hedera.
 *
 * To get USDC balances for a given account using the Mirror Node you can use
 * https://mainnet.mirrornode.hedera.com/api/v1/tokens/0.0.456858/balances?account.id=0.0.38047
 */
contract LocalNodeTokenTest is Test, TestSetup, IERC20Events {
    address TOKEN_ADDRESS = 0x0000000000000000000000000000000000000408;
    address HTS_ADDRESS = 0x0000000000000000000000000000000000000167;
    function setUp() external {
        deployCodeTo("HtsSystemContractLocalNode.sol", address(HTS_ADDRESS));
        vm.allowCheatcodes(address(HTS_ADDRESS));

        //   setUpMockStorageForNonFork();
    }

    function test_ERC20_create() external {
        /*
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
vm.prank(address(this)); // Simulate the caller as this test contract

(int responseCode, address tokenAddress) =
IHederaTokenService(address(0x167)).createFungibleToken(
token,
        initialTotalSupply,
        decimals
);
assertEq(responseCode, 22);
*/
    }

    function test_ERC20_name() external {
        assertEq(IERC20(TOKEN_ADDRESS).name(), "MyToken");
    }

    function test_ERC20_decimals() external {
        assertEq(IERC20(TOKEN_ADDRESS).decimals(), uint256(2));
    }
}
