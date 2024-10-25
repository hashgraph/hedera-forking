// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20Events, IERC20} from "./IERC20.sol";
import {MirrorNodeAware} from "./MirrorNodeAware.sol";

import {StdCheats} from "forge-std/StdCheats.sol";

contract HtsSystemContract is StdCheats, IERC20Events, MirrorNodeAware {
    address private constant HTS_ADDRESS = address(0x167);

    // All ERC20 properties are accessed with a `delegatecall` from the Token Proxy.
    // See `__redirectForToken` for more details.
    string private name;
    string private symbol;
    uint8 private decimals;
    uint256 private totalSupply;

    bool private initialized;
    mapping(bytes32 => bool) private initializedApprovals;
    mapping(bytes32 => bool) private initializedBalances;

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
     * @dev Returns the account id (omitting both shard and realm numbers) of the given `address`.
     * The storage adapter, _i.e._, `getHtsStorageAt`, assumes that both shard and realm numbers are zero.
     * Thus, they can be omitted from the account id.
     *
     * See https://docs.hedera.com/hedera/core-concepts/accounts/account-properties
     * for more info on account properties.
     */
    function getAccountId(address account) htsCall external view returns (uint32 accountId) {
        bytes4 selector = HtsSystemContract.getAccountId.selector;
        uint64 pad = 0x0;
        uint256 slot = uint256(bytes32(abi.encodePacked(selector, pad, account)));
        assembly {
            accountId := sload(slot)
        }
        if (accountId == 0) {
            accountId = uint32(bytes4(keccak256(abi.encodePacked(account))));
        }
    }

    /**
     * @dev HTS Storage will be used to keep a track of initialization of storage slot on the token contract.
     * The reason for that is not make the 'deal' test method still working. We can't read from 2 slots of the same
     * smart contract. 1 slot has to be used only, that's why we will use the second smart contract (HTS) memory to hold
     * the initialization status.
     */
    function initializeApproval(address token, address from, address to) public {
        initializedApprovals[keccak256(abi.encodePacked(token, from, to))] = true;
    }

    function isInitializedApproval(address token, address from, address to) public view returns (bool) {
        return initializedApprovals[keccak256(abi.encodePacked(token, from, to))];
    }

    function initializeBalance(address token, address account) public {
        initializedBalances[keccak256(abi.encodePacked(token, account))] = true;
    }

    function isInitializedBalance(address token, address account) public view returns (bool) {
        return initializedBalances[keccak256(abi.encodePacked(token, account))];
    }

    /**
     * @dev Validates `redirectForToken(address,bytes)` dispatcher arguments.
     *
     * The interaction between tokens and HTS System Contract is specified in
     * https://hips.hedera.com/hip/hip-218 and
     * https://hips.hedera.com/hip/hip-719.
     *
     * NOTE: The dispatcher **needs** to be implemented in the `fallback` function.
     * That is, it cannot be implemented as a regular `function`, _i.e._,
     * `function redirectForToken(address token, bytes encodedFunctionSelector) { ... }`.
     * The reason is that the arguments encoding of the Token Proxy, as defined in HIP-719,
     * is different from the Contract ABI Specification[1] arguments encoding.
     * In particular, the Contract ABI Specification states that `address`(`uint160`) is
     * **"padded on the higher-order (left) side with zero-bytes such that the length is 32 bytes"**.
     * Whereas HIP-719 encodes the `address` argument in the `redirectForToken` delegate call with no padding.
     *
     * To see that, we can analyze the HIP-719 Token Proxy fragment that encodes the arguments.
     * Please notice the `redirectForToken(address,bytes)` selector was replaced for clarity.
     *
     * ```yul
     * // (on the caller contract)
     * // calldata [ 0:..]: (bytes for encoded function call)
     * // Before execution
     * // memory   [ 0:32): 0x0
     *
     * mstore(0, 0x618dc65eFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFE)
     * // memory   [ 0:32): 0x0000000000000000618dc65eFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFE
     *
     * calldatacopy(32, 0, calldatasize())
     * // memory   [ 0:32): 0x0000000000000000618dc65eFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFE
     * // memory   [32:..): [bytes for encoded function call]
     *
     * let result := delegatecall(gas(), precompileAddress, 8, add(24, calldatasize()), 0, 0)
     * // (on the callee contract)
     * // calldata [ 0:24): 0x618dc65eFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFE
     * // calldata [24:..): [bytes for encoded function call]
     * ```
     *
     * Given the `address` is not left-padded, this encoding is incompatible with the
     * Contract ABI Specification, and hence a regular function cannot be used.
     *
     * Also notice that _currently_ we do not support direct calls to `redirectForToken`, _i.e._,
     * `address(0x167).redirectForToken(tokenAddr, bytesData)`.
     * The reason being direct calls read storage from `0x167` address.
     * But delegate calls on the other hand read storage from the token address.
     *
     * [1] https://docs.soliditylang.org/en/v0.8.23/abi-spec.html#function-selector-and-argument-encoding
     */
    fallback (bytes calldata) external returns (bytes memory) {
        // Calldata for a successful `redirectForToken(address,bytes)` call must contain
        // 00: 0x618dc65e (selector for `redirectForToken(address,bytes)`)
        // 04: 0xffffffffffffffffffffffffffffffffffffffff (token address which issue the `delegatecall`)
        // 24: 0xffffffff (selector for HTS method call)
        // 28: (bytes args for HTS method call, if any)
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

        if (selector == IERC20.name.selector && !initialized) {
            return abi.encode(_getTokenStringDataFromMirrorNode("name"));
        } else if (selector == IERC20.name.selector && initialized) {
            return abi.encode(name);
        } else if (selector == IERC20.decimals.selector && !initialized) {
            return abi.encode(uint8(vm.parseUint(_getTokenStringDataFromMirrorNode("decimals"))));
        } else if (selector == IERC20.decimals.selector && initialized) {
            return abi.encode(decimals);
        } else if (selector == IERC20.totalSupply.selector && !initialized) {
            return abi.encode(uint256(vm.parseUint(_getTokenStringDataFromMirrorNode("total_supply"))));
        } else if (selector == IERC20.totalSupply.selector && initialized) {
            return abi.encode(totalSupply);
        } else if (selector == IERC20.symbol.selector && !initialized) {
            return abi.encode(_getTokenStringDataFromMirrorNode("symbol"));
        } else if (selector == IERC20.symbol.selector && initialized) {
            return abi.encode(symbol);
        } else if (selector == IERC20.balanceOf.selector) {
            require(msg.data.length >= 60, "balanceOf: Not enough calldata");
            address account = address(bytes20(msg.data[40:60]));
            uint256 inMemory = __balanceOf(account);
            if (inMemory > 0 || HtsSystemContract(HTS_ADDRESS).isInitializedBalance(address(this), account)) {
                return abi.encode(inMemory);
            }
            return abi.encode(_getAccountBalanceFromMirrorNode(account));
        } else if (selector == IERC20.transfer.selector) {
            require(msg.data.length >= 92, "transfer: Not enough calldata");
            address to = address(bytes20(msg.data[40:60]));
            uint256 amount = uint256(bytes32(msg.data[60:92]));
            address owner = msg.sender;
            _initializeTokenData();
            _initializeAccountsRelations(owner, to);
            _transfer(owner, to, amount);
            return abi.encode(true);
        } else if (selector == IERC20.transferFrom.selector) {
            require(msg.data.length >= 124, "transferF: Not enough calldata");
            address from = address(bytes20(msg.data[40:60]));
            address to = address(bytes20(msg.data[72:92]));
            uint256 amount = uint256(bytes32(msg.data[92:124]));
            address spender = msg.sender;
            _initializeTokenData();
            _initializeAccountsRelations(from, to);
            if (from != spender) {
                _initializeAccountsRelations(spender, to);
                _initializeAccountsRelations(from, spender);
            }
            _spendAllowance(from, spender, amount);
            _transfer(from, to, amount);
            return abi.encode(true);
        } else if (selector == IERC20.allowance.selector) {
            require(msg.data.length >= 92, "allowance: Not enough calldata");
            address owner = address(bytes20(msg.data[40:60]));
            address spender = address(bytes20(msg.data[72:92]));
            if (!HtsSystemContract(HTS_ADDRESS).isInitializedApproval(address(this), owner, spender)) {
                return abi.encode(_getAllowanceFromMirrorNode(
                    HtsSystemContract(HTS_ADDRESS).getAccountId(owner),
                    HtsSystemContract(HTS_ADDRESS).getAccountId(spender)
                ));
            }
            return abi.encode(__allowance(owner, spender));
        } else if (selector == IERC20.approve.selector) {
            require(msg.data.length >= 92, "approve: Not enough calldata");
            address spender = address(bytes20(msg.data[40:60]));
            uint256 amount = uint256(bytes32(msg.data[60:92]));
            address owner = msg.sender;
            _initializeTokenData();
            _initializeAccountsRelations(owner, spender);
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
        if (slot == 0) {
            return 0;
        }
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
        require(fromBalance >= amount, "_transfer: insufficient balance");
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
            require(currentAllowance >= amount, "_spendAllowance: insufficient");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Reading Smart Contract's data into it's storage directly from the MirrorNode.
     */
    function _initializeTokenData() private {
        if (initialized) {
            return;
        }
        initialized = true;

        name = _getTokenStringDataFromMirrorNode("name");
        decimals = uint8(vm.parseUint(_getTokenStringDataFromMirrorNode("decimals")));
        totalSupply = uint256(vm.parseUint(_getTokenStringDataFromMirrorNode("total_supply")));
        symbol =  _getTokenStringDataFromMirrorNode("symbol");
    }

    function _initializeAccountsRelations(address firstAccount, address secondAccount) private {
        _initializeAccountBalance(firstAccount);
        _initializeAccountBalance(secondAccount);
        _initializeApproval(firstAccount, secondAccount);
        _initializeApproval(secondAccount, firstAccount);
    }

    function _initializeAccountBalance(address account) private  {
        if (HtsSystemContract(HTS_ADDRESS).isInitializedBalance(address(this), account)) {
            return;
        }

        uint256 slot = _balanceOfSlot(account);
        uint256 accountBalance = _getAccountBalanceFromMirrorNode(account);
        assembly { sstore(slot, accountBalance) }

        HtsSystemContract(HTS_ADDRESS).initializeBalance(address(this), account);
    }

    function _initializeApproval(address owner, address spender) private  {
        if (HtsSystemContract(HTS_ADDRESS).isInitializedApproval(address(this), owner, spender)) {
            return;
        }

        uint256 slot = _allowanceSlot(owner, spender);
        uint256 allowance = _getAllowanceFromMirrorNode(
            HtsSystemContract(HTS_ADDRESS).getAccountId(owner),
            HtsSystemContract(HTS_ADDRESS).getAccountId(spender)
        );
        assembly { sstore(slot, allowance) }

        HtsSystemContract(HTS_ADDRESS).initializeApproval(address(this), owner, spender);
    }
}