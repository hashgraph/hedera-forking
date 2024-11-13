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
}
