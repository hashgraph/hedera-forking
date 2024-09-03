// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "./IERC20.sol";

contract HtsSystemContract {

    address private constant HTS_ADDRESS = address(0x167);

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    // address[] public holders;
    // uint256[] public balances; /// account id
    // address[] public allowancesOwners;
    // address[] public allowancesSpenders;
    // uint256[] public allowancesAmounts;
    // address[] public associatedAccounts;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Associated(address indexed account);
    event Dissociated(address indexed account);

    /// @notice Prevents delegatecall into the modified method.
    modifier htsCall() {
        require(address(this) == HTS_ADDRESS, "htsCall: delegated call");
        _;
    }

    /// @dev
    function getAccountId(address account) htsCall external view returns (uint32 accountId) {
        bytes4 selector = HtsSystemContract.getAccountId.selector;
        uint64 pad = 0x0;
        uint256 slot = uint256(bytes32(abi.encodePacked(selector, pad, account)));
        assembly {
            accountId := sload(slot)
        }
    }

    // function transfer(address recipient, uint256 amount) public returns (bool) {
    //     uint256 senderIndex = findIndex(msg.sender, holders);
    //     require(senderIndex != type(uint256).max, "Sender not found");
    //     require(balances[senderIndex] >= amount, "Insufficient balance");
    //     uint256 recipientIndex = findIndex(recipient, allowancesOwners);
    //     if (recipientIndex == type(uint256).max) {
    //         holders.push(recipient);
    //         balances.push(amount);
    //     } else {
    //         balances[recipientIndex] += amount;
    //     }

    //     balances[senderIndex] -= amount;
    //     emit Transfer(msg.sender, recipient, amount);
    //     return true;
    // }

    // function approve(address spender, uint256 amount) public returns (bool) {
    //     uint256 ownerIndex = findIndex(msg.sender, allowancesOwners);
    //     uint256 spenderIndex = findIndex(spender, allowancesSpenders);

    //     if (ownerIndex != type(uint256).max && spenderIndex != type(uint256).max) {
    //         allowancesAmounts[ownerIndex] = amount;
    //     } else {
    //         allowancesOwners.push(msg.sender);
    //         allowancesSpenders.push(spender);
    //         allowancesAmounts.push(amount);
    //     }

    //     emit Approval(msg.sender, spender, amount);
    //     return true;
    // }

    // function findIndex(address account, address[] storage list) internal view returns (uint256) {
    //     for (uint256 i = 0; i < list.length; i++) {
    //         if (list[i] == account) {
    //             return i;
    //         }
    //     }
    //     return type(uint256).max;  // Max uint256 value as not found flag
    // }

    // function associate() public {
    //     require(!isAssociated(msg.sender), "Already associated");
    //     associatedAccounts.push(msg.sender);
    //     emit Associated(msg.sender);
    // }

    // function dissociate() public {
    //     require(isAssociated(msg.sender), "Not associated");
    //     require(__balanceOf(msg.sender) == 0, "Cannot dissociate with non-zero balance");

    //     uint256 index = findIndex(msg.sender, associatedAccounts);
    //     if (index != type(uint256).max) {
    //         associatedAccounts[index] = associatedAccounts[associatedAccounts.length - 1];
    //         associatedAccounts.pop();
    //     }

    //     emit Dissociated(msg.sender);
    // }

    // function isAssociated(address account) public view returns (bool) {
    //     return findIndex(account, associatedAccounts) != type(uint256).max;
    // }

    /// `__redirectForToken` dispatcher.
    fallback (bytes calldata) external returns (bytes memory) {
        // Calldata for a successful `redirectForToken(address,bytes)` call must contain
        // 00: 0x618dc65e (selector for `redirectForToken(address,bytes)`)
        // 04: 0xffffffffffffffffffffffffffffffffffffffff (token address which issue the `delegatecall`)
        // 24: 0xffffffff (selector for HTS method call)
        // 28: (bytes args for HTS method call, is any)
        require(msg.data.length >= 28, "Not enough calldata");

        uint256 fallbackSelector = uint32(bytes4(msg.data[0:4]));
        require(fallbackSelector == 0x618dc65e, "Fallback selector not supported");

        address token = address(bytes20(msg.data[4:24]));
        require(token == address(this), "Calldata token is not caller");

        return __redirectForToken();
    }

    function __redirectForToken() private returns (bytes memory) {
        bytes4 selector = bytes4(msg.data[24:28]);

        if (selector == IERC20.name.selector) {
            return abi.encode(name);
        } else if (selector == IERC20.decimals.selector) {
            return abi.encode(decimals);
        } else if (selector == IERC20.totalSupply.selector) {
            return abi.encode(totalSupply);
        } else if (selector == IERC20.symbol.selector) {
            return abi.encode(symbol);
        } else if (selector == IERC20.balanceOf.selector) {
            require(msg.data.length >= 60, "balanceOf: Not enough calldata");

            address account = address(bytes20(msg.data[40:60]));
            return abi.encode(__balanceOf(account));
        } else if (selector == IERC20.transfer.selector) {
            require(msg.data.length >= 92, "transfer: Not enough calldata");

            // addresses are word padded 
            address to = address(bytes20(msg.data[40:60]));
            uint256 amount = uint256(bytes32(msg.data[60:92]));
            address owner = msg.sender;
            _transfer(owner, to, amount);
            return abi.encode(true);
        } else if (selector == IERC20.transferFrom.selector) {
            require(msg.data.length >= 124, "transferF: Not enough calldata");

            // addresses are word padded 
            address from = address(bytes20(msg.data[40:60]));
            address to = address(bytes20(msg.data[72:92]));
            uint256 amount = uint256(bytes32(msg.data[92:124]));
            _transfer(from, to, amount);
            return abi.encode(true);
        // } else if (selector == IERC20.approve.selector) {
        //     address account = address(bytes20(msg.data[40:60]));
        //     uint256 amount = abi.decode(msg.data[60:92], (uint256));
        //     return abi.encode(approve(account, amount));
        } else if (selector == IERC20.allowance.selector) {
            // addresses are word padded 
            address owner = address(bytes20(msg.data[40:60]));
            address spender = address(bytes20(msg.data[72:92]));
            return abi.encode(__allowance(owner, spender));
        // } else if (selector == bytes4(keccak256("associate()"))) {
        //     return abi.encode(associate());
        // } else if (selector == bytes4(keccak256("dissociate()"))) {
        //     return abi.encode(dissociate());
        // } else if (selector == bytes4(keccak256("isAssociated(address)"))) {
        //     address account = address(bytes20(msg.data[40:60]));
        //     return abi.encode(isAssociated(account));
        }
        revert ("redirectForToken: not supported");
    }

    function _balanceOfSlot(address account) private view returns (uint256 slot) {
        bytes4 selector = IERC20.balanceOf.selector;
        uint192 pad = 0x0;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(account);
        slot = uint256(bytes32(abi.encodePacked(selector, pad, accountId)));
    }

    function __balanceOf(address account) private view returns (uint256 amount) {
        uint256 slot = _balanceOfSlot(account);
        assembly {
            amount := sload(slot)
        }
    }

    function __allowance(address owner, address spender) private view returns (uint256 amount) {
        bytes4 selector = IERC20.allowance.selector;
        uint160 pad = 0x0;
        uint32 ownerId = HtsSystemContract(HTS_ADDRESS).getAccountId(owner);
        uint32 spenderId = HtsSystemContract(HTS_ADDRESS).getAccountId(spender);
        uint256 slot = uint256(bytes32(abi.encodePacked(selector, pad, spenderId, ownerId)));
        assembly {
            amount := sload(slot)
        }
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "hts: invalid sender");
        require(to != address(0), "hts: invalid receiver");

        uint256 fromSlot = _balanceOfSlot(from);
        uint256 fromBalance;
        assembly { fromBalance := sload(fromSlot) }
        require(fromBalance >= amount, "hts: insufficient balance");
        assembly { sstore(fromSlot, sub(fromBalance, amount)) }

        uint256 toSlot = _balanceOfSlot(to);
        uint256 toBalance;
        assembly { toBalance := sload(toSlot) }
        // Solidity's checked arithmetic will revert if this overflows
        // https://soliditylang.org/blog/2020/12/16/solidity-v0.8.0-release-announcement
        uint256 newToBalance = toBalance + amount;
        assembly { sstore(toSlot, newToBalance) }
    }
}