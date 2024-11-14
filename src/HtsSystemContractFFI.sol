// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {HtsSystemContract} from "./HtsSystemContract.sol";
import {IERC20} from "./IERC20.sol";
import {MirrorNodeLib} from "./MirrorNodeLib.sol";
import {HVM} from "./HVM.sol";

contract HtsSystemContractFFI is HtsSystemContract {
    using MirrorNodeLib for *;
    using HVM for *;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bool private initialized;
    mapping(address => mapping(address => bool)) private initializedAllowances;

    // HTS Memory will be used for that...
    mapping(address => mapping(address => bool)) private initializedBalances;

    /**
     * @dev HTS Storage will be used to keep a track of initialization of storage slot on the token contract.
     * The reason for that is not make the 'deal' test method still working. We can't read from 2 slots of the same
     * smart contract. 1 slot has to be used only, that's why we will use the second smart contract (HTS) memory to hold
     * the initialization status.
     */
    function isInitializedBalance(address token, address account) htsCall public view returns (bool) {
        return initializedBalances[token][account];
    }

    /*
     * @dev HTS can be used to propagate allow cheat codes flag onto the token Proxies Smart Contracts.
     * We can call vm.allowCheatcodes from within the HTS context.
     */
    function initialize(address target) htsCall public {
        vm.allowCheatcodes(target);
    }

    // For testing, we support accounts created with `makeAddr`. These accounts will not exist on the mirror node,
    // so we calculate a deterministic (but unique) ID at runtime as a fallback.
    function getAccountId(address account) htsCall public view override returns (uint32 accountId) {
        accountId = uint32(bytes4(keccak256(abi.encodePacked(account))));
    }

    function getAccountAddress(string memory accountId) htsCall public override returns (address evm_address) {
        evm_address = MirrorNodeLib.getAccountAddress(accountId);
    }

    function __redirectForToken() internal override returns (bytes memory) {
        HtsSystemContractFFI(HTS_ADDRESS).initialize(address(this));
        bytes4 selector = bytes4(msg.data[24:28]);
        if (selector == IERC20.balanceOf.selector) {
            // We have to always read from this memory slot in order to make deal work correctly.
            bytes memory balance = super.__redirectForToken();
            address account = address(bytes20(msg.data[40:60]));
            uint256 value = abi.decode(balance, (uint256));
            if (value > 0 || HtsSystemContractFFI(HTS_ADDRESS).isInitializedBalance(address(this), account)) {
                return balance;
            }
            return abi.encode(MirrorNodeLib.getAccountBalance(account));
        }
        _initializeTokenData();
        if (selector == IERC20.transfer.selector && msg.data.length >= 92) {
            address from = msg.sender;
            address to = address(bytes20(msg.data[40:60]));
            _initializeAccountBalance(from);
            _initializeAccountBalance(to);
        } else if (selector == IERC20.transferFrom.selector && msg.data.length >= 124) {
            address from = address(bytes20(msg.data[40:60]));
            address to = address(bytes20(msg.data[72:92]));
            address spender = msg.sender;
            _initializeAccountBalance(from);
            _initializeAccountBalance(to);
            if (from != spender) {
                _initializeApproval(from, spender);
            }
        } else if (selector == IERC20.allowance.selector && msg.data.length >= 92) {
            address owner = address(bytes20(msg.data[40:60]));
            address spender = address(bytes20(msg.data[72:92]));
            _initializeApproval(owner, spender);
        } else if (selector == IERC20.approve.selector && msg.data.length >= 92) {
            address from = msg.sender;
            address to = address(bytes20(msg.data[40:60]));
            _initializeApproval(from, to);
        }
        return super.__redirectForToken();
    }

    /**
     * @dev Reading Smart Contract's data into it's storage directly from the MirrorNode.
     */
    function _initializeTokenData() private {
        if (initialized) {
            return;
        }
        string memory json = string(MirrorNodeLib.getTokenData());
        _loadBasicTokenData(address(this), json);
        _loadTokenKeys(address(this), json);
        _loadCustomFees(address(this), json);
        HVM.storeBool(address(this), HVM.getSlot("initialized"), true);
    }

    function _initializeAccountBalance(address account) private  {
        if (HtsSystemContractFFI(HTS_ADDRESS).isInitializedBalance(address(this), account)) {
            return;
        }
        uint256 slot = super._balanceOfSlot(account);
        uint256 balance = MirrorNodeLib.getAccountBalance(account);
        vm.store(address(this), bytes32(slot), bytes32(balance));

        bytes32 mappingSlot = keccak256(
            abi.encode(address(this), keccak256(abi.encode(account, HVM.getSlot("initializedBalances"))))
        );
        vm.store(HTS_ADDRESS, mappingSlot, bytes32(uint256(1)));
    }

    function _initializeApproval(address owner, address spender) private  {
        if (initializedAllowances[owner][spender]) {
            return;
        }
        uint256 slot = super._allowanceSlot(owner, spender);
        uint256 allowance = MirrorNodeLib.getAllowance(owner, spender);
        vm.store(address(this), bytes32(slot), bytes32(allowance));
        bytes32 mappingSlot = keccak256(
            abi.encode(spender, keccak256(abi.encode(owner, HVM.getSlot("initializedAllowances"))))
        );
        vm.store(address(this), mappingSlot, bytes32(uint256(1)));
    }

    function _loadBasicTokenData(address tokenAddress, string memory json) private {
        bytes32 slot;

        assembly { slot := name.slot }
        try vm.parseJsonString(json, ".name") returns (string memory name) {
            HVM.storeString(tokenAddress, uint256(slot), name);
        } catch {
            // Do nothing
        }

        assembly { slot := symbol.slot }
        try vm.parseJsonString(json, ".symbol") returns (string memory symbol) {
            HVM.storeString(tokenAddress, uint256(slot), symbol);
        } catch {
            // Do nothing
        }

        assembly { slot := decimals.slot }
        try vm.parseJsonUint(json, ".decimals") returns (uint256 decimals) {
            HVM.storeUint(tokenAddress, uint256(slot), decimals);
        } catch {
            // Do nothing
        }

        assembly { slot := totalSupply.slot }
        try vm.parseJsonUint(json, ".total_supply") returns (uint256 totalSupply) {
            HVM.storeUint(tokenAddress, uint256(slot), totalSupply);
        } catch {
            // Do nothing
        }

        assembly { slot := maxSupply.slot }
        try vm.parseJsonUint(json, ".max_supply") returns (uint256 maxSupply) {
            HVM.storeUint(tokenAddress, uint256(slot), maxSupply);
        } catch {
            // Do nothing
        }

        assembly { slot := freezeDefault.slot }
        try vm.parseJsonBool(json, ".freeze_default") returns (bool freezeDefault) {
            HVM.storeBool(tokenAddress, uint256(slot), freezeDefault);
        } catch {
            // Do nothing
        }

        assembly { slot := supplyType.slot }
        try vm.parseJsonString(json, ".supply_type") returns (string memory supplyType) {
            HVM.storeString(tokenAddress, uint256(slot), supplyType);
        } catch {
            // Do nothing
        }

        assembly { slot := pauseStatus.slot }
        try vm.parseJsonString(json, ".pause_status") returns (string memory pauseStatus) {
            HVM.storeString(tokenAddress, uint256(slot), pauseStatus);
        } catch {
            // Do nothing
        }

        assembly { slot := expiryTimestamp.slot }
        try vm.parseJsonInt(json, ".expiry_timestamp") returns (int256 expiry) {
            HVM.storeInt64(tokenAddress, uint256(slot), int64(expiry));
        } catch {
            // Do nothing
        }

        assembly { slot := autoRenewAccount.slot }
        try vm.parseJsonString(json, ".auto_renew_account") returns (string memory autoRenewAccount) {
            HVM.storeString(tokenAddress, uint256(slot), autoRenewAccount);
        } catch {
            // Do nothing
        }

        assembly { slot := autoRenewPeriod.slot }
        try vm.parseJsonInt(json, ".auto_renew_period") returns (int256 autoRenewPeriod) {
            HVM.storeInt64(tokenAddress, uint256(slot), int64(autoRenewPeriod));
        } catch {
            // Do nothing
        }

        assembly { slot := deleted.slot }
        try vm.parseJsonBool(json, ".deleted") returns (bool deleted) {
            HVM.storeBool(tokenAddress, uint256(slot), deleted);
        } catch {
            // Do nothing
        }

        assembly { slot := memo.slot }
        try vm.parseJsonString(json, ".memo") returns (string memory memo) {
            HVM.storeString(tokenAddress, uint256(slot), memo);
        } catch {
            // Do nothing
        }

        assembly { slot := treasuryAccountId.slot }
        try vm.parseJsonString(json, ".treasury_account_id") returns (string memory treasuryAccountId) {
            HVM.storeString(tokenAddress, uint256(slot), treasuryAccountId);
        } catch {
            // Do nothing
        }
    }

    function _loadTokenKeys(address tokenAddress, string memory json) private {
        if (vm.keyExistsJson(json, ".admin_key")) {
            try vm.parseJson(json, ".admin_key") returns (bytes memory keyBytes) {
                if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                    bytes32 slot;
                    assembly { slot := adminKey.slot }
                    IKey memory key = abi.decode(keyBytes, (IKey));
                    HVM.storeString(tokenAddress, uint256(slot), key._type);
                    HVM.storeString(tokenAddress, uint256(slot) + 1, key.key);
                }
            } catch {
                // Do nothing
            }
        }
        if (vm.keyExistsJson(json, ".fee_schedule_key")) {
            try vm.parseJson(json, ".fee_schedule_key") returns (bytes memory keyBytes) {
                if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                    bytes32 slot;
                    assembly { slot := feeScheduleKey.slot }
                    IKey memory key = abi.decode(keyBytes, (IKey));
                    HVM.storeString(tokenAddress, uint256(slot), key._type);
                    HVM.storeString(tokenAddress, uint256(slot) + 1, key.key);
                }
            } catch {
                // Do nothing
            }
        }
        if (vm.keyExistsJson(json, ".freeze_key")) {
            try vm.parseJson(json, ".freeze_key") returns (bytes memory keyBytes) {
                if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                    bytes32 slot;
                    assembly { slot := freezeKey.slot }
                    IKey memory key = abi.decode(keyBytes, (IKey));
                    HVM.storeString(tokenAddress, uint256(slot), key._type);
                    HVM.storeString(tokenAddress, uint256(slot) + 1, key.key);
                }
            } catch {
                // Do nothing
            }
        }
        if (vm.keyExistsJson(json, ".kyc_key")) {
            try vm.parseJson(json, ".kyc_key") returns (bytes memory keyBytes) {
                if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                    bytes32 slot;
                    assembly { slot := kycKey.slot }
                    IKey memory key = abi.decode(keyBytes, (IKey));
                    HVM.storeString(tokenAddress, uint256(slot), key._type);
                    HVM.storeString(tokenAddress, uint256(slot) + 1, key.key);
                }
            } catch {
                // Do nothing
            }
        }
        if (vm.keyExistsJson(json, ".pause_key")) {
            try vm.parseJson(json, ".pause_key") returns (bytes memory keyBytes) {
                if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                    bytes32 slot;
                    assembly { slot := pauseKey.slot }
                    IKey memory key = abi.decode(keyBytes, (IKey));
                    HVM.storeString(tokenAddress, uint256(slot), key._type);
                    HVM.storeString(tokenAddress, uint256(slot) + 1, key.key);
                }
            } catch {
                // Do nothing
            }
        }
        if (vm.keyExistsJson(json, ".supply_key")) {
            try vm.parseJson(json, ".supply_key") returns (bytes memory keyBytes) {
                if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                    bytes32 slot;
                    assembly { slot := supplyKey.slot }
                    IKey memory key = abi.decode(keyBytes, (IKey));
                    HVM.storeString(tokenAddress, uint256(slot), key._type);
                    HVM.storeString(tokenAddress, uint256(slot) + 1, key.key);
                }
            } catch {
                // Do nothing
            }
        }
        if (vm.keyExistsJson(json, ".wipe_key")) {
            try vm.parseJson(json, ".wipe_key") returns (bytes memory keyBytes) {
                if (keccak256(keyBytes) != keccak256(abi.encodePacked(bytes32(0)))) {
                    bytes32 slot;
                    assembly { slot := wipeKey.slot }
                    IKey memory key = abi.decode(keyBytes, (IKey));
                    HVM.storeString(tokenAddress, uint256(slot), key._type);
                    HVM.storeString(tokenAddress, uint256(slot) + 1, key.key);
                }
            } catch {
                // Do nothing
            }
        }
    }

    function _loadCustomFees(address tokenAddress, string memory json) private {
        bytes32 slot;
        assembly { slot := customFees.slot }

        HVM.storeString(tokenAddress, uint256(slot), vm.parseJsonString(json, ".custom_fees.created_timestamp"));
        slot = bytes32(uint256(slot) + 1);

        try vm.parseJson(json, ".custom_fees.fixed_fees") returns (bytes memory fixedFeesBytes) {
            if (fixedFeesBytes.length == 0) {
                return;
            }
            IFixedFee[] memory fixedFees = abi.decode(fixedFeesBytes, (IFixedFee[]));
            _loadFixedFees(tokenAddress, fixedFees, uint256(slot));
            slot = bytes32(uint256(slot) + fixedFees.length * 4);
        } catch {
            // Do nothing
        }
        try vm.parseJson(json, ".custom_fees.fractional_fees") returns (bytes memory fractionalFeesBytes) {
            if (fractionalFeesBytes.length == 0) {
                return;
            }
            IFractionalFee[] memory fractionalFees = abi.decode(fractionalFeesBytes, (IFractionalFee[]));
            _loadFractionalFees(tokenAddress, fractionalFees, uint256(slot));
            slot = bytes32(uint256(slot) + fractionalFees.length > 0 ? fractionalFees.length * 8 : 1);
        } catch {
            // Do nothing
        }
        try vm.parseJson(json, ".custom_fees.royalty_fees") returns (bytes memory royaltyFeesBytes) {
            if (royaltyFeesBytes.length == 0) {
                return;
            }
            IRoyaltyFee[] memory royaltyFees = abi.decode(royaltyFeesBytes, (IRoyaltyFee[]));
            _loadRoyaltyFees(tokenAddress, royaltyFees, uint256(slot));
            slot = bytes32(uint256(slot) + royaltyFees.length > 0 ? royaltyFees.length * 6 : 1);
        } catch {
            // Do nothing
        }
    }

    function _loadFixedFees(address tokenAddress, IFixedFee[] memory fixedFees, uint256 startingSlot) private {
        for (uint i = 0; i < fixedFees.length; i++) {
            IFixedFee memory fixedFee = fixedFees[i];
            uint slot = startingSlot + i * 4;
            HVM.storeBool(tokenAddress, slot, fixedFee.allCollectorsAreExempt);
            HVM.storeInt64(tokenAddress, slot + 1, fixedFee.amount);
            HVM.storeString(tokenAddress, slot + 2, fixedFee.collectorAccountId);
            HVM.storeString(tokenAddress, slot + 3, fixedFee.denominatingTokenId);
        }
    }

    function _loadFractionalFees(address tokenAddress, IFractionalFee[] memory fractionalFees, uint256 startingSlot) private {
        for (uint i = 0; i < fractionalFees.length; i++) {
            IFractionalFee memory fractionalFee = fractionalFees[i];
            uint slot = startingSlot + i * 8;
            HVM.storeBool(tokenAddress, slot, fractionalFee.allCollectorsAreExempt);
            HVM.storeInt64(tokenAddress, slot + 1, fractionalFee.amount.numerator);
            HVM.storeInt64(tokenAddress, slot + 2, fractionalFee.amount.denominator);
            HVM.storeString(tokenAddress, slot + 3, fractionalFee.collectorAccountId);
            HVM.storeString(tokenAddress, slot + 4, fractionalFee.denominatingTokenId);
            HVM.storeInt64(tokenAddress, slot + 5, fractionalFee.maximum);
            HVM.storeInt64(tokenAddress, slot + 6, fractionalFee.minimum);
            HVM.storeBool(tokenAddress, slot + 7, fractionalFee.netOfTransfers);
        }
    }

    function _loadRoyaltyFees(address tokenAddress, IRoyaltyFee[] memory royaltyFees, uint256 startingSlot) private {
        for (uint i = 0; i < royaltyFees.length; i++) {
            IRoyaltyFee memory royaltyFee = royaltyFees[i];
            uint slot = startingSlot + i * 6;
            HVM.storeBool(tokenAddress, slot, royaltyFee.allCollectorsAreExempt);
            HVM.storeInt64(tokenAddress, slot + 1, royaltyFee.amount.numerator);
            HVM.storeInt64(tokenAddress, slot + 2, royaltyFee.amount.denominator);
            HVM.storeString(tokenAddress, slot + 3, royaltyFee.collectorAccountId);
            HVM.storeInt64(tokenAddress, slot + 4, royaltyFee.fallbackFee.amount);
            HVM.storeString(tokenAddress, slot + 5, royaltyFee.fallbackFee.denominatingTokenId);
        }
    }
}
