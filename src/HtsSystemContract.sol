// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20Events, IERC20} from "./IERC20.sol";
import {IHederaTokenService} from "./IHederaTokenService.sol";
import {IHRC719} from "./IHRC719.sol";

contract HtsSystemContract is IHederaTokenService, IERC20Events {

    address internal constant HTS_ADDRESS = address(0x167);

    struct IKey {
        string _type;
        string key;
    }

    struct IFixedFee {
        bool allCollectorsAreExempt;
        int64 amount;
        string collectorAccountId;
        string denominatingTokenId;
    }

    struct IFractionalAmount {
        int64 numerator;
        int64 denominator;
    }

    struct IFractionalFee {
        bool allCollectorsAreExempt;
        IFractionalAmount amount;
        string collectorAccountId;
        string denominatingTokenId;
        int64 maximum;
        int64 minimum;
        bool netOfTransfers;
    }

    struct IRoyaltyFee {
        bool allCollectorsAreExempt;
        IFractionalAmount amount;
        string collectorAccountId;
        IFallbackFee fallbackFee;
    }

    struct IFallbackFee {
        int64 amount;
        string denominatingTokenId;
    }

    struct ICustomFees {
        string createdTimestamp;
        IFixedFee[] fixedFees;
        IFractionalFee[] fractionalFees;
        IRoyaltyFee[] royaltyFees;
    }

    // All ERC20 properties are accessed with a `delegatecall` from the Token Proxy.
    // See `__redirectForToken` for more details.
    string internal name;
    string internal symbol;
    uint8 private decimals;
    uint256 private totalSupply;
    uint256 private maxSupply;
    bool private freezeDefault;
    string private supplyType;
    string private pauseStatus;
    IKey private adminKey;
    IKey private feeScheduleKey;
    IKey private freezeKey;
    IKey private kycKey;
    IKey private pauseKey;
    IKey private supplyKey;
    IKey private wipeKey;
    int64 private expiryTimestamp;
    string private autoRenewAccount;
    int64 private autoRenewPeriod;
    ICustomFees private customFees;
    bool private deleted;
    string private memo;
    string private treasuryAccountId;

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
    function getAccountId(address account) htsCall public virtual view returns (uint32 accountId) {
        // 0xe0b490f7 is the selector for HtsSystemContract.getAccountId.
        // Due to limitations with virtual functions, we use a direct byte assignment here.
        bytes4 selector = 0xe0b490f7;
        uint64 pad = 0x0;
        uint256 slot = uint256(bytes32(abi.encodePacked(selector, pad, account)));
        assembly {
            accountId := sload(slot)
        }
    }

    function getAccountAddress(string memory accountId) htsCall public virtual returns (address evm_address) {
        if (bytes(accountId).length < 4) {
            return address(0);
        }
        // ignore the first 4 characters ("0.0.") to get the account number string
        bytes memory accountIdBytes = bytes(accountId);
        bytes memory accountNumBytes = new bytes(accountIdBytes.length - 4);
        for (uint i = 0; i < accountNumBytes.length; i++) {
            accountNumBytes[i] = accountIdBytes[i + 4];
        }
        uint32 accountNum = uint32(_parseUint(string(accountNumBytes)));

        bytes4 selector = this.getAccountAddress.selector;
        uint192 pad = 0x0;
        uint256 slot = uint256(bytes32(abi.encodePacked(selector, pad, accountNum)));
        assembly {
            evm_address := sload(slot)
        }
    }

    function _tokenInfo() public returns (TokenInfo memory tokenInfo) {
        FixedFee[] memory fixedFees = new FixedFee[](customFees.fixedFees.length);
        for (uint256 i = 0; i < customFees.fixedFees.length; i++) {
            IFixedFee memory fixedFee = customFees.fixedFees[i];

            address denominatingToken = HtsSystemContract(HTS_ADDRESS).getAccountAddress(fixedFee.denominatingTokenId);
            address collectorAccount = HtsSystemContract(HTS_ADDRESS).getAccountAddress(fixedFee.collectorAccountId);

            fixedFees[i] = FixedFee(
                fixedFee.amount,
                denominatingToken,
                denominatingToken == address(0),
                denominatingToken == address(this),
                collectorAccount
            );
        }

        FractionalFee[] memory fractionalFees = new FractionalFee[](customFees.fractionalFees.length);
        for (uint256 i = 0; i < customFees.fractionalFees.length; i++) {
            IFractionalFee memory fractionalFee = customFees.fractionalFees[i];

            address denominatingToken = HtsSystemContract(HTS_ADDRESS).getAccountAddress(fractionalFee.denominatingTokenId);

            fractionalFees[i] = FractionalFee(
                fractionalFee.amount.numerator,
                fractionalFee.amount.denominator,
                fractionalFee.maximum,
                fractionalFee.minimum,
                fractionalFee.netOfTransfers,
                denominatingToken
            );
        }

        RoyaltyFee[] memory royaltyFees = new RoyaltyFee[](customFees.royaltyFees.length);
        for (uint256 i = 0; i < customFees.royaltyFees.length; i++) {
            IRoyaltyFee memory royaltyFee = customFees.royaltyFees[i];

            address collectorAccount = HtsSystemContract(HTS_ADDRESS).getAccountAddress(royaltyFee.collectorAccountId);

            royaltyFees[i] = RoyaltyFee(
                royaltyFee.amount.numerator,
                royaltyFee.amount.denominator,
                royaltyFee.fallbackFee.amount,
                HtsSystemContract(HTS_ADDRESS).getAccountAddress(royaltyFee.fallbackFee.denominatingTokenId),
                collectorAccount == address(0),
                collectorAccount
            );
        }

        TokenKey[] memory tokenKeys = new TokenKey[](7);
        tokenKeys[0] = _createTokenKey(adminKey, 0x1);
        tokenKeys[1] = _createTokenKey(kycKey, 0x2);
        tokenKeys[2] = _createTokenKey(freezeKey, 0x4);
        tokenKeys[3] = _createTokenKey(wipeKey, 0x8);
        tokenKeys[4] = _createTokenKey(supplyKey, 0x10);
        tokenKeys[5] = _createTokenKey(feeScheduleKey, 0x20);
        tokenKeys[6] = _createTokenKey(pauseKey, 0x40);

        // Add detailed checks and logging
        require(maxSupply <= type(uint64).max, "_tokenInfo: maxSupply exceeds uint64 max");
        require(totalSupply <= type(uint64).max, "_tokenInfo: totalSupply exceeds uint64 max");

        int64 maxSupplyInt64 = int64(uint64(maxSupply));
        int64 totalSupplyInt64 = int64(uint64(totalSupply));
        require(maxSupplyInt64 >= 0, "_tokenInfo: maxSupply overflow");
        require(totalSupplyInt64 >= 0, "_tokenInfo: totalSupply overflow");

        address treasury = HtsSystemContract(HTS_ADDRESS).getAccountAddress(treasuryAccountId);
        address autoRenew = HtsSystemContract(HTS_ADDRESS).getAccountAddress(autoRenewAccount);

        tokenInfo = TokenInfo(
            HederaToken(
                name,
                symbol,
                treasury,
                memo,
                _compare(supplyType, "FINITE") == 0,
                maxSupplyInt64,
                freezeDefault,
                tokenKeys,
                Expiry(expiryTimestamp, autoRenew, autoRenewPeriod)
            ),
            totalSupplyInt64,
            deleted,
            false,
            _compare(pauseStatus, "PAUSED") == 0,
            fixedFees,
            fractionalFees,
            royaltyFees,
            "0x00"
        );
    }

    function _createTokenKey(IKey memory key, uint8 keyType) public pure returns (TokenKey memory) {
        return TokenKey(
            keyType,
            KeyValue(
                false,
                address(0),
                _compare(key._type, "ED25519") == 0 ? bytes(key.key) : new bytes(0),
                _compare(key._type, "ECDSA_SECP256K1") == 0 ? bytes(key.key) : new bytes(0),
                address(0)
            )
        );
    }

    /// Mints an amount of the token to the defined treasury account
    /// @param token The token for which to mint tokens. If token does not exist, transaction results in
    ///              INVALID_TOKEN_ID
    /// @param amount Applicable to tokens of type FUNGIBLE_COMMON. The amount to mint to the Treasury Account.
    ///               Amount must be a positive non-zero number represented in the lowest denomination of the
    ///               token. The new supply must be lower than 2^63.
    /// @param metadata Applicable to tokens of type NON_FUNGIBLE_UNIQUE. A list of metadata that are being created.
    ///                 Maximum allowed size of each metadata is 100 bytes
    /// @return responseCode The response code for the status of the request. SUCCESS is 22.
    /// @return newTotalSupply The new supply of tokens. For NFTs it is the total count of NFTs
    /// @return serialNumbers If the token is an NFT the newly generate serial numbers, othersise empty.
    function mintToken(address token, int64 amount, bytes[] memory metadata) htsCall external returns (
        int64 responseCode,
        int64 newTotalSupply,
        int64[] memory serialNumbers
    ) {
        require(token != address(0), "mintToken: invalid token");
        require(amount > 0, "mintToken: invalid amount");
        require(serialNumbers.length == 0, "burnToken: invalid serial numbers");

        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(this.getTokenInfo.selector, token)
        );
        require(success, "Failed to get token info");
        IHederaTokenService.TokenInfo memory tokenInfo = abi.decode(data, (TokenInfo));

        address treasuryAccount = tokenInfo.token.treasury;
        require(treasuryAccount != address(0), "mintToken: invalid account");

        _update(address(0), treasuryAccount, uint64(amount));

        responseCode = 22; // HederaResponseCodes.SUCCESS
        newTotalSupply = int64(uint64(totalSupply));
        serialNumbers = new int64[](0);
        require(newTotalSupply >= 0, "mintToken: invalid total supply");
    }

    /// Burns an amount of the token from the defined treasury account
    /// @param token The token for which to burn tokens. If token does not exist, transaction results in
    ///              INVALID_TOKEN_ID
    /// @param amount  Applicable to tokens of type FUNGIBLE_COMMON. The amount to burn from the Treasury Account.
    ///                Amount must be a positive non-zero number, not bigger than the token balance of the treasury
    ///                account (0; balance], represented in the lowest denomination.
    /// @param serialNumbers Applicable to tokens of type NON_FUNGIBLE_UNIQUE. The list of serial numbers to be burned.
    /// @return responseCode The response code for the status of the request. SUCCESS is 22.
    /// @return newTotalSupply The new supply of tokens. For NFTs it is the total count of NFTs
    function burnToken(address token, int64 amount, int64[] memory serialNumbers) htsCall external returns (
        int64 responseCode,
        int64 newTotalSupply
    ) {
        require(token != address(0), "burnToken: invalid token");
        require(amount > 0, "burnToken: invalid amount");
        require(serialNumbers.length == 0, "burnToken: invalid serial numbers");

        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(this.getTokenInfo.selector, token)
        );
        require(success, "Failed to get token info");
        IHederaTokenService.TokenInfo memory tokenInfo = abi.decode(data, (TokenInfo));

        address treasuryAccount = tokenInfo.token.treasury;
        require(treasuryAccount != address(0), "burnToken: invalid account");

        _update(treasuryAccount, address(0), uint64(amount));

        responseCode = 22; // HederaResponseCodes.SUCCESS
        newTotalSupply = int64(uint64(totalSupply));
        require(newTotalSupply >= 0, "burnToken: invalid total supply");
    }

    function getTokenInfo(address token) external view returns (int64 responseCode, TokenInfo memory tokenInfo) {
        require(token != address(0), "getTokenInfo: invalid token");

        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(this.getTokenInfo.selector, token)
        );
        require(success, "Failed to get token info");
        tokenInfo = abi.decode(data, (TokenInfo));
        responseCode = 22; // HederaResponseCodes.SUCCESS
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

        // Even if the `__redirectForToken` method does not have any formal parameters,
        // it accesses the calldata arguments directly using `msg.data`.
        return __redirectForToken();
    }

    /**
     * @dev Addresses are word right-padded starting from memory position `28`.
     */
    function __redirectForToken() internal virtual returns (bytes memory) {
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
        } else if (selector == IHRC719.associate.selector) {
            uint256 slot = _isAssociatedSlot(msg.sender);
            assembly {
                sstore(slot, true)
            }
            return abi.encode(true);
        } else if (selector == IHRC719.dissociate.selector) {
            uint256 slot = _isAssociatedSlot(msg.sender);
            assembly {
                sstore(slot, false)
            }
            return abi.encode(true);
        } else if (selector == IHRC719.isAssociated.selector) {
            uint256 slot = _isAssociatedSlot(msg.sender);
            bool res;
            assembly {
                res := sload(slot)
            }
            return abi.encode(res);
        } else if (selector == this.getTokenInfo.selector) {
            require(msg.data.length >= 28, "getTokenInfo: Not enough calldata");
            return abi.encode(_tokenInfo());
        }
        revert ("redirectForToken: not supported");
    }

    function _balanceOfSlot(address account) internal view returns (uint256 slot) {
        bytes4 selector = IERC20.balanceOf.selector;
        uint192 pad = 0x0;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(account);
        slot = uint256(bytes32(abi.encodePacked(selector, pad, accountId)));
    }

    function _allowanceSlot(address owner, address spender) internal view returns (uint256 slot) {
        bytes4 selector = IERC20.allowance.selector;
        uint160 pad = 0x0;
        uint32 ownerId = HtsSystemContract(HTS_ADDRESS).getAccountId(owner);
        uint32 spenderId = HtsSystemContract(HTS_ADDRESS).getAccountId(spender);
        slot = uint256(bytes32(abi.encodePacked(selector, pad, spenderId, ownerId)));
    }

    function _isAssociatedSlot(address account) internal view returns (uint256 slot) {
        bytes4 selector = IHRC719.isAssociated.selector;
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
        uint256 slot = _allowanceSlot(owner, spender);
        assembly {
            amount := sload(slot)
        }
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "hts: invalid sender");
        require(to != address(0), "hts: invalid receiver");
        _update(from, to, amount);
        emit Transfer(from, to, amount);
    }

    function _update(address from, address to, uint256 amount) private {
        if (from == address(0)) {
            totalSupply += amount;
        } else {
            uint256 fromSlot = _balanceOfSlot(from);
            uint256 fromBalance;
            assembly { fromBalance := sload(fromSlot) }
            require(fromBalance >= amount, "_transfer: insufficient balance");
            assembly { sstore(fromSlot, sub(fromBalance, amount)) }
        }

        if (to == address(0)) {
            totalSupply -= amount;
        } else {
            uint256 toSlot = _balanceOfSlot(to);
            uint256 toBalance;
            assembly { toBalance := sload(toSlot) }
            // Solidity's checked arithmetic will revert if this overflows
            // https://soliditylang.org/blog/2020/12/16/solidity-v0.8.0-release-announcement
            uint256 newToBalance = toBalance + amount;
            assembly { sstore(toSlot, newToBalance) }
        }
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

    function _compare(string memory _a, string memory _b) public pure returns (int) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;

        uint i = 0;
        while (i + 32 <= minLength) {
            bytes32 aPart;
            bytes32 bPart;
            assembly {
                aPart := mload(add(a, add(32, i)))
                bPart := mload(add(b, add(32, i)))
            }
            if (aPart < bPart) return -1;
            else if (aPart > bPart) return 1;
            i += 32;
        }

        for (; i < minLength; i++) {
            if (a[i] < b[i]) return -1;
            else if (a[i] > b[i]) return 1;
        }

        if (a.length < b.length) return -1;
        else if (a.length > b.length) return 1;
        else return 0;
    }

    function _parseUint(string memory numString) public pure returns (uint) {
        uint val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint i = 0; i < stringBytes.length; i++) {
            require(uint8(stringBytes[i]) >= 48 && uint8(stringBytes[i]) <= 57, "parseUint: invalid string");
            val = val * 10 + (uint8(stringBytes[i]) - 48);
        }
        return val;
    }
}
