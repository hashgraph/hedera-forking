// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {HtsSystemContract} from "@hts-forking/HtsSystemContract.sol";
import {IERC20} from "@hts-forking/IERC20.sol";
import {MirrorNodeLib} from "./lib/MirrorNodeLib.sol";

contract HtsSystemContractInitialized is HtsSystemContract {
    using MirrorNodeLib for *;

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
    function initializeBalance(address token, address account) htsCall public {
        initializedBalances[token][account] = true;
    }

    function isInitializedBalance(address token, address account) htsCall public view returns (bool) {
        return initializedBalances[token][account];
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
        bytes4 selector = bytes4(msg.data[24:28]);

        if (selector == IERC20.name.selector && !initialized) {
            return abi.encode(MirrorNodeLib.getTokenStringDataFromMirrorNode("name"));
        } else if (selector == IERC20.decimals.selector && !initialized) {
            return abi.encode(uint8(vm.parseUint(MirrorNodeLib.getTokenStringDataFromMirrorNode("decimals"))));
        } else if (selector == IERC20.totalSupply.selector && !initialized) {
            return abi.encode(uint256(vm.parseUint(MirrorNodeLib.getTokenStringDataFromMirrorNode("total_supply"))));
        } else if (selector == IERC20.symbol.selector && !initialized) {
            return abi.encode(MirrorNodeLib.getTokenStringDataFromMirrorNode("symbol"));
        } else if (selector == IERC20.balanceOf.selector && msg.data.length >= 60) {
            // We have to always read from this memory slot in order to make deal work correctly.
            bytes memory balance = super.__redirectForToken();
            address account = address(bytes20(msg.data[40:60]));
            uint256 inMemory = abi.decode(balance, (uint256));
            if (inMemory > 0 || HtsSystemContractInitialized(HTS_ADDRESS).isInitializedBalance(address(this), account)) {
                return balance;
            }
            return abi.encode(MirrorNodeLib.getAccountBalanceFromMirrorNode(account));
        } else if (selector == IERC20.transfer.selector && msg.data.length >= 92) {
            address to = address(bytes20(msg.data[40:60]));
            address owner = msg.sender;
            _initializeTokenData();
            _initializeAccountsRelations(owner, to);
        } else if (selector == IERC20.transferFrom.selector && msg.data.length >= 124) {
            address from = address(bytes20(msg.data[40:60]));
            address to = address(bytes20(msg.data[72:92]));
            address spender = msg.sender;
            _initializeTokenData();
            _initializeAccountsRelations(from, to);
            if (from != spender) {
                _initializeAccountsRelations(spender, to);
                _initializeAccountsRelations(from, spender);
            }
        } else if (selector == IERC20.allowance.selector && msg.data.length >= 92) {
            address owner = address(bytes20(msg.data[40:60]));
            address spender = address(bytes20(msg.data[72:92]));
            if (!initializedAllowances[owner][spender]) {
                return abi.encode(MirrorNodeLib.getAllowanceFromMirrorNode(owner, spender));
            }
        } else if (selector == IERC20.approve.selector && msg.data.length >= 92) {
            address spender = address(bytes20(msg.data[40:60]));
            address owner = msg.sender;
            _initializeTokenData();
            _initializeAccountsRelations(owner, spender);
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
        initialized = true;
        name = MirrorNodeLib.getTokenStringDataFromMirrorNode("name");
        symbol = MirrorNodeLib.getTokenStringDataFromMirrorNode("symbol");

        uint8 decimals = uint8(vm.parseUint(MirrorNodeLib.getTokenStringDataFromMirrorNode("decimals")));
        uint256 totalSupply = uint256(vm.parseUint(MirrorNodeLib.getTokenStringDataFromMirrorNode("total_supply")));
        vm.store(address(this), bytes32(uint256(2)), bytes32(uint256(decimals)));
        vm.store(address(this), bytes32(uint256(3)), bytes32(totalSupply));
    }

    function _initializeAccountsRelations(address firstAccount, address secondAccount) private {
        _initializeAccountBalance(firstAccount);
        _initializeAccountBalance(secondAccount);
        _initializeApproval(firstAccount, secondAccount);
        _initializeApproval(secondAccount, firstAccount);
    }

    function _initializeAccountBalance(address account) private  {
        if (HtsSystemContractInitialized(HTS_ADDRESS).isInitializedBalance(address(this), account)) {
            return;
        }
        uint256 slot = super._balanceOfSlot(account);
        uint256 balance = MirrorNodeLib.getAccountBalanceFromMirrorNode(account);
        vm.store(address(this), bytes32(slot), bytes32(balance));
        HtsSystemContractInitialized(HTS_ADDRESS).initializeBalance(address(this), account);
    }

    function _initializeApproval(address owner, address spender) private  {
        if (initializedAllowances[owner][spender]) {
            return;
        }
        uint256 slot = super._allowanceSlot(owner, spender);
        uint256 allowance = MirrorNodeLib.getAllowanceFromMirrorNode(owner, spender);
        vm.store(address(this), bytes32(slot), bytes32(allowance));
        initializedAllowances[owner][spender] = true;
    }
}
