// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {HtsSystemContract, HTS_ADDRESS} from "./HtsSystemContract.sol";
import {IERC20} from "./IERC20.sol";
import {IMirrorNode} from "./IMirrorNode.sol";
import {storeString} from "./StrStore.sol";

contract HtsSystemContractJson is HtsSystemContract {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IMirrorNode private _mirrorNode;

    bool private initialized;

    function setMirrorNodeProvider(IMirrorNode mirrorNode_) htsCall external {
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
        bytes4 selector = bytes4(msg.data[24:28]);
        if (selector == IERC20.balanceOf.selector && msg.data.length >= 60) {
            // We have to always read from this memory slot in order to make deal work correctly.
            // bytes memory balance = super.__redirectForToken();
            address account = address(bytes20(msg.data[40:60]));
            _initBalance(account);
            return super.__redirectForToken();
        }
        _initTokenData();
        if (selector == IERC20.transfer.selector && msg.data.length >= 92) {
            address from = msg.sender;
            address to = address(bytes20(msg.data[40:60]));
            _initBalance(from);
            _initBalance(to);
        } else if (selector == IERC20.transferFrom.selector && msg.data.length >= 124) {
            address from = address(bytes20(msg.data[40:60]));
            address to = address(bytes20(msg.data[72:92]));
            address spender = msg.sender;
            _initBalance(from);
            _initBalance(to);
            if (from != spender) {
                _initAllowance(from, spender);
            }
        } else if (selector == IERC20.allowance.selector && msg.data.length >= 92) {
            address owner = address(bytes20(msg.data[40:60]));
            address spender = address(bytes20(msg.data[72:92]));
            _initAllowance(owner, spender);
        } else if (selector == IERC20.approve.selector && msg.data.length >= 92) {
            address from = msg.sender;
            address to = address(bytes20(msg.data[40:60]));
            _initAllowance(from, to);
        }
        return super.__redirectForToken();
    }

    function mirrorNode() private view returns (IMirrorNode) {
        bytes32 slot;
        assembly { slot := _mirrorNode.slot }
        return IMirrorNode(address(uint160(uint256(vm.load(HTS_ADDRESS, slot)))));
    }

    /**
     * @dev Reading Smart Contract's data into it's storage directly from the MirrorNode.
     */
    function _initTokenData() private {
        if (initialized) return;
        
        bytes32 slot;
        string memory json = mirrorNode().getTokenData(address(this));

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

    function _initBalance(address account) private  {
        bytes32 slot = super._balanceOfSlot(account);
        if (vm.load(_scratchAddr(), slot) == bytes32(0)) {
            uint256 amount = 0;
            try mirrorNode().getBalance(address(this), account) returns (string memory json) {
                if (vm.keyExistsJson(json, ".balances[0].balance")) {
                    amount = vm.parseJsonUint(json, ".balances[0].balance");
                }
            } catch {}
            _setValue(slot, bytes32(amount));
        }
    }

    function _initAllowance(address owner, address spender) private  {
        bytes32 slot = super._allowanceSlot(owner, spender);
        if (vm.load(_scratchAddr(), slot) == bytes32(0)) {
            uint256 amount = 0;
            try mirrorNode().getAllowance(address(this), owner, spender) returns (string memory json) {
                if (vm.keyExistsJson(json, ".allowances[0].amount")) {
                    amount = vm.parseJsonUint(json, ".allowances[0].amount");
                }
            } catch {}
            _setValue(slot, bytes32(amount));
        }
    }

    function _setValue(bytes32 slot, bytes32 value) private {
        vm.store(address(this), slot, value);
        vm.store(_scratchAddr(), slot, bytes32(uint(1)));
    }

    function _scratchAddr() private view returns (address) {
        return address(bytes20(keccak256(abi.encode(address(this)))));
    }
}
