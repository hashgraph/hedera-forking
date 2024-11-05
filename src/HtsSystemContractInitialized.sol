// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {HtsSystemContract} from "./HtsSystemContract.sol";
import {IERC20} from "./IERC20.sol";
import {MirrorNodeLib} from "./MirrorNodeLib.sol";
import {HVM} from "./HVM.sol";

contract HtsSystemContractInitialized is HtsSystemContract {
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

    function getAccountId(address account) htsCall public view override returns (uint32 accountId) {
        accountId = super.getAccountId(account);
        // For testing, we support accounts created with `makeAddr`. These accounts will not exist on the mirror node,
        // so we calculate a deterministic (but unique) ID at runtime as a fallback.
        if (accountId == 0) {
            accountId = uint32(bytes4(keccak256(abi.encodePacked(account))));
        }
    }

    function __redirectForToken() internal override returns (bytes memory) {
        HtsSystemContractInitialized(HTS_ADDRESS).initialize(address(this));
        bytes4 selector = bytes4(msg.data[24:28]);
        if (selector == IERC20.balanceOf.selector) {
            // We have to always read from this memory slot in order to make deal work correctly.
            bytes memory balance = super.__redirectForToken();
            address account = address(bytes20(msg.data[40:60]));
            uint256 value = abi.decode(balance, (uint256));
            if (value > 0 || HtsSystemContractInitialized(HTS_ADDRESS).isInitializedBalance(address(this), account)) {
                return balance;
            }
            return abi.encode(MirrorNodeLib.getAccountBalanceFromMirrorNode(account));
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
        HVM.storeString(address(this), HVM.getSlot("name"), MirrorNodeLib.getTokenStringDataFromMirrorNode("name"));
        HVM.storeString(
            address(this),
            HVM.getSlot("symbol"),
            MirrorNodeLib.getTokenStringDataFromMirrorNode("symbol")
        );
        vm.store(
            address(this),
            bytes32(HVM.getSlot("decimals")),
            bytes32(vm.parseUint(MirrorNodeLib.getTokenStringDataFromMirrorNode("decimals")))
        );
        vm.store(
            address(this),
            bytes32(HVM.getSlot("totalSupply")),
            bytes32(vm.parseUint(MirrorNodeLib.getTokenStringDataFromMirrorNode("total_supply")))
        );
        vm.store(address(this), bytes32(HVM.getSlot("initialized")), bytes32(uint256(1)));
    }

    function _initializeAccountBalance(address account) private  {
        if (HtsSystemContractInitialized(HTS_ADDRESS).isInitializedBalance(address(this), account)) {
            return;
        }
        uint256 slot = super._balanceOfSlot(account);
        uint256 balance = MirrorNodeLib.getAccountBalanceFromMirrorNode(account);
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
        uint256 allowance = MirrorNodeLib.getAllowanceFromMirrorNode(owner, spender);
        vm.store(address(this), bytes32(slot), bytes32(allowance));
        bytes32 mappingSlot = keccak256(
            abi.encode(spender, keccak256(abi.encode(owner, HVM.getSlot("initializedAllowances"))))
        );
        vm.store(address(this), mappingSlot, bytes32(uint256(1)));
    }
}
