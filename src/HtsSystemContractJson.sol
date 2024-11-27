// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {HtsSystemContract, HTS_ADDRESS} from "./HtsSystemContract.sol";
import {IERC20} from "./IERC20.sol";
import {MirrorNode} from "./MirrorNode.sol";
import {IMirrorNodeResponses} from "./IMirrorNodeResponses.sol";
import {storeAddress, storeBool, storeBytes, storeInt, storeString, storeUint} from "./StrStore.sol";

contract HtsSystemContractJson is HtsSystemContract {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MirrorNode private _mirrorNode;

    bool private initialized;
    mapping (address => bool) private relationshipsInitialized;

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
     * @dev Both `initialized` and `_mirrorNode` are stored in the same slot (with different offsets).
     * Given how `initialized` is written to (see at the end of the method), it would seem that the
     * instance variable `_mirrorNode` is overwritten.
     * However, this is not the case because the slot space for each access is different:
     * - `_mirrorNode` is accessed through the `0x167` address.
     * - `initialized` is accessed through the address of the token.
     */
    function _initTokenData() internal override {
        bytes32 slot;
        assembly { slot := initialized.slot }
        if (vm.load(address(this), slot) == bytes32(uint256(1))) {
            // Already initialized
            return;
        }

        string memory json = mirrorNode().fetchTokenData(address(this));

        assembly { slot := name.slot }
        storeString(address(this), uint256(slot), vm.parseJsonString(json, ".name"));

        assembly { slot := symbol.slot }
        storeString(address(this), uint256(slot), vm.parseJsonString(json, ".symbol"));

        assembly { slot := decimals.slot }
        storeUint(address(this), uint256(slot), vm.parseJsonUint(json, ".decimals"));

        assembly { slot := totalSupply.slot }
        storeUint(address(this), uint256(slot), vm.parseJsonUint(json, ".total_supply"));

        assembly { slot := initialized.slot }
        storeBool(address(this), uint256(slot), true);

        _initTokenInfo(json);
    }

    function _initTokenRelationships(address account) internal override {
        if (relationshipsInitialized[account]) {
            // Already initialized
            return;
        }

        bytes32 slot = _isAssociatedSlot(account);
        try mirrorNode().fetchTokenRelationshipOfAccount(vm.toString(account), address(this)) returns (string memory json) {
            string memory notFoundError = "{\"_status\":{\"messages\":[{\"message\":\"Not found\"}]}}";
            if (keccak256(bytes(json)) == keccak256(bytes(notFoundError))) {
                storeBool(address(this), uint256(slot), false);
            } else {
                bytes memory tokens = vm.parseJson(json, ".tokens");
                IMirrorNodeResponses.TokenRelationship[] memory relationships = abi.decode(tokens, (IMirrorNodeResponses.TokenRelationship[]));
                storeBool(address(this), uint256(slot), relationships.length > 0);
            }
        } catch {
            storeBool(address(this), uint256(slot), false);
        }

        relationshipsInitialized[account] = true;
    }

    function _initTokenInfo(string memory json) internal {
        TokenInfo memory tokenInfo = _getTokenInfo(json);

        bytes32 slotBytes;
        assembly { slotBytes := _tokenInfo.slot }

        uint256 slot = uint256(slotBytes);

        // Name
        storeString(address(this), slot++, tokenInfo.token.name);

        // Symbol
        storeString(address(this), slot++, tokenInfo.token.symbol);

        // Treasury
        storeAddress(address(this), slot++, tokenInfo.token.treasury);

        // Memo
        storeString(address(this), slot++, tokenInfo.token.memo);

        // Token supply type
        storeBool(address(this), slot++, tokenInfo.token.tokenSupplyType);

        // Max supply
        storeInt(address(this), slot++, tokenInfo.token.maxSupply);

        // Freeze default
        storeBool(address(this), slot++, tokenInfo.token.freezeDefault);

        // Token keys
        // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
        storeUint(address(this), slot, tokenInfo.token.tokenKeys.length);
        uint256 itemSlot = uint256(keccak256(abi.encodePacked(slot)));
        for (uint256 i = 0; i < tokenInfo.token.tokenKeys.length; i++) {
            // Key type
            storeUint(address(this), itemSlot++, tokenInfo.token.tokenKeys[i].keyType);
            // Key value
            storeAddress(address(this), itemSlot++, tokenInfo.token.tokenKeys[i].key.contractId);
            storeBytes(address(this), itemSlot++, tokenInfo.token.tokenKeys[i].key.ed25519);
            storeBool(address(this), itemSlot++, tokenInfo.token.tokenKeys[i].key.inheritAccountKey);
            storeBytes(address(this), itemSlot++, tokenInfo.token.tokenKeys[i].key.ECDSA_secp256k1);
            storeAddress(address(this), itemSlot++, tokenInfo.token.tokenKeys[i].key.delegatableContractId);
        }
        slot += 1;

        // Expiry
        storeInt(address(this), slot++, tokenInfo.token.expiry.second);
        storeAddress(address(this), slot++, tokenInfo.token.expiry.autoRenewAccount);
        storeInt(address(this), slot++, tokenInfo.token.expiry.autoRenewPeriod);

        // Total supply
        storeInt(address(this), slot++, tokenInfo.totalSupply);

        // Deleted
        storeBool(address(this), slot++, tokenInfo.deleted);

        // Fixed fees
        // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
        itemSlot = uint256(keccak256(abi.encodePacked(slot)));
        storeUint(address(this), slot, tokenInfo.fixedFees.length);
        for (uint256 i = 0; i < tokenInfo.fixedFees.length; i++) {
            storeAddress(address(this), itemSlot++, tokenInfo.fixedFees[i].feeCollector);
            storeInt(address(this), itemSlot++, tokenInfo.fixedFees[i].amount);
            storeAddress(address(this), itemSlot++, tokenInfo.fixedFees[i].tokenId);
            itemSlot += 1; // Skip the gap1 variable
            storeBool(address(this), itemSlot++, tokenInfo.fixedFees[i].useHbarsForPayment);
            itemSlot += 1; // Skip the gap2 variable
            storeBool(address(this), itemSlot++, tokenInfo.fixedFees[i].useCurrentTokenForPayment);
        }
        slot += 1;

        // Default KYC status
        storeBool(address(this), slot++, tokenInfo.defaultKycStatus);

        // Fractional fees
        // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
        itemSlot = uint256(keccak256(abi.encodePacked(slot)));
        storeUint(address(this), slot, tokenInfo.fractionalFees.length);
        for (uint256 i = 0; i < tokenInfo.fractionalFees.length; i++) {
            storeBool(address(this), itemSlot, tokenInfo.fractionalFees[i].netOfTransfers);
            storeInt(address(this), itemSlot++, tokenInfo.fractionalFees[i].numerator);
            storeInt(address(this), itemSlot++, tokenInfo.fractionalFees[i].denominator);
            storeInt(address(this), itemSlot++, tokenInfo.fractionalFees[i].minimumAmount);
            storeInt(address(this), itemSlot++, tokenInfo.fractionalFees[i].maximumAmount);
            storeAddress(address(this), itemSlot++, tokenInfo.fractionalFees[i].feeCollector);
        }
        slot += 1;

        // Pause status
        storeBool(address(this), slot++, tokenInfo.pauseStatus);

        // Royalty fees
        // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
        itemSlot = uint256(keccak256(abi.encodePacked(slot)));
        storeUint(address(this), slot, tokenInfo.royaltyFees.length);
        for (uint256 i = 0; i < tokenInfo.royaltyFees.length; i++) {
            storeAddress(address(this), itemSlot++, tokenInfo.royaltyFees[i].feeCollector);
            storeInt(address(this), itemSlot++, tokenInfo.royaltyFees[i].numerator);
            storeInt(address(this), itemSlot++, tokenInfo.royaltyFees[i].denominator);
            storeBool(address(this), itemSlot++, tokenInfo.royaltyFees[i].useHbarsForPayment);
            storeInt(address(this), itemSlot++, tokenInfo.royaltyFees[i].amount);
            storeAddress(address(this), itemSlot++, tokenInfo.royaltyFees[i].tokenId);
        }
        slot += 1;

        // Ledger ID
        storeString(address(this), slot++, tokenInfo.ledgerId);
    }

    function _getTokenInfo(string memory json) private returns (TokenInfo memory tokenInfo) {
        tokenInfo.token = _getHederaToken(json);
        tokenInfo.fixedFees = _getFixedFees(json);
        tokenInfo.fractionalFees = _getFractionalFees(json);
        tokenInfo.royaltyFees = _getRoyaltyFees(json);
        tokenInfo.ledgerId = _getLedgerId();
        tokenInfo.defaultKycStatus = false; // not available in the fetched JSON from mirror node
        tokenInfo.totalSupply = vm.parseInt(vm.parseJsonString(json, ".total_supply"));
        tokenInfo.deleted = vm.parseJsonBool(json, ".deleted");
        tokenInfo.pauseStatus = keccak256(bytes(vm.parseJsonString(json, ".pause_status"))) == keccak256(bytes("PAUSED"));
        return tokenInfo;
    }

    function _getHederaToken(string memory json) private returns (HederaToken memory token) {
        token.tokenKeys = _getTokenKeys(json);
        token.name = vm.parseJsonString(json, ".name");
        token.symbol = vm.parseJsonString(json, ".symbol");
        token.memo = vm.parseJsonString(json, ".memo");
        token.tokenSupplyType = keccak256(bytes(vm.parseJsonString(json, ".supply_type"))) == keccak256(bytes("FINITE"));
        token.maxSupply = vm.parseInt(vm.parseJsonString(json, ".max_supply"));
        token.freezeDefault = vm.parseJsonBool(json, ".freeze_default");
        token.expiry.second = abi.decode(vm.parseJson(json, ".expiry_timestamp"), (int256));

        try vm.parseJsonString(json, ".auto_renew_account") returns (string memory autoRenewAccount) {
            if (keccak256(bytes(autoRenewAccount)) != keccak256(bytes("null"))) {
                token.expiry.autoRenewAccount = mirrorNode().getAccountAddress(autoRenewAccount);
            }
        } catch {}

        try vm.parseJson(json, ".auto_renew_period") returns (bytes memory autoRenewPeriodBytes) {
            token.expiry.autoRenewPeriod = abi.decode(autoRenewPeriodBytes, (int256));
        } catch {}

        try vm.parseJsonString(json, ".treasury_account_id") returns (string memory treasuryAccountId) {
            if (keccak256(bytes(treasuryAccountId)) != keccak256(bytes("null"))) {
                token.treasury =  mirrorNode().getAccountAddress(treasuryAccountId);
            }
        } catch {}

        return token;
    }

    function _getTokenKeys(string memory json) private pure returns (TokenKey[] memory tokenKeys) {
        tokenKeys = new TokenKey[](7);

        try vm.parseJson(json, ".admin_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[0] = _getTokenKey(key, 0x1);
            }
        } catch {}

        try vm.parseJson(json, ".kyc_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[1] = _getTokenKey(key, 0x2);
            }
        } catch {}

        try vm.parseJson(json, ".freeze_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[2] = _getTokenKey(key, 0x4);
            }
        } catch {}

        try vm.parseJson(json, ".wipe_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[3] = _getTokenKey(key, 0x8);
            }
        } catch {}

        try vm.parseJson(json, ".supply_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[4] = _getTokenKey(key, 0x10);
            }
        } catch {}

        try vm.parseJson(json, ".fee_schedule_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[5] = _getTokenKey(key, 0x20);
            }
        } catch {}

        try vm.parseJson(json, ".pause_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNodeResponses.Key memory key = abi.decode(keyBytes, (IMirrorNodeResponses.Key));
                tokenKeys[6] = _getTokenKey(key, 0x40);
            }
        } catch {}

        return tokenKeys;
    }

    function _getTokenKey(IMirrorNodeResponses.Key memory key, uint8 keyType) internal pure returns (TokenKey memory) {
        bool inheritAccountKey = false;
        address contractId = address(0);
        address delegatableContractId = address(0);
        bytes memory ed25519 = keccak256(bytes(key._type)) == keccak256(bytes("ED25519"))
            ? vm.parseBytes(key.key)
            : new bytes(0);
        bytes memory ECDSA_secp256k1 = keccak256(bytes(key._type)) == keccak256(bytes("ECDSA_SECP256K1"))
            ? vm.parseBytes(key.key)
            : new bytes(0);
        return TokenKey(
            keyType,
            KeyValue(
                contractId,
                ed25519,
                inheritAccountKey,
                ECDSA_secp256k1,
                delegatableContractId
            )
        );
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
                string memory path = vm.replace(".custom_fees.fixed_fees[{i}]", "{i}", vm.toString(i));
                address denominatingToken = mirrorNode().getAccountAddress(vm.parseJsonString(json, string.concat(path, ".denominating_token_id")));
                fixedFees[i] = FixedFee(
                    mirrorNode().getAccountAddress(vm.parseJsonString(json, string.concat(path, ".collector_account_id"))),
                    vm.parseJsonInt(json, string.concat(path, ".amount")),
                    denominatingToken,
                    uint96(0),
                    denominatingToken == address(0),
                    uint248(0),
                    denominatingToken == address(this)
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
                string memory path = vm.replace(".custom_fees.fractional_fees[{i}]", "{i}", vm.toString(i));
                fractionalFees[i] = FractionalFee(
                    vm.parseJsonBool(json, string.concat(path, ".net_of_transfers")),
                    vm.parseJsonInt(json, string.concat(path, ".amount.numerator")),
                    vm.parseJsonInt(json, string.concat(path, ".amount.denominator")),
                    vm.parseJsonInt(json, string.concat(path, ".minimum")),
                    vm.parseJsonInt(json, string.concat(path, ".maximum")),
                    mirrorNode().getAccountAddress(vm.parseJsonString(json, string.concat(path, ".collector_account_id")))
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
                string memory path = vm.replace(".custom_fees.royalty_fees[{i}]", "{i}", vm.toString(i));
                address collectorAccount = mirrorNode().getAccountAddress(vm.parseJsonString(json, string.concat(path, ".collector_account_id")));
                royaltyFees[i] = RoyaltyFee(
                    collectorAccount,
                    vm.parseJsonInt(json, string.concat(path, ".amount.numerator")),
                    vm.parseJsonInt(json, string.concat(path, ".amount.denominator")),
                    collectorAccount == address(0),
                    vm.parseJsonInt(json, string.concat(path, ".fallback_fee.amount")),
                    mirrorNode().getAccountAddress(vm.parseJsonString(json, string.concat(path, ".denominating_token_id")))
                );
            }
            return royaltyFees;
        } catch {
            return new RoyaltyFee[](0);
        }
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
