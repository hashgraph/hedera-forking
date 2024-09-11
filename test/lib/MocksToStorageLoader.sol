// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "../../src/IERC20.sol";
import {HtsSystemContract} from "../../src/HtsSystemContract.sol";

contract MocksToStorageLoader is CommonBase, StdCheats {
    using stdStorage for StdStorage;

    address HTS;

    constructor(address _HTS) {
        HTS = _HTS;
    }

    function _assignStringToSlot(address target, uint256 startingSlot, string memory value) private {
        if (bytes(value).length <= 31) {
            bytes32 rightPaddedSymbol;
            assembly {
                rightPaddedSymbol := mload(add(value, 32))
            }
            bytes32 storageSlotValue = bytes32(bytes(value).length * 2) | rightPaddedSymbol;
            vm.store(target, bytes32(startingSlot), storageSlotValue);
            return;
        }

        bytes memory valueBytes = bytes(value);
        uint256 length = bytes(value).length;
        bytes32 lengthLeftPadded = bytes32(length * 2 + 1);
        vm.store(target, bytes32(startingSlot), lengthLeftPadded);
        uint256 numChunks = (length + 31) / 32;
        bytes32 baseSlot = keccak256(abi.encodePacked(startingSlot));

        for (uint256 i = 0; i < numChunks; i++) {
            bytes32 chunk;
            uint256 chunkStart = i * 32;
            uint256 chunkEnd = chunkStart + 32;

            if (chunkEnd > length) {
                chunkEnd = length;
            }

            for (uint256 j = chunkStart; j < chunkEnd; j++) {
                chunk |= bytes32(valueBytes[j]) >> (8 * (j - chunkStart));
            }

            vm.store(target, bytes32(uint256(baseSlot) + i), chunk);
        }
    }

    function _loadAccountData(address account) private {
        string memory path = string.concat("./test/data/getAccount_", vm.toLowercase(vm.toString(account)), ".json");
        uint256 accountId;
        if (vm.isFile(path)) {
            string memory json = vm.readFile(path);
            accountId = vm.parseUint(vm.replace(abi.decode(vm.parseJson(json, ".account"), (string)), "0.0.", ""));
        } else {
            accountId = uint160(account);
        }
        assignEvmAccountAddress(account, accountId);
    }

    function _deployTokenProxyBytecode(address tokenAddress) private {
        string memory placeholder = "fefefefefefefefefefefefefefefefefefefefe";
        string memory bytecodePath = string.concat("./test/lib/HIP719.bytecode");
        string memory addressString = vm.replace(vm.toLowercase(vm.toString(tokenAddress)), "0x", "");
        string memory updatedBytecode = vm.replace(vm.readFile(bytecodePath), placeholder, addressString);
        vm.etch(tokenAddress, vm.parseBytes(updatedBytecode));
    }

    function _loadTokenData(address tokenAddress, string memory tokenSymbol) private {
        _deployTokenProxyBytecode(tokenAddress);
        string memory path = string.concat("./test/data/", tokenSymbol, "/getToken.json");
        string memory json = vm.readFile(path);
        string memory name = abi.decode(vm.parseJson(json, ".name"), (string));
        uint256 decimals = uint8(vm.parseUint(abi.decode(vm.parseJson(json, ".decimals"), (string))));
        string memory symbol = abi.decode(vm.parseJson(json, ".symbol"), (string));
        uint256 totalSupply = vm.parseUint(abi.decode(vm.parseJson(json, ".total_supply"), (string)));

        stdstore
            .target(tokenAddress)
            .sig(IERC20.decimals.selector)
            .checked_write(decimals);
        stdstore
            .target(tokenAddress)
            .sig(IERC20.totalSupply.selector)
            .checked_write(totalSupply);

        _assignStringToSlot(tokenAddress, 0, name);
        _assignStringToSlot(tokenAddress, 1, symbol);
    }

    function _loadAllowancesOfAnAccount(address tokenAddress, string memory tokenSymbol, address ownerEVMAddress, address spenderEVMAddress) private {
        uint256 ownerId = HtsSystemContract(HTS).getAccountId(ownerEVMAddress);
        uint256 spenderId = HtsSystemContract(HTS).getAccountId(spenderEVMAddress);
        string memory path = string.concat("./test/data/", tokenSymbol, "/getAllowanceForToken_0.0.", vm.toString(ownerId), "_0.0.", vm.toString(spenderId), ".json");
        uint256 allowance = 0;

        try vm.readFile(path) returns (string memory json) {
            if (vm.keyExistsJson(json, ".allowances[0].amount")) {
                allowance = abi.decode(vm.parseJson(json, ".allowances[0].amount"), (uint256));
            }
        } catch {
            console.log(string.concat("Allowances are not configured for token ", tokenSymbol, " in path", path));
        }

        // This bit is written using the `stdStorage` library explicitly
        // instead of chaining methods to avoid `Stack too deep` error:
        //
        // ```
        // CompilerError: Stack too deep.
        // Try compiling with `--via-ir` (cli) or the equivalent `viaIR: true` (standard JSON) while enabling the optimizer.
        // Otherwise, try removing local variables.
        // ```
        stdStorage.target(stdstore, tokenAddress);
        stdStorage.sig(stdstore, IERC20.allowance.selector);
        stdStorage.with_key(stdstore, ownerEVMAddress);
        stdStorage.with_key(stdstore, spenderEVMAddress);
        stdStorage.checked_write(stdstore, allowance);
    }

    function _loadBalanceOfAnAccount(address tokenAddress, string memory tokenSymbol, address accountEVMAddress) private {
        uint256 accountId = HtsSystemContract(HTS).getAccountId(accountEVMAddress);
        string memory accountIdString = vm.toString(accountId);
        string memory path = string.concat("./test/data/", tokenSymbol, "/getBalanceOfToken_0.0.", accountIdString, ".json");
        uint256 balance = 0;

        try vm.readFile(path) returns (string memory json) {
            if (vm.keyExistsJson(json, ".balances[0].balance")) {
                balance = abi.decode(vm.parseJson(json, ".balances[0].balance"), (uint256));
            }
        } catch {
            console.log(string.concat("Balances are not configured for token ", tokenSymbol, " in path", path));
        }

        stdstore
            .target(tokenAddress)
            .sig(IERC20.balanceOf.selector)
            .with_key(accountEVMAddress)
            .checked_write(balance);
    }

    function assignEvmAccountAddress(address account, uint256 accountId) public {
        stdstore
            .target(HTS)
            .sig(HtsSystemContract.getAccountId.selector)
            .with_key(account)
            .checked_write(accountId);
    }

    function loadHts() external {
        deployCodeTo("HtsSystemContract.sol", HTS);
        _loadAccountData(0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15);
        _loadAccountData(0x0000000000000000000000000000000000000887);
        _loadAccountData(0x0000000000000000000000000000000000000537);
        _loadAccountData(0x000000000000000000000000000000000040984F);
    }

    function loadToken(address tokenAddress, string memory tokenSymbol) external {
        _loadTokenData(tokenAddress, tokenSymbol);
        _loadBalanceOfAnAccount(tokenAddress, tokenSymbol, 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15);
        _loadBalanceOfAnAccount(tokenAddress, tokenSymbol, 0x0000000000000000000000000000000000000887);
        _loadAllowancesOfAnAccount(tokenAddress, tokenSymbol, 0x000000000000000000000000000000000040984F, 0x0000000000000000000000000000000000000537);
    }
}
