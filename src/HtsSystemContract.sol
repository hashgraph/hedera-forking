// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20Events, IERC20} from "./IERC20.sol";

contract HtsSystemContract is IERC20Events {

    address private constant HTS_ADDRESS = address(0x167);

    string private name;
    string private symbol;
    uint8 private decimals;
    uint256 private totalSupply;

    event Associated(address indexed account);
    event Dissociated(address indexed account);

    /**
     * @dev Prevents delegatecall into the modified method.
     */
    modifier htsCall() {
        require(address(this) == HTS_ADDRESS, "htsCall: delegated call");
        _;
    }

    /**
     * @dev
     */
    function getAccountId(address account) htsCall external view returns (uint32 accountId) {
        bytes4 selector = HtsSystemContract.getAccountId.selector;
        uint64 pad = 0x0;
        uint256 slot = uint256(bytes32(abi.encodePacked(selector, pad, account)));
        assembly {
            accountId := sload(slot)
        }
    }

    /**
     * @dev `__redirectForToken` dispatcher.
     */
    fallback (bytes calldata) external returns (bytes memory) {
        // Calldata for a successful `redirectForToken(address,bytes)` call must contain
        // 00: 0x618dc65e (selector for `redirectForToken(address,bytes)`)
        // 04: 0xffffffffffffffffffffffffffffffffffffffff (token address which issue the `delegatecall`)
        // 24: 0xffffffff (selector for HTS method call)
        // 28: (bytes args for HTS method call, is any)
        require(msg.data.length >= 28, "fallback: not enough calldata");

        uint256 fallbackSelector = uint32(bytes4(msg.data[0:4]));
        require(fallbackSelector == 0x618dc65e, "fallback: unsupported selector");

        address token = address(bytes20(msg.data[4:24]));
        require(token == address(this), "fallback: token is not caller");

        return __redirectForToken();
    }

    /**
     * @dev Addresses are word right-padded starting from memory position `28`.
     */
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

            address to = address(bytes20(msg.data[40:60]));
            uint256 amount = uint256(bytes32(msg.data[60:92]));
            address owner = msg.sender;
            _transfer(owner, to, amount);
            return abi.encode(true);
        } else if (selector == IERC20.transferFrom.selector) {
            require(msg.data.length >= 124, "transferF: Not enough calldata");

            address from = address(bytes20(msg.data[40:60]));
            address to = address(bytes20(msg.data[72:92]));
            uint256 amount = uint256(bytes32(msg.data[92:124]));
            address spender = msg.sender;

            _spendAllowance(from, spender, amount);
            _transfer(from, to, amount);
            return abi.encode(true);
        } else if (selector == IERC20.allowance.selector) {
            require(msg.data.length >= 92, "allowance: Not enough calldata");

            address owner = address(bytes20(msg.data[40:60]));
            address spender = address(bytes20(msg.data[72:92]));
            return abi.encode(__allowance(owner, spender));
        } else if (selector == IERC20.approve.selector) {
            require(msg.data.length >= 92, "approve: Not enough calldata");

            address spender = address(bytes20(msg.data[40:60]));
            uint256 amount = uint256(bytes32(msg.data[60:92]));
            address owner = msg.sender;
            _approve(owner, spender, amount);
            emit Approval(owner, spender, amount);
            return abi.encode(true);
        }
        revert ("redirectForToken: not supported");
    }

    function _balanceOfSlot(address account) private view returns (uint256 slot) {
        bytes4 selector = IERC20.balanceOf.selector;
        uint192 pad = 0x0;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(account);
        slot = uint256(bytes32(abi.encodePacked(selector, pad, accountId)));
    }

    function _allowanceSlot(address owner, address spender) private view returns (uint256 slot) {
        bytes4 selector = IERC20.allowance.selector;
        uint160 pad = 0x0;
        uint32 ownerId = HtsSystemContract(HTS_ADDRESS).getAccountId(owner);
        uint32 spenderId = HtsSystemContract(HTS_ADDRESS).getAccountId(spender);
        slot = uint256(bytes32(abi.encodePacked(selector, pad, spenderId, ownerId)));
    }

    function __balanceOf(address account) private view returns (uint256 amount) {
        uint256 slot = _balanceOfSlot(account);
        assembly {
            amount := sload(slot)
        }
    }

    function __allowance(address owner, address spender) private view returns (uint256 amount) {
        uint256 slot = _allowanceSlot(owner, spender);
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

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "_approve: invalid owner");
        require(spender != address(0), "_approve: invalid spender");
        uint256 allowanceSlot = _allowanceSlot(owner, spender);
        assembly {
            sstore(allowanceSlot, amount)
        }
    }

    /**
     * TODO: We might need to optimize the double owner+spender calls to get
     * their account IDs.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) private {
        uint256 currentAllowance = __allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance < amount, "_spendAllowance: insufficient");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}