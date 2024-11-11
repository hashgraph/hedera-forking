// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {HtsSystemContract} from "./HtsSystemContract.sol";
import {IERC20} from "./IERC20.sol";
import {MirrorNodeLib} from "./MirrorNodeLib.sol";
import {HVM} from "./HVM.sol";

contract HtsSystemContractFFI is HtsSystemContract {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bool private initialized;

    /*
     * @dev HTS can be used to propagate allow cheat codes flag onto the token Proxies Smart Contracts.
     * We can call `vm.allowCheatcodes` from within the HTS context.
     */
    function allowCheatcodes(address target) htsCall external {
        vm.allowCheatcodes(target);
    }

    // For testing, we support accounts created with `makeAddr`. These accounts will not exist on the mirror node,
    // so we calculate a deterministic (but unique) ID at runtime as a fallback.
    function getAccountId(address account) htsCall public view override returns (uint32) {
        return uint32(bytes4(keccak256(abi.encodePacked(account))));
    }

    function __redirectForToken() internal override returns (bytes memory) {
        HtsSystemContractFFI(HTS_ADDRESS).allowCheatcodes(address(this));
        bytes4 selector = bytes4(msg.data[24:28]);
        if (selector == IERC20.balanceOf.selector && msg.data.length >= 60) {
            // We have to always read from this memory slot in order to make deal work correctly.
            // bytes memory balance = super.__redirectForToken();
            address account = address(bytes20(msg.data[40:60]));
            _initBalance(account);
            return super.__redirectForToken();
        }
        _initializeTokenData();
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

    /**
     * @dev Reading Smart Contract's data into it's storage directly from the MirrorNode.
     */
    function _initializeTokenData() private {
        if (initialized) return;
        
        string memory json = MirrorNodeLib.getTokenData();
        string memory tokenName = abi.decode(vm.parseJson(json, ".name"), (string));
        string memory tokenSymbol = abi.decode(vm.parseJson(json, ".symbol"), (string));
        uint256 totalSupply = vm.parseUint(abi.decode(vm.parseJson(json, ".total_supply"), (string)));
        uint256 decimals = uint8(vm.parseUint(abi.decode(vm.parseJson(json, ".decimals"), (string))));
        HVM.storeString(address(this), HVM.getSlot("name"), tokenName);
        HVM.storeString(address(this), HVM.getSlot("symbol"), tokenSymbol);
        vm.store(address(this), bytes32(HVM.getSlot("decimals")), bytes32(decimals));
        vm.store(address(this), bytes32(HVM.getSlot("totalSupply")), bytes32(totalSupply));
        vm.store(address(this), bytes32(HVM.getSlot("initialized")), bytes32(uint256(1)));
    }

    function _initBalance(address account) private  {
        bytes32 slot = super._balanceOfSlot(account);
        if (vm.load(_scratchAddr(), slot) == bytes32(0)) {
            _setValue(slot, bytes32(MirrorNodeLib.getBalance(account)));
        }
    }

    function _initAllowance(address owner, address spender) private  {
        bytes32 slot = super._allowanceSlot(owner, spender);
        if (vm.load(_scratchAddr(), slot) == bytes32(0)) {
            _setValue(slot, bytes32(MirrorNodeLib.getAllowance(owner, spender)));
        }
    }

    function _setValue(bytes32 slot, bytes32 value) private {
        vm.store(address(this), slot, value);
        vm.store(_scratchAddr(), slot, bytes32(uint(1)));
    }

    /**
     * @dev HTS Storage will be used to keep a track of initialization of storage slot on the token contract.
     * The reason for that is not make the 'deal' test method still working. We can't read from 2 slots of the same
     * smart contract. 1 slot has to be used only, that's why we will use the second smart contract (HTS) memory to hold
     * the initialization status.
     */
    function _scratchAddr() private view returns (address) {
        return address(bytes20(keccak256(abi.encode(address(this)))));
    }
}
