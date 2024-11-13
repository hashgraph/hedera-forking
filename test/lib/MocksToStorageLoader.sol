// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "../../src/IERC20.sol";
import {HtsSystemContract} from "../../src/HtsSystemContract.sol";
import {HVM} from "../../src/HVM.sol";

contract MocksToStorageLoader is CommonBase, StdCheats {
    using stdStorage for StdStorage;
    using HVM for *;

    address HTS;

    constructor(address _HTS) {
        HTS = _HTS;
    }

    function _loadAccountData(address account) private {
        string memory path = string.concat("./@hts-forking/test/data/getAccount_", vm.toLowercase(vm.toString(account)), ".json");
        uint256 accountId;
        if (vm.isFile(path)) {
            string memory json = vm.readFile(path);
            accountId = vm.parseUint(vm.replace(abi.decode(vm.parseJson(json, ".account"), (string)), "0.0.", ""));
        } else {
            accountId = uint160(account);
        }
        assignEvmAccountAddress(account, accountId);
    }

    function _loadAccountData(uint256 accountNum) private {
        string memory path = string.concat("./@hts-forking/test/data/getAccount_0.0.", vm.toString(accountNum), ".json");
        address account;
        if (vm.isFile(path)) {
            string memory json = vm.readFile(path);
            account = abi.decode(vm.parseJson(json, ".evm_address"), (address));
        } else {
            account = address(uint160(accountNum));
        }
        assignAccountId(accountNum, account);
    }

    function _deployTokenProxyBytecode(address tokenAddress) private {
        string memory template = vm.replace(vm.trim(vm.readFile("./@hts-forking/src/HIP719.bytecode.json")), "\"", "");
        string memory placeholder = "fefefefefefefefefefefefefefefefefefefefe";
        string memory addressString = vm.replace(vm.toString(tokenAddress), "0x", "");
        string memory proxyBytecode = vm.replace(template, placeholder, addressString);
        vm.etch(tokenAddress, vm.parseBytes(proxyBytecode));
    }

    function _loadTokenData(address tokenAddress, string memory tokenSymbol) private {
        _deployTokenProxyBytecode(tokenAddress);
        string memory path = string.concat("./@hts-forking/test/data/", tokenSymbol, "/getToken.json");
        string memory json = vm.readFile(path);

        _loadBasicTokenData(tokenAddress, json);
        _loadTokenKeys(tokenAddress, json);
        _loadCustomFees(tokenAddress, json);
    }

    function _loadBasicTokenData(address tokenAddress, string memory json) private {
        HVM.storeString(tokenAddress, HVM.getSlot("name"), abi.decode(vm.parseJson(json, ".name"), (string)));
        HVM.storeString(tokenAddress, HVM.getSlot("symbol"), abi.decode(vm.parseJson(json, ".symbol"), (string)));
        HVM.storeUint(tokenAddress, HVM.getSlot("decimals"), vm.parseUint(abi.decode(vm.parseJson(json, ".decimals"), (string))));
        HVM.storeUint(tokenAddress, HVM.getSlot("totalSupply"), vm.parseUint(abi.decode(vm.parseJson(json, ".total_supply"), (string))));
        HVM.storeUint(tokenAddress, HVM.getSlot("maxSupply"), vm.parseUint(abi.decode(vm.parseJson(json, ".max_supply"), (string))));
        HVM.storeBool(tokenAddress, HVM.getSlot("freezeDefault"), abi.decode(vm.parseJson(json, ".freeze_default"), (bool)));
        HVM.storeString(tokenAddress, HVM.getSlot("supplyType"), abi.decode(vm.parseJson(json, ".supply_type"), (string)));
        HVM.storeString(tokenAddress, HVM.getSlot("pauseStatus"), abi.decode(vm.parseJson(json, ".pause_status"), (string)));
        HVM.storeUint(tokenAddress, HVM.getSlot("expiryTimestamp"), abi.decode(vm.parseJson(json, ".expiry_timestamp"), (uint)));
        HVM.storeString(tokenAddress, HVM.getSlot("autoRenewAccount"), abi.decode(vm.parseJson(json, ".auto_renew_account"), (string)));
        HVM.storeUint(tokenAddress, HVM.getSlot("autoRenewPeriod"), abi.decode(vm.parseJson(json, ".auto_renew_period"), (uint)));
        HVM.storeBool(tokenAddress, HVM.getSlot("deleted"), abi.decode(vm.parseJson(json, ".deleted"), (bool)));
        HVM.storeString(tokenAddress, HVM.getSlot("memo"), abi.decode(vm.parseJson(json, ".memo"), (string)));
        HVM.storeString(tokenAddress, HVM.getSlot("treasuryAccountId"), abi.decode(vm.parseJson(json, ".treasury_account_id"), (string)));
    }

    function _loadTokenKeys(address tokenAddress, string memory json) private {
        if (vm.keyExistsJson(json, ".admin_key")) {
            bytes memory encodedData = vm.parseJson(json, ".admin_key");
            if (keccak256(encodedData) != keccak256(abi.encodePacked(bytes32(0)))) {
                HtsSystemContract.IKey memory adminKey = abi.decode(encodedData, (HtsSystemContract.IKey));
                HVM.storeString(tokenAddress, HVM.getSlot("adminKey"), adminKey._type);
                HVM.storeString(tokenAddress, HVM.getSlot("adminKey") + 1, adminKey.key);
            }
        }
        if (vm.keyExistsJson(json, ".fee_schedule_key")) {
            bytes memory encodedData = vm.parseJson(json, ".fee_schedule_key");
            if (keccak256(encodedData) != keccak256(abi.encodePacked(bytes32(0)))) {
                HtsSystemContract.IKey memory feeScheduleKey = abi.decode(encodedData, (HtsSystemContract.IKey));
                HVM.storeString(tokenAddress, HVM.getSlot("feeScheduleKey"), feeScheduleKey._type);
                HVM.storeString(tokenAddress, HVM.getSlot("feeScheduleKey") + 1, feeScheduleKey.key);
            }
        }
        if (vm.keyExistsJson(json, ".freeze_key")) {
            bytes memory encodedData = vm.parseJson(json, ".freeze_key");
            if (keccak256(encodedData) != keccak256(abi.encodePacked(bytes32(0)))) {
                HtsSystemContract.IKey memory freezeKey = abi.decode(encodedData, (HtsSystemContract.IKey));
                HVM.storeString(tokenAddress, HVM.getSlot("freezeKey"), freezeKey._type);
                HVM.storeString(tokenAddress, HVM.getSlot("freezeKey") + 1, freezeKey.key);
            }
        }
        if (vm.keyExistsJson(json, ".kyc_key")) {
            bytes memory encodedData = vm.parseJson(json, ".kyc_key");
            if (keccak256(encodedData) != keccak256(abi.encodePacked(bytes32(0)))) {
                HtsSystemContract.IKey memory kycKey = abi.decode(encodedData, (HtsSystemContract.IKey));
                HVM.storeString(tokenAddress, HVM.getSlot("kycKey"), kycKey._type);
                HVM.storeString(tokenAddress, HVM.getSlot("kycKey") + 1, kycKey.key);
            }
        }
        if (vm.keyExistsJson(json, ".pause_key")) {
            bytes memory encodedData = vm.parseJson(json, ".pause_key");
            if (keccak256(encodedData) != keccak256(abi.encodePacked(bytes32(0)))) {
                HtsSystemContract.IKey memory pauseKey = abi.decode(encodedData, (HtsSystemContract.IKey));
                HVM.storeString(tokenAddress, HVM.getSlot("pauseKey"), pauseKey._type);
                HVM.storeString(tokenAddress, HVM.getSlot("pauseKey") + 1, pauseKey.key);
            }
        }
        if (vm.keyExistsJson(json, ".supply_key")) {
            bytes memory encodedData = vm.parseJson(json, ".supply_key");
            if (keccak256(encodedData) != keccak256(abi.encodePacked(bytes32(0)))) {
                HtsSystemContract.IKey memory supplyKey = abi.decode(encodedData, (HtsSystemContract.IKey));
                HVM.storeString(tokenAddress, HVM.getSlot("supplyKey"), supplyKey._type);
                HVM.storeString(tokenAddress, HVM.getSlot("supplyKey") + 1, supplyKey.key);
            }
        }
        if (vm.keyExistsJson(json, ".wipe_key")) {
            bytes memory encodedData = vm.parseJson(json, ".wipe_key");
            if (keccak256(encodedData) != keccak256(abi.encodePacked(bytes32(0)))) {
                HtsSystemContract.IKey memory wipeKey = abi.decode(encodedData, (HtsSystemContract.IKey));
                HVM.storeString(tokenAddress, HVM.getSlot("wipeKey"), wipeKey._type);
                HVM.storeString(tokenAddress, HVM.getSlot("wipeKey") + 1, wipeKey.key);
            }
        }
    }

    function _loadCustomFees(address tokenAddress, string memory json) private {
        string memory createdTimestamp = abi.decode(vm.parseJson(json, ".custom_fees.created_timestamp"), (string));
        HVM.storeString(tokenAddress, HVM.getSlot("customFees"), createdTimestamp);
        _loadFixedFees(tokenAddress, new HtsSystemContract.IFixedFee[](0), HVM.getSlot("customFees") + 1);
        _loadFractionalFees(tokenAddress, new HtsSystemContract.IFractionalFee[](0), HVM.getSlot("customFees") + 2);
        _loadRoyaltyFees(tokenAddress, new HtsSystemContract.IRoyaltyFee[](0), HVM.getSlot("customFees") + 3);
    }

    function _loadFixedFees(address tokenAddress, HtsSystemContract.IFixedFee[] memory fixedFees, uint256 startingSlot) private {
        for (uint i = 0; i < fixedFees.length; i++) {
            HtsSystemContract.IFixedFee memory fixedFee = fixedFees[i];
            uint slot = startingSlot + i * 4;
            HVM.storeBool(tokenAddress, slot, fixedFee.allCollectorsAreExempt);
            HVM.storeUint(tokenAddress, slot + 1, uint256(uint64(fixedFee.amount)));
            HVM.storeString(tokenAddress, slot + 2, fixedFee.collectorAccountId);
            HVM.storeString(tokenAddress, slot + 3, fixedFee.denominatingTokenId);
        }
    }

    function _loadFractionalFees(address tokenAddress, HtsSystemContract.IFractionalFee[] memory fractionalFees, uint256 startingSlot) private {
        for (uint i = 0; i < fractionalFees.length; i++) {
            HtsSystemContract.IFractionalFee memory fractionalFee = fractionalFees[i];
            uint slot = startingSlot + i * 8;
            HVM.storeBool(tokenAddress, slot, fractionalFee.allCollectorsAreExempt);
            HVM.storeUint(tokenAddress, slot + 1, uint256(uint64(fractionalFee.amount.numerator)));
            HVM.storeUint(tokenAddress, slot + 2, uint256(uint64(fractionalFee.amount.denominator)));
            HVM.storeString(tokenAddress, slot + 3, fractionalFee.collectorAccountId);
            HVM.storeString(tokenAddress, slot + 4, fractionalFee.denominatingTokenId);
            HVM.storeUint(tokenAddress, slot + 5, uint256(uint64(fractionalFee.maximum)));
            HVM.storeUint(tokenAddress, slot + 6, uint256(uint64(fractionalFee.minimum)));
            HVM.storeBool(tokenAddress, slot + 7, fractionalFee.netOfTransfers);
        }
    }

    function _loadRoyaltyFees(address tokenAddress, HtsSystemContract.IRoyaltyFee[] memory royaltyFees, uint256 startingSlot) private {
        for (uint i = 0; i < royaltyFees.length; i++) {
            HtsSystemContract.IRoyaltyFee memory royaltyFee = royaltyFees[i];
            uint slot = startingSlot + i * 6;
            HVM.storeBool(tokenAddress, slot, royaltyFee.allCollectorsAreExempt);
            HVM.storeUint(tokenAddress, slot + 1, uint256(uint64(royaltyFee.amount.numerator)));
            HVM.storeUint(tokenAddress, slot + 2, uint256(uint64(royaltyFee.amount.denominator)));
            HVM.storeString(tokenAddress, slot + 3, royaltyFee.collectorAccountId);
            HVM.storeUint(tokenAddress, slot + 4, uint256(uint64(royaltyFee.fallbackFee.amount)));
            HVM.storeString(tokenAddress, slot + 5, royaltyFee.fallbackFee.denominatingTokenId);
        }
    }

    function _loadAllowancesOfAnAccount(address tokenAddress, string memory tokenSymbol, address ownerEVMAddress, address spenderEVMAddress) private {
        uint256 ownerId = HtsSystemContract(HTS).getAccountId(ownerEVMAddress);
        uint256 spenderId = HtsSystemContract(HTS).getAccountId(spenderEVMAddress);
        string memory path = string.concat("./@hts-forking/test/data/", tokenSymbol, "/getAllowanceForToken_0.0.", vm.toString(ownerId), "_0.0.", vm.toString(spenderId), ".json");
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
        string memory path = string.concat("./@hts-forking/test/data/", tokenSymbol, "/getBalanceOfToken_0.0.", accountIdString, ".json");
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

    function assignAccountId(uint256 accountId, address account) public {
        bytes4 selector = HtsSystemContract.getAccountAddress.selector;
        uint192 pad = 0x0;
        uint256 slot = uint256(bytes32(abi.encodePacked(selector, pad, uint32(accountId))));
        HVM.storeAddress(HTS, slot, account);
    }

    function loadHts() external {
        deployCodeTo("HtsSystemContract.sol", HTS);
        _loadAccountData(0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15);
        _loadAccountData(0x0000000000000000000000000000000000000887);
        _loadAccountData(0x0000000000000000000000000000000000000537);
        _loadAccountData(0x000000000000000000000000000000000040984F);
        _loadAccountData(5176);
        _loadAccountData(2669675);
    }

    function loadToken(address tokenAddress, string memory tokenSymbol) external {
        _loadTokenData(tokenAddress, tokenSymbol);
        _loadBalanceOfAnAccount(tokenAddress, tokenSymbol, 0x4D1c823b5f15bE83FDf5adAF137c2a9e0E78fE15);
        _loadBalanceOfAnAccount(tokenAddress, tokenSymbol, 0x0000000000000000000000000000000000000887);
        _loadAllowancesOfAnAccount(tokenAddress, tokenSymbol, 0x000000000000000000000000000000000040984F, 0x0000000000000000000000000000000000000537);
    }
}
