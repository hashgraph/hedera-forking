// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {HtsSystemContract, HTS_ADDRESS} from "./HtsSystemContract.sol";
import {IERC20} from "./IERC20.sol";
import {MirrorNode} from "./MirrorNode.sol";
import {IMirrorNodeResponses} from "./IMirrorNodeResponses.sol";
import {storeAddress, storeBool, storeBytes, storeInt, storeString, storeUint} from "./StrStore.sol";

contract HtsSystemContractJson is HtsSystemContract {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MirrorNode private _mirrorNode;

    bool private initialized;

    function setMirrorNodeProvider(MirrorNode mirrorNode_) htsCall external {
        _mirrorNode = mirrorNode_;
    }

    /*
     * @dev HTS can be used to propagate allow cheat codes flag onto the token Proxies Smart Contracts.
     * We can call `vm.allowCheatcodes` from within the HTS context.
     */
    function allowCheatcodes(address target) htsCall external {
        vm.allowCheatcodes(target);
    }

    // For testing, we support accounts created with `makeAddr`. These accounts will not exist on the mirror node,
    // so we calculate a deterministic (but unique) ID at runtime as a fallback.
    function getAccountId(address account) htsCall external view override returns (uint32) {
        return uint32(bytes4(keccak256(abi.encodePacked(account))));
    }

    function __redirectForToken() internal override returns (bytes memory) {
        HtsSystemContractJson(HTS_ADDRESS).allowCheatcodes(address(this));
        return super.__redirectForToken();
    }

    function mirrorNode() private view returns (MirrorNode) {
        bytes32 slot;
        assembly { slot := _mirrorNode.slot }
        return MirrorNode(address(uint160(uint256(vm.load(HTS_ADDRESS, slot)))));
    }

    /**
     * @dev Reading Smart Contract's data into it's storage directly from the MirrorNode.
     */
    function _initTokenData() internal override {
        if (initialized) return;
        
        bytes32 slot;
        string memory json = mirrorNode().fetchTokenData(address(this));

        assembly { slot := name.slot }
        storeString(address(this), uint256(slot), vm.parseJsonString(json, ".name"));

        assembly { slot := symbol.slot }
        storeString(address(this), uint256(slot), vm.parseJsonString(json, ".symbol"));

        assembly { slot := decimals.slot }
        vm.store(address(this), slot, bytes32(vm.parseJsonUint(json, ".decimals")));

        assembly { slot := totalSupply.slot }
        vm.store(address(this), slot, bytes32(vm.parseJsonUint(json, ".total_supply")));

        assembly { slot := initialized.slot }
        vm.store(address(this), slot, bytes32(uint256(1)));

        _initTokenInfo(json);
    }

    function _initTokenInfo(string memory json) internal {
        TokenInfo memory tokenInfo = _getTokenInfo(json);

        bytes32 slot;
        uint8 offset;
        uint256 slotsTaken;

        assembly { slot := _tokenInfo.slot }

        // Name
        slotsTaken = storeString(address(this), uint256(slot), tokenInfo.token.name);
        slot = bytes32(uint256(slot) + slotsTaken);

        // Symbol
        slotsTaken = storeString(address(this), uint256(slot), tokenInfo.token.symbol);
        slot = bytes32(uint256(slot) + slotsTaken);

        // Treasury
        storeAddress(address(this), uint256(slot), tokenInfo.token.treasury);
        slot = bytes32(uint256(slot) + 1);

        // Memo
        slotsTaken = storeString(address(this), uint256(slot), tokenInfo.token.memo);
        slot = bytes32(uint256(slot) + slotsTaken);

        // Token supply type
        storeBool(address(this), uint256(slot), tokenInfo.token.tokenSupplyType);
        slot = bytes32(uint256(slot) + 1);

        // Max supply
        storeInt(address(this), uint256(slot), tokenInfo.token.maxSupply);
        slot = bytes32(uint256(slot) + 1);

        // Freeze default
        storeBool(address(this), uint256(slot), tokenInfo.token.freezeDefault);
        slot = bytes32(uint256(slot) + 1);

        // Token keys
        uint256 p = uint256(slot);
        storeUint(address(this), p, tokenInfo.token.tokenKeys.length);
        for (uint256 i = 0; i < tokenInfo.token.tokenKeys.length; i++) {
            // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
            uint256 itemSlot = uint256(keccak256(abi.encodePacked(p))) + i;

            // Key type
            storeUint(address(this), itemSlot, tokenInfo.token.tokenKeys[i].keyType);
            itemSlot += 1;

            // Key value
            storeBool(address(this), itemSlot, tokenInfo.token.tokenKeys[i].key.inheritAccountKey);
            offset = 1;

            storeAddress(address(this), itemSlot, offset, tokenInfo.token.tokenKeys[i].key.contractId);
            itemSlot += 1;

            slotsTaken = storeString(address(this), itemSlot, string(tokenInfo.token.tokenKeys[i].key.ed25519));
            itemSlot += slotsTaken;

            slotsTaken = storeString(address(this), itemSlot, string(tokenInfo.token.tokenKeys[i].key.ECDSA_secp256k1));
            itemSlot += slotsTaken;

            storeAddress(address(this), itemSlot, tokenInfo.token.tokenKeys[i].key.delegatableContractId);
            itemSlot += 1;
        }
        slot = bytes32(uint256(slot) + 1);

        // Expiry
        storeInt(address(this), uint256(slot), tokenInfo.token.expiry.second);
        slot = bytes32(uint256(slot) + 1);

        storeAddress(address(this), uint256(slot), tokenInfo.token.expiry.autoRenewAccount);
        slot = bytes32(uint256(slot) + 1);

        storeInt(address(this), uint256(slot), tokenInfo.token.expiry.autoRenewPeriod);
        slot = bytes32(uint256(slot) + 1);

        // Total supply
        storeInt(address(this), uint256(slot), tokenInfo.totalSupply);
        slot = bytes32(uint256(slot) + 1);

        // Deleted
        storeBool(address(this), uint256(slot), tokenInfo.deleted);
        offset = 1;

        // Default KYC status
        storeBool(address(this), uint256(slot), offset, tokenInfo.defaultKycStatus);
        offset += 1;

        // Pause status
        storeBool(address(this), uint256(slot), offset, tokenInfo.pauseStatus);
        slot = bytes32(uint256(slot) + 1);

        // Fixed fees
        p = uint256(slot);
        storeUint(address(this), p, tokenInfo.fixedFees.length);
        for (uint256 i = 0; i < tokenInfo.fixedFees.length; i++) {
            // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
            uint256 itemSlot = uint256(keccak256(abi.encodePacked(p))) + i;

            storeInt(address(this), itemSlot, tokenInfo.fixedFees[i].amount);
            itemSlot += 1;

            storeAddress(address(this), itemSlot, tokenInfo.fixedFees[i].tokenId);
            offset = 20;

            storeBool(address(this), itemSlot, offset, tokenInfo.fixedFees[i].useHbarsForPayment);
            offset += 1;

            storeBool(address(this), itemSlot, offset, tokenInfo.fixedFees[i].useCurrentTokenForPayment);
            itemSlot += 1;

            storeAddress(address(this), itemSlot, tokenInfo.fixedFees[i].feeCollector);
            itemSlot += 1;
        }
        slot = bytes32(uint256(slot) + 1);

        // Fractional fees
        p = uint256(slot);
        storeUint(address(this), p, tokenInfo.fractionalFees.length);
        for (uint256 i = 0; i < tokenInfo.fractionalFees.length; i++) {
            // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
            uint256 itemSlot = uint256(keccak256(abi.encodePacked(p))) + i;

            storeInt(address(this), itemSlot, tokenInfo.fractionalFees[i].numerator);
            itemSlot += 1;

            storeInt(address(this), itemSlot, tokenInfo.fractionalFees[i].denominator);
            itemSlot += 1;

            storeInt(address(this), itemSlot, tokenInfo.fractionalFees[i].minimumAmount);
            itemSlot += 1;

            storeInt(address(this), itemSlot, tokenInfo.fractionalFees[i].maximumAmount);
            itemSlot += 1;

            storeBool(address(this), itemSlot, tokenInfo.fractionalFees[i].netOfTransfers);
            offset = 1;

            storeAddress(address(this), itemSlot, offset, tokenInfo.fractionalFees[i].feeCollector);
            itemSlot += 1;
        }
        slot = bytes32(uint256(slot) + 1);

        // Royalty fees
        p = uint256(slot);
        storeUint(address(this), p, tokenInfo.royaltyFees.length);
        for (uint256 i = 0; i < tokenInfo.royaltyFees.length; i++) {
            // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
            uint256 itemSlot = uint256(keccak256(abi.encodePacked(p))) + i;

            storeInt(address(this), itemSlot, tokenInfo.royaltyFees[i].numerator);
            itemSlot += 1;

            storeInt(address(this), itemSlot, tokenInfo.royaltyFees[i].denominator);
            itemSlot += 1;

            storeInt(address(this), itemSlot, tokenInfo.royaltyFees[i].amount);
            itemSlot += 1;

            storeAddress(address(this), itemSlot, tokenInfo.royaltyFees[i].tokenId);
            offset = 20;

            storeBool(address(this), itemSlot, offset, tokenInfo.royaltyFees[i].useHbarsForPayment);
            itemSlot += 1;

            storeAddress(address(this), uint256(slot), tokenInfo.royaltyFees[i].feeCollector);
            itemSlot += 1;
        }
        slot = bytes32(uint256(slot) + 1);

        // Ledger ID
        slotsTaken = storeString(address(this), uint256(slot), tokenInfo.ledgerId);
        slot = bytes32(uint256(slot) + slotsTaken);
    }

    function _getTokenInfo(string memory json) private returns (TokenInfo memory tokenInfo) {
        tokenInfo.token = _getHederaToken(json);
        tokenInfo.fixedFees = _getFixedFees(json);
        tokenInfo.fractionalFees = _getFractionalFees(json);
        tokenInfo.royaltyFees = _getRoyaltyFees(json);
        tokenInfo.ledgerId = _getLedgerId();
        tokenInfo.defaultKycStatus = false; // not available in the fetched JSON from mirror node

        try vm.parseJsonString(json, ".total_supply") returns (string memory totalSupply) {
            tokenInfo.totalSupply = vm.parseInt(totalSupply);
        } catch {
            revert("getTokenInfo: Token total supply is required");
        }

        try vm.parseJsonBool(json, ".deleted") returns (bool deleted) {
            tokenInfo.deleted = deleted;
        } catch {
            // Do nothing
        }

        try vm.parseJsonString(json, ".pause_status") returns (string memory pauseStatus) {
            tokenInfo.pauseStatus = keccak256(bytes(pauseStatus)) == keccak256(bytes("PAUSED"));
        } catch {
            revert("getTokenInfo: Token pause status is required");
        }

        return tokenInfo;
    }

    function _getFixedFees(string memory json) private returns (FixedFee[] memory) {
        if (!vm.keyExistsJson(json, ".custom_fees.fixed_fees")) {
            return new FixedFee[](0);
        }

        try vm.parseJson(json, ".custom_fees.fixed_fees") returns (bytes memory fixedFeesBytes) {
            if (fixedFeesBytes.length == 0) {
                return new FixedFee[](0);
            }
            IMirrorNodeResponses.FixedFee[] memory fees = abi.decode(fixedFeesBytes, (IMirrorNodeResponses.FixedFee[]));
            FixedFee[] memory fixedFees = new FixedFee[](fees.length);
            for (uint i = 0; i < fees.length; i++) {
                IMirrorNodeResponses.FixedFee memory fee = fees[i];
                address denominatingToken = _getAccountAddress(fee.denominating_token_id);
                address collectorAccount = _getAccountAddress(fee.collector_account_id);
                fixedFees[i] = FixedFee(
                    fee.amount,
                    denominatingToken,
                    denominatingToken == address(0),
                    denominatingToken == address(this),
                    collectorAccount
                );
            }
            return fixedFees;
        } catch {
            // Do nothing
            return new FixedFee[](0);
        }
    }

    function _getFractionalFees(string memory json) private returns (FractionalFee[] memory) {
        if (!vm.keyExistsJson(json, ".custom_fees.fractional_fees")) {
            return new FractionalFee[](0);
        }

        try vm.parseJson(json, ".custom_fees.fractional_fees") returns (bytes memory fractionalFeesBytes) {
            if (fractionalFeesBytes.length == 0) {
                return new FractionalFee[](0);
            }
            IMirrorNodeResponses.FractionalFee[] memory fees = abi.decode(fractionalFeesBytes, (IMirrorNodeResponses.FractionalFee[]));
            FractionalFee[] memory fractionalFees = new FractionalFee[](fees.length);
            for (uint i = 0; i < fees.length; i++) {
                IMirrorNodeResponses.FractionalFee memory fee = fees[i];
                fractionalFees[i] = FractionalFee(
                    fee.amount.numerator,
                    fee.amount.denominator,
                    fee.maximum,
                    fee.minimum,
                    fee.net_of_transfers,
                    _getAccountAddress(fee.denominating_token_id)
                );
            }
            return fractionalFees;
        } catch {
            // Do nothing
            return new FractionalFee[](0);
        }
    }

    function _getRoyaltyFees(string memory json) private returns (RoyaltyFee[] memory) {
        if (!vm.keyExistsJson(json, ".custom_fees.royalty_fees")) {
            return new RoyaltyFee[](0);
        }

        try vm.parseJson(json, ".custom_fees.royalty_fees") returns (bytes memory royaltyFeesBytes) {
            if (royaltyFeesBytes.length == 0) {
                return new RoyaltyFee[](0);
            }
            IMirrorNodeResponses.RoyaltyFee[] memory fees = abi.decode(royaltyFeesBytes, (IMirrorNodeResponses.RoyaltyFee[]));
            RoyaltyFee[] memory royaltyFees = new RoyaltyFee[](fees.length);
            for (uint i = 0; i < fees.length; i++) {
                IMirrorNodeResponses.RoyaltyFee memory fee = fees[i];
                address collectorAccount = _getAccountAddress(fee.collector_account_id);
                address tokenId = _getAccountAddress(fee.fallback_fee.denominating_token_id);
                royaltyFees[i] = RoyaltyFee(
                    fee.amount.numerator,
                    fee.amount.denominator,
                    fee.fallback_fee.amount,
                    tokenId,
                    collectorAccount == address(0),
                    collectorAccount
                );
            }
            return royaltyFees;
        } catch {
            return new RoyaltyFee[](0);
        }
    }

    function _getHederaToken(string memory json) private returns (HederaToken memory token) {
        token.tokenKeys = _getTokenKeys(json);

        try vm.parseJsonString(json, ".name") returns (string memory name) {
            token.name = name;
        } catch {
            revert("getTokenInfo: Token name is required");
        }

        try vm.parseJsonString(json, ".symbol") returns (string memory symbol) {
            token.symbol = symbol;
        } catch {
            revert("getTokenInfo: Token symbol is required");
        }

        try vm.parseJsonString(json, ".treasury_account_id") returns (string memory treasuryAccountId) {
            if (keccak256(bytes(treasuryAccountId)) != keccak256(bytes("null"))) {
                token.treasury =  _getAccountAddress(treasuryAccountId);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJsonString(json, ".memo") returns (string memory memo) {
            token.memo = memo;
        } catch {
            revert("getTokenInfo: Token memo is required");
        }

        try vm.parseJsonString(json, ".supply_type") returns (string memory supplyType) {
            token.tokenSupplyType = keccak256(bytes(supplyType)) == keccak256(bytes("FINITE"));
        } catch {
            revert("getTokenInfo: Token supply type is required");
        }

        try vm.parseJsonString(json, ".max_supply") returns (string memory maxSupply) {
            token.maxSupply = vm.parseInt(maxSupply);
        } catch {
            revert("getTokenInfo: Token max supply is required");
        }

        try vm.parseJsonBool(json, ".freeze_default") returns (bool freezeDefault) {
            token.freezeDefault = freezeDefault;
        } catch {
            revert("getTokenInfo: Token freeze default is required");
        }

        try vm.parseJson(json, ".expiry_timestamp") returns (bytes memory expiryBytes) {
            token.expiry.second = abi.decode(expiryBytes, (int256));
        } catch {
            // Do nothing
        }

        try vm.parseJsonString(json, ".auto_renew_account") returns (string memory autoRenewAccount) {
            if (keccak256(bytes(autoRenewAccount)) != keccak256(bytes("null"))) {
                token.expiry.autoRenewAccount = _getAccountAddress(autoRenewAccount);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".auto_renew_period") returns (bytes memory autoRenewPeriodBytes) {
            token.expiry.autoRenewPeriod = abi.decode(autoRenewPeriodBytes, (int256));
        } catch {
            // Do nothing
        }

        return token;
    }

    function _getTokenKeys(string memory json) private pure returns (TokenKey[] memory tokenKeys) {
        tokenKeys = new TokenKey[](7);

        try vm.parseJson(json, ".admin_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                console.log("Admin key found");
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[0] = _createTokenKey(key, 0x1);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".kyc_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                console.log("KYC key found");
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[1] = _createTokenKey(key, 0x2);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".freeze_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                console.log("Freeze key found");
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[2] = _createTokenKey(key, 0x4);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".wipe_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                console.log("Wipe key found");
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[3] = _createTokenKey(key, 0x8);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".supply_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                console.log("Supply key found");
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[4] = _createTokenKey(key, 0x10);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".fee_schedule_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                console.log("Fee schedule key found");
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[5] = _createTokenKey(key, 0x20);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".pause_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                console.log("Pause key found");
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[6] = _createTokenKey(key, 0x40);
            }
        } catch {
            // Do nothing
        }

        return tokenKeys;
    }

    function _createTokenKey(IMirrorNodeResponses.Key memory key, uint8 keyType) internal pure returns (TokenKey memory) {
        bool inheritAccountKey = false;
        address contractId = address(0);
        address delegatableContractId = address(0);
        bytes memory ed25519 = keccak256(bytes(key._type)) == keccak256(bytes("ED25519"))
            ? bytes(key.key)
            : new bytes(0);
        bytes memory ECDSA_secp256k1 = keccak256(bytes(key._type)) == keccak256(bytes("ECDSA_SECP256K1"))
            ? bytes(key.key)
            : new bytes(0);
        return TokenKey(
            keyType,
            KeyValue(
                inheritAccountKey,
                contractId,
                ed25519,
                ECDSA_secp256k1,
                delegatableContractId
            )
        );
    }

    function _getAccountAddress(string memory accountId) private returns (address) {
        if (bytes(accountId).length == 0 || keccak256(bytes(accountId)) == keccak256(bytes("null"))) {
            return address(0);
        }

        string memory json = mirrorNode().fetchAccount(accountId);
        if (vm.keyExistsJson(json, ".evm_address")) {
            return vm.parseJsonAddress(json, ".evm_address");
        }

        // ignore the first 4 characters ("0.0.") to get the account number string
        require(bytes(accountId).length > 4, "Invalid account ID, needs to be in the format '0.0.<account_number>'");
        uint32 accountNum = uint32(vm.parseUint(vm.replace(accountId, "0.0.", "")));

        // generate a deterministic address based on the account number as a fallback
        return address(uint160(accountNum));
    }

    function _getLedgerId() internal view returns (string memory) {
        if (block.chainid == 295) return "0x00"; // Mainnet
        if (block.chainid == 296) return "0x01"; // Testnet
        if (block.chainid == 297) return "0x02"; // Previewnet
        return "0x00"; // Default to Mainnet
    }

    function _balanceOfSlot(address account) internal override returns (bytes32) {
        bytes32 slot = super._balanceOfSlot(account);
        if (vm.load(_scratchAddr(), slot) == bytes32(0)) {
            uint256 amount = mirrorNode().getBalance(address(this), account);
            _setValue(slot, bytes32(amount));
        }
        return slot;
    }

    function _allowanceSlot(address owner, address spender) internal override returns (bytes32) {
        bytes32 slot = super._allowanceSlot(owner, spender);
        if (vm.load(_scratchAddr(), slot) == bytes32(0)) {
            uint256 amount = mirrorNode().getAllowance(address(this), owner, spender);
            _setValue(slot, bytes32(amount));
        }
        return slot;
    }

    function _setValue(bytes32 slot, bytes32 value) private {
        vm.store(address(this), slot, value);
        vm.store(_scratchAddr(), slot, bytes32(uint(1)));
    }

    function _scratchAddr() private view returns (address) {
        return address(bytes20(keccak256(abi.encode(address(this)))));
    }
}
