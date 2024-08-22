// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./IERC20.sol";

contract HtsSystemContract is IERC20 {
    string public name = "ArrayToken";
    string public symbol = "ART";
    uint8 public decimals = 18;
    uint256 public override totalSupply;

    address[] public holders;
    uint256[] public balances;
    address[] public allowancesOwners;
    address[] public allowancesSpenders;
    uint256[] public allowancesAmounts;

    address[] public associatedAccounts;

    event Associated(address indexed account);
    event Dissociated(address indexed account);

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply * (10 ** uint256(decimals));
        holders.push(msg.sender);
        balances.push(totalSupply);
    }

    function balanceOf(address account) public view override returns (uint256) {
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == account) {
                return balances[i];
            }
        }
        return 0;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
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

    function allowance(address owner, address spender) public view override returns (uint256) {
        for (uint256 i = 0; i < allowancesOwners.length; i++) {
            if (allowancesOwners[i] == owner && allowancesSpenders[i] == spender) {
                return allowancesAmounts[i];
            }
        }
        return 0;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
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

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
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
        require(balanceOf(msg.sender) == 0, "Cannot dissociate with non-zero balance");

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

    fallback (bytes calldata) external returns (bytes memory) {
        uint selector = uint32(bytes4(msg.data[0:4]));
        address token = address(bytes20(msg.data[4:24]));
        bytes memory args = msg.data[24:];
        return __redirectForToken(token, args);
    }

    function __redirectForToken(address token, bytes memory encodedFunctionSelector) internal returns (bytes memory) {
        bytes4 selector = bytes4(msg.data[24:28]);

        if (selector == bytes4(keccak256("name()"))) {
            return abi.encode(name);
        } else if (selector == bytes4(keccak256("decimals()"))) {
            return abi.encode(decimals);
        } else if (selector == bytes4(keccak256("symbol()"))) {
            return abi.encode(symbol);
        } else if (selector == bytes4(keccak256("balanceOf(address)"))) {
            address account = address(bytes20(msg.data[40:60]));
            return abi.encode(balanceOf(account));
        } else if (selector == bytes4(keccak256("transfer(address,uint256)"))) {
            address account = address(bytes20(msg.data[40:60]));
            uint256 amount = abi.decode(msg.data[60:92], (uint256));
            return abi.encode(transfer(account, amount));
        } else if (selector == bytes4(keccak256("approve(address,uint256)"))) {
            address account = address(bytes20(msg.data[40:60]));
            uint256 amount = abi.decode(msg.data[60:92], (uint256));
            return abi.encode(approve(account, amount));
        } else if (selector == bytes4(keccak256("allowance(address,address)"))) {
            address from = address(bytes20(msg.data[40:60]));
            uint256 to = uint160(address(bytes20(msg.data[60:80])));
            return abi.encode(approve(from, to));
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
        return "";
    }
}