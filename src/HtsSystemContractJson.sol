// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {HtsSystemContract, HTS_ADDRESS} from "./HtsSystemContract.sol";
import {IERC20} from "./IERC20.sol";
import {MirrorNode} from "./MirrorNode.sol";
import {IMirrorNode} from "./IMirrorNode.sol";
import {storeString} from "./StrStore.sol";
import {parseUint, slice} from "./StrUtils.sol";

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

    // For testing, we support accounts created with `makeAddr`. These accounts will not exist on the mirror node,
    // so we calculate a deterministic (but unique) address at runtime as a fallback.
    function getAccountAddress(string memory accountId) htsCall public override returns (address) {
        string memory json = mirrorNode().fetchAccount(accountId);
        if (vm.keyExistsJson(json, ".evm_address")) {
            return vm.parseJsonAddress(json, ".evm_address");
        }

        // ignore the first 4 characters ("0.0.") to get the account number string
        require(bytes(accountId).length > 4, "Invalid account ID, needs to be in the format '0.0.<account_number>'");
        string memory accountNumStr = slice(4, bytes(accountId).length, accountId);
        uint32 accountNum = uint32(parseUint(accountNumStr));

        // generate a deterministic address based on the account number as a fallback
        return address(uint160(accountNum));
    }

    function getTokenInfo(address token) htsCall external override returns (int64 responseCode, TokenInfo memory tokenInfo) {
        string memory json = mirrorNode().fetchTokenData(token);
        tokenInfo = _getTokenInfo(json);
        responseCode = 22; // SUCCESS
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
    }

    function _getTokenInfo(string memory json) private returns (TokenInfo memory tokenInfo) {
        tokenInfo.token = _getHederaToken(json);
        tokenInfo.fixedFees = _getFixedFees(json);
        tokenInfo.fractionalFees = _getFractionalFees(json);
        tokenInfo.royaltyFees = _getRoyaltyFees(json);
        tokenInfo.ledgerId = _getLedgerId();
        tokenInfo.defaultKycStatus = false; // not available in the fetched JSON from mirror node

        try vm.parseJsonInt(json, ".total_supply") returns (int256 totalSupply) {
            tokenInfo.totalSupply = int64(totalSupply);
        } catch {
            // Do nothing
        }

        try vm.parseJsonBool(json, ".deleted") returns (bool deleted) {
            tokenInfo.deleted = deleted;
        } catch {
            // Do nothing
        }

        try vm.parseJsonString(json, ".pause_status") returns (string memory pauseStatus) {
            tokenInfo.pauseStatus = keccak256(bytes(pauseStatus)) == keccak256(bytes("PAUSED"));
        } catch {
            // Do nothing
        }

        return tokenInfo;
    }

    function _getFixedFees(string memory json) private returns (FixedFee[] memory) {
        try vm.parseJson(json, ".custom_fees.fixed_fees") returns (bytes memory fixedFeesBytes) {
            if (fixedFeesBytes.length == 0) {
                return new FixedFee[](0);
            }
            IMirrorNode.FixedFee[] memory fees = abi.decode(fixedFeesBytes, (IMirrorNode.FixedFee[]));
            FixedFee[] memory fixedFees = new FixedFee[](fees.length);
            for (uint i = 0; i < fees.length; i++) {
                IMirrorNode.FixedFee memory fee = fees[i];
                address denominatingToken = HtsSystemContract(HTS_ADDRESS).getAccountAddress(fee.denominating_token_id);
                address collectorAccount = HtsSystemContract(HTS_ADDRESS).getAccountAddress(fee.collector_account_id);
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
        try vm.parseJson(json, ".custom_fees.fractional_fees") returns (bytes memory fractionalFeesBytes) {
            if (fractionalFeesBytes.length == 0) {
                return new FractionalFee[](0);
            }
            IMirrorNode.FractionalFee[] memory fees = abi.decode(fractionalFeesBytes, (IMirrorNode.FractionalFee[]));
            FractionalFee[] memory fractionalFees = new FractionalFee[](fees.length);
            for (uint i = 0; i < fees.length; i++) {
                IMirrorNode.FractionalFee memory fee = fees[i];
                fractionalFees[i] = FractionalFee(
                    fee.amount.numerator,
                    fee.amount.denominator,
                    fee.maximum,
                    fee.minimum,
                    fee.net_of_transfers,
                    HtsSystemContract(HTS_ADDRESS).getAccountAddress(fee.denominating_token_id)
                );
            }
            return fractionalFees;
        } catch {
            // Do nothing
            return new FractionalFee[](0);
        }
    }

    function _getRoyaltyFees(string memory json) private returns (RoyaltyFee[] memory) {
        try vm.parseJson(json, ".custom_fees.royalty_fees") returns (bytes memory royaltyFeesBytes) {
            if (royaltyFeesBytes.length == 0) {
                return new RoyaltyFee[](0);
            }
            IMirrorNode.RoyaltyFee[] memory fees = abi.decode(royaltyFeesBytes, (IMirrorNode.RoyaltyFee[]));
            RoyaltyFee[] memory royaltyFees = new RoyaltyFee[](fees.length);
            for (uint i = 0; i < fees.length; i++) {
                IMirrorNode.RoyaltyFee memory fee = fees[i];
                address collectorAccount = HtsSystemContract(HTS_ADDRESS).getAccountAddress(fee.collector_account_id);
                address tokenId = HtsSystemContract(HTS_ADDRESS).getAccountAddress(fee.fallback_fee.denominating_token_id);
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
            // Do nothing
        }

        try vm.parseJsonString(json, ".symbol") returns (string memory symbol) {
            token.symbol = symbol;
        } catch {
            // Do nothing
        }

        try vm.parseJsonString(json, ".treasury_account_id") returns (string memory treasuryAccountId) {
            address treasury = HtsSystemContract(HTS_ADDRESS).getAccountAddress(treasuryAccountId);
            token.treasury = treasury;
        } catch {
            // Do nothing
        }

        try vm.parseJsonString(json, ".memo") returns (string memory memo) {
            token.memo = memo;
        } catch {
            // Do nothing
        }

        try vm.parseJsonString(json, ".supply_type") returns (string memory supplyType) {
            token.tokenSupplyType = keccak256(bytes(supplyType)) == keccak256(bytes("FINITE"));
        } catch {
            // Do nothing
        }

        try vm.parseJsonInt(json, ".max_supply") returns (int256 maxSupply) {
            token.maxSupply = int64(maxSupply);
        } catch {
            // Do nothing
        }

        try vm.parseJsonBool(json, ".freeze_default") returns (bool freezeDefault) {
            token.freezeDefault = freezeDefault;
        } catch {
            // Do nothing
        }

        try vm.parseJsonInt(json, ".expiry_timestamp") returns (int256 expiry) {
            token.expiry.second = int64(expiry);
        } catch {
            // Do nothing
        }

        try vm.parseJsonString(json, ".auto_renew_account") returns (string memory autoRenewAccount) {
            token.expiry.autoRenewAccount = HtsSystemContract(HTS_ADDRESS).getAccountAddress(autoRenewAccount);
        } catch {
            // Do nothing
        }

        try vm.parseJsonInt(json, ".auto_renew_period") returns (int256 autoRenewPeriod) {
            token.expiry.autoRenewPeriod = int64(autoRenewPeriod);
        } catch {
            // Do nothing
        }

        return token;
    }

    function _getTokenKeys(string memory json) private pure returns (TokenKey[] memory tokenKeys) {
        tokenKeys = new TokenKey[](7);

        try vm.parseJson(json, ".admin_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNode.Key memory key = abi.decode(keyBytes, (IMirrorNode.Key));
                tokenKeys[0] = _createTokenKey(key, 0x1);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".kyc_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNode.Key memory key = abi.decode(keyBytes, (IMirrorNode.Key));
                tokenKeys[1] = _createTokenKey(key, 0x2);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".freeze_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNode.Key memory key = abi.decode(keyBytes, (IMirrorNode.Key));
                tokenKeys[2] = _createTokenKey(key, 0x4);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".wipe_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNode.Key memory key = abi.decode(keyBytes, (IMirrorNode.Key));
                tokenKeys[3] = _createTokenKey(key, 0x8);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".supply_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNode.Key memory key = abi.decode(keyBytes, (IMirrorNode.Key));
                tokenKeys[4] = _createTokenKey(key, 0x10);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".fee_schedule_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNode.Key memory key = abi.decode(keyBytes, (IMirrorNode.Key));
                tokenKeys[5] = _createTokenKey(key, 0x20);
            }
        } catch {
            // Do nothing
        }

        try vm.parseJson(json, ".pause_key") returns (bytes memory keyBytes) {
            if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                IMirrorNode.Key memory key = abi.decode(keyBytes, (IMirrorNode.Key));
                tokenKeys[6] = _createTokenKey(key, 0x40);
            }
        } catch {
            // Do nothing
        }

        return tokenKeys;
    }

    function _createTokenKey(IMirrorNode.Key memory key, uint8 keyType) internal pure returns (TokenKey memory) {
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
