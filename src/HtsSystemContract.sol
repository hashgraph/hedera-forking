// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "./IERC20.sol";

contract HtsSystemContract {

    address private constant HTS_ADDRESS = address(0x167);

    string private name;
    string private symbol;
    uint8 private decimals;
    uint256 private totalSupply;

    address[] public holders;
    uint256[] public balances; /// account id
    address[] public allowancesOwners;
    address[] public allowancesSpenders;
    uint256[] public allowancesAmounts;

    address[] public associatedAccounts;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

    function transfer(address recipient, uint256 amount) public returns (bool) {
        uint256 senderIndex = findIndex(msg.sender, holders);
        require(senderIndex != type(uint256).max, "Sender not found");
        require(balances[senderIndex] >= amount, "Insufficient balance");
        uint256 recipientIndex = findIndex(recipient, allowancesOwners);
        if (recipientIndex == type(uint256).max) {
            holders.push(recipient);
            balances.push(amount);
        } else {
            balances[recipientIndex] += amount;
        }

        balances[senderIndex] -= amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        for (uint256 i = 0; i < allowancesOwners.length; i++) {
            if (allowancesOwners[i] == owner && allowancesSpenders[i] == spender) {
                return allowancesAmounts[i];
            }
        }
        return 0;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        uint256 ownerIndex = findIndex(msg.sender, allowancesOwners);
        uint256 spenderIndex = findIndex(spender, allowancesSpenders);

        if (ownerIndex != type(uint256).max && spenderIndex != type(uint256).max) {
            allowancesAmounts[ownerIndex] = amount;
        } else {
            allowancesOwners.push(msg.sender);
            allowancesSpenders.push(spender);
            allowancesAmounts.push(amount);
        }

        emit Approval(msg.sender, spender, amount);
        return true;
    }


    function findIndex(address account, address[] storage list) internal view returns (uint256) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == account) {
                return i;
            }
        }
        return type(uint256).max;  // Max uint256 value as not found flag
    }


    function associate() public {
        require(!isAssociated(msg.sender), "Already associated");
        associatedAccounts.push(msg.sender);
        emit Associated(msg.sender);
    }

    function dissociate() public {
        require(isAssociated(msg.sender), "Not associated");
        require(__balanceOf(msg.sender) == 0, "Cannot dissociate with non-zero balance");

        uint256 index = findIndex(msg.sender, associatedAccounts);
        if (index != type(uint256).max) {
            associatedAccounts[index] = associatedAccounts[associatedAccounts.length - 1];
            associatedAccounts.pop();
        }

        emit Dissociated(msg.sender);
    }

    function isAssociated(address account) public view returns (bool) {
        return findIndex(account, associatedAccounts) != type(uint256).max;
    }

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

    function __redirectForToken() internal returns (bytes memory) {
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
            address account = address(bytes20(msg.data[40:60]));
            return abi.encode(__balanceOf(account));
        } else if (selector == IERC20.transfer.selector) {
            address account = address(bytes20(msg.data[40:60]));
            uint256 amount = abi.decode(msg.data[60:92], (uint256));
            return abi.encode(transfer(account, amount));
        } else if (selector == IERC20.approve.selector) {
            address account = address(bytes20(msg.data[40:60]));
            uint256 amount = abi.decode(msg.data[60:92], (uint256));
            return abi.encode(approve(account, amount));
        } else if (selector == IERC20.allowance.selector) {
            address owner = address(bytes20(msg.data[40:60]));
            address spender = address(bytes20(msg.data[60:80]));
            return abi.encode(__allowance(owner, spender));
        // } else if (selector == bytes4(keccak256("associate()"))) {
        //     return abi.encode(associate());
        // } else if (selector == bytes4(keccak256("dissociate()"))) {
        //     return abi.encode(dissociate());
        } else if (selector == bytes4(keccak256("isAssociated(address)"))) {
            address account = address(bytes20(msg.data[40:60]));
            return abi.encode(isAssociated(account));
        // } else if (selector == bytes4(keccak256("transferFrom(address,address,uint256)"))) {
        //     address from = address(bytes20(msg.data[40:60]));
        //     uint256 to = address(bytes20(msg.data[60:80]));
        //     uint256 amount = abi.decode(msg.data[80:112], (uint256));
        //     return abi.encode(transferFrom(from, to));
        }
        revert ("redirectForToken: not supported");
    }

    function __balanceOf(address account) private view returns (uint256 amount) {
        bytes4 selector = IERC20.balanceOf.selector;
        uint192 pad = 0x0;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(account);
        uint256 slot = uint256(bytes32(abi.encodePacked(selector, pad, accountId)));
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

    function __transferFrom(address sender, address recipient, uint256 amount) private returns (bool) {
        uint256 senderIndex = findIndex(sender, holders);
        uint256 spenderIndex = findIndex(msg.sender, allowancesSpenders);
        require(senderIndex != type(uint256).max, "Sender not found");
        require(allowancesOwners[spenderIndex] == sender, "Sender not authorized");
        require(balances[senderIndex] >= amount, "Insufficient balance");
        require(allowancesAmounts[spenderIndex] >= amount, "Allowance exceeded");

        balances[senderIndex] -= amount;
        allowancesAmounts[spenderIndex] -= amount;

        uint256 recipientIndex = findIndex(recipient, holders);
        if (recipientIndex == type(uint256).max) {
            holders.push(recipient);
            balances.push(amount);
        } else {
            balances[recipientIndex] += amount;
        }

        emit Transfer(sender, recipient, amount);
        return true;
    }
}