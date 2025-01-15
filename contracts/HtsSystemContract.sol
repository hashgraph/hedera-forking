// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20Events, IERC20} from "./IERC20.sol";
import {IERC721, IERC721Events} from "./IERC721.sol";
import {IHRC719} from "./IHRC719.sol";
import {IHederaTokenService} from "./IHederaTokenService.sol";
import {IERC165} from "../lib/forge-std/src/interfaces/IERC165.sol";

address constant HTS_ADDRESS = address(0x167);

contract HtsSystemContract is IHederaTokenService, IERC20Events, IERC721Events {

    // All ERC20 properties are accessed with a `delegatecall` from the Token Proxy.
    // See `__redirectForToken` for more details.
    string internal tokenType;
    string internal name;
    string internal symbol;
    uint8 internal decimals;
    uint256 internal totalSupply;
    TokenInfo internal _tokenInfo;

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
    function getAccountId(address account) htsCall external virtual view returns (uint32 accountId) {
        bytes4 selector = this.getAccountId.selector;
        uint64 pad = 0x0;
        bytes32 slot = bytes32(abi.encodePacked(selector, pad, account));
        assembly { accountId := sload(slot) }
    }

    function getTokenInfo(address token) htsCall external returns (int64 responseCode, TokenInfo memory tokenInfo) {
        require(token != address(0), "getTokenInfo: invalid token");

        (responseCode, tokenInfo) = IHederaTokenService(token).getTokenInfo(token);
    }

    function getNonFungibleTokenInfo(address token, int64 serialNumber)
        htsCall external
        returns (int64, NonFungibleTokenInfo memory) {
        require(token != address(0), "getNonFungibleTokenInfo: invalid token");

        (int64 responseCode, TokenInfo memory tokenInfo) = IHederaTokenService(token).getTokenInfo(token);
        require(responseCode == 22, "getNonFungibleTokenInfo: failed to get token data");
        NonFungibleTokenInfo memory nonFungibleTokenInfo;
        nonFungibleTokenInfo.tokenInfo = tokenInfo;
        nonFungibleTokenInfo.serialNumber = serialNumber;
        nonFungibleTokenInfo.spenderId = IERC721(token).getApproved(uint256(uint64(serialNumber)));
        nonFungibleTokenInfo.ownerId = IERC721(token).ownerOf(uint256(uint64(serialNumber)));

        // ToDo:
        // nonFungibleTokenInfo.metadata = bytes(IERC721(token).tokenURI(uint256(uint64(serialNumber))));
        // nonFungibleTokenInfo.creationTime = int64(0);

        return (responseCode, nonFungibleTokenInfo);
    }

    function getFungibleTokenInfo(address token) htsCall external returns (int64, FungibleTokenInfo memory) {
        require(token != address(0), "getFungibleTokenInfo: invalid token");

        (int64 responseCode, TokenInfo memory tokenInfo) = IHederaTokenService(token).getTokenInfo(token);
        require(responseCode == 22, "getFungibleTokenInfo: failed to get token data");
        FungibleTokenInfo memory fungibleTokenInfo;
        fungibleTokenInfo.tokenInfo = tokenInfo;
        fungibleTokenInfo.decimals =  int32(int8(IERC20(token).decimals()));

        return (responseCode, fungibleTokenInfo);
    }

    function associateTokens(address account, address[] memory tokens) htsCall public returns (int64 responseCode) {
        require(tokens.length > 0, "associateTokens: missing tokens");
        require(account == msg.sender, "associateTokens: Must be signed by the provided Account's key or called from the accounts contract key");
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "associateTokens: invalid token");
            int64 associationResponseCode = IHederaTokenService(tokens[i]).associateToken(account, tokens[i]);
            require(associationResponseCode == 22, "associateTokens: Failed to associate token");
        }
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function transferTokens(
        address token,
        address[] memory accountId,
        int64[] memory amount
    ) htsCall public returns (int64 responseCode) {
        require(token != address(0), "transferTokens: invalid token");
        require(accountId.length > 0, "transferTokens: missing recipients");
        require(amount.length == accountId.length, "transferTokens: inconsistent input");

        int64 total = 0;
        for (uint256 i = 0; i < accountId.length; i++) {
            total += amount[i];
        }
        require(total == 0, "transferTokens: total amount must balance");

        for (uint256 from = 0; from < amount.length; from++) {
            if (amount[from] >= 0) {
                continue;
            }
            for (uint256 to = 0; to < amount.length; to++) {
                if (amount[to] <= 0) {
                    continue;
                }
                int64 transferAmount = amount[to] < -amount[from] ? amount[to] : -amount[from];
                transferToken(token, accountId[from], accountId[to], transferAmount);
                amount[from] += transferAmount;
                amount[to] -= transferAmount;
                if (amount[from] == 0) {
                    break;
                }
            }
        }
        for (uint256 i = 0; i < amount.length; i++) { // Ensure all amounts are fully balanced after processing
            require(amount[i] == 0, "transferTokens: unmatched transfers");
        }
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function transferFrom(
        address token,
        address sender,
        address recipient,
        uint256 amount
    ) htsCall external returns (int64) {
        return transferToken(token, sender, recipient, int64(int256(amount)));
    }

    function transferFromNFT(
        address token,
        address from,
        address to,
        uint256 serialNumber
    ) htsCall external returns (int64) {
        return transferNFT(token, from, to, int64(int256(serialNumber)));
    }

    function transferToken(
        address token,
        address sender,
        address recipient,
        int64 amount
    ) htsCall public returns (int64 responseCode) {
        require(token != address(0), "transferToken: invalid token");
        address from = sender;
        address to = recipient;
        if (amount < 0) {
            from = recipient;
            to = sender;
            amount *= -1;
        }
        require(
            from == msg.sender ||
            IERC20(token).allowance(from, msg.sender) >= uint256(uint64(amount)),
            "transferNFT: unauthorized"
        );
        HtsSystemContract(token)._transferAsHTS(from, to, uint256(uint64(amount)));
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function approve(address token, address spender, uint256 amount) htsCall public returns (int64 responseCode) {
        HtsSystemContract(token).approve(msg.sender, spender, amount);
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function approveNFT(address token, address approved, uint256 serialNumber) htsCall public returns (int64 responseCode) {
        HtsSystemContract(token).approveNFT(msg.sender, approved, serialNumber);
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function setApprovalForAll(
        address token,
        address operator,
        bool approved
    ) htsCall external returns (int64 responseCode) {
        HtsSystemContract(token).setApprovalForAll(msg.sender, operator, approved);
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function transferNFTs(
        address token,
        address[] memory sender,
        address[] memory receiver,
        int64[] memory serialNumber
    ) htsCall external returns (int64 responseCode) {
        require(token != address(0), "transferNFTs: invalid token");
        require(sender.length > 0, "transferNFTs: missing recipients");
        require(receiver.length == sender.length, "transferNFTs: inconsistent input");
        require(serialNumber.length == sender.length, "transferNFTs: inconsistent input");
        for (uint256 i = 0; i < sender.length; i++) {
            transferNFT(token, sender[i], receiver[i], serialNumber[i]);
        }
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function transferNFT(
        address token,
        address sender,
        address recipient,
        int64 serialNumber
    ) htsCall public returns (int64 responseCode) {
        uint256 serialId = uint256(uint64(serialNumber));
        require(
            IERC721(token).ownerOf(serialId) == msg.sender ||
            IERC721(token).getApproved(serialId) == msg.sender ||
            IERC721(token).isApprovedForAll(sender, msg.sender),
            "transferNFT: unauthorized"
        );
        HtsSystemContract(token)._transferNFTAsHTS(sender, recipient, serialId);
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function dissociateTokens(address account, address[] memory tokens) htsCall public returns (int64 responseCode) {
        require(tokens.length > 0, "dissociateTokens: missing tokens");
        require(account == msg.sender, "dissociateTokens: Must be signed by the provided Account's key or called from the accounts contract key");
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "dissociateTokens: invalid token");
            int64 dissociationResponseCode = IHederaTokenService(tokens[i]).dissociateToken(account, tokens[i]);
            require(dissociationResponseCode == 22, "dissociateTokens: Failed to dissociate token");
        }
        responseCode = 22; // HederaResponseCodes.SUCCESS
    }

    function associateToken(address account, address token) htsCall external returns (int64 responseCode) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        return associateTokens(account, tokens);
    }

    function dissociateToken(address account, address token) htsCall external returns (int64 responseCode) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        return dissociateTokens(account, tokens);
    }

    function getTokenExpiryInfo(address token) htsCall external returns (int64 responseCode, Expiry memory tokenInfo) {
        require(token != address(0), "getTokenExpiryInfo: invalid token");

        (responseCode, tokenInfo) = IHederaTokenService(token).getTokenExpiryInfo(token);
    }

    function getApproved(address token, uint256 serialNumber)
        htsCall external view returns (int64 responseCode, address approved) {
        require(token != address(0), "getApproved: invalid token");
        (responseCode, approved) = (int64(22), IERC721(token).getApproved(serialNumber));
    }

    function isApprovedForAll(
        address token,
        address owner,
        address operator
    ) htsCall external view returns (int64, bool) {
        require(token != address(0), "isApprovedForAll: invalid token");
        return (int64(22), IERC721(token).isApprovedForAll(owner, operator));
    }

    function getTokenDefaultFreezeStatus(address token) htsCall external returns (int64, bool) {
        require(token != address(0), "getTokenDefaultFreezeStatus: invalid address");
        return IHederaTokenService(token).getTokenDefaultFreezeStatus(token);
    }

    function getTokenCustomFees(
        address token
    ) htsCall external returns (int64, FixedFee[] memory, FractionalFee[] memory, RoyaltyFee[] memory) {
        require(token != address(0), "getTokenCustomFees: invalid token");
        return IHederaTokenService(token).getTokenCustomFees(token);
    }

    function getTokenDefaultKycStatus(address token) htsCall external returns (int64, bool) {
        require(token != address(0), "getTokenDefaultKycStatus: invalid address");
        return IHederaTokenService(token).getTokenDefaultKycStatus(token);
    }

    function getTokenKey(address token, uint keyType) htsCall external returns (int64, KeyValue memory) {
        require(token != address(0), "getTokenKey: invalid token");
        (int64 responseCode, TokenInfo memory tokenInfo) = IHederaTokenService(token).getTokenInfo(token);
        require(responseCode == 22, "getTokenKey: failed to get token data");
        for (uint256 i = 0; i < tokenInfo.token.tokenKeys.length; i++) {
            if (tokenInfo.token.tokenKeys[i].keyType == keyType) {
                return (22, tokenInfo.token.tokenKeys[i].key);
            }
        }
        KeyValue memory emptyKey;
        return (22, emptyKey);
    }

    function getTokenType(address token) htsCall external returns (int64, int32) {
        require(token != address(0), "getTokenType: invalid address");
        return IHederaTokenService(token).getTokenType(token);
    }

    function isToken(address token) external returns (int64, bool) {
        bytes memory payload = abi.encodeWithSignature("getTokenType(address)", token);
        (bool success, bytes memory returnData) = token.call(payload);
        return (22, success && returnData.length > 0);
    }

    function mintToken(address token, int64 amount, bytes[] memory) htsCall external returns (
        int64 responseCode,
        int64 newTotalSupply,
        int64[] memory serialNumbers
    ) {
        require(token != address(0), "mintToken: invalid token");
        require(amount > 0, "mintToken: invalid amount");

        (int64 tokenInfoResponseCode, TokenInfo memory tokenInfo) = IHederaTokenService(token).getTokenInfo(token);
        require(tokenInfoResponseCode == 22, "mintToken: failed to get token info");

        address treasuryAccount = tokenInfo.token.treasury;
        require(treasuryAccount != address(0), "mintToken: invalid account");

        HtsSystemContract(token)._update(address(0), treasuryAccount, uint256(uint64(amount)));

        responseCode = 22; // HederaResponseCodes.SUCCESS
        newTotalSupply = int64(uint64(IERC20(token).totalSupply()));
        serialNumbers = new int64[](0);
        require(newTotalSupply >= 0, "mintToken: invalid total supply");
    }

    function burnToken(address token, int64 amount, int64[] memory) htsCall external returns (
        int64 responseCode,
        int64 newTotalSupply
    ) {
        require(token != address(0), "burnToken: invalid token");
        require(amount > 0, "burnToken: invalid amount");

        (int64 tokenInfoResponseCode, TokenInfo memory tokenInfo) = IHederaTokenService(token).getTokenInfo(token);
        require(tokenInfoResponseCode == 22, "burnToken: failed to get token info");

        address treasuryAccount = tokenInfo.token.treasury;
        require(treasuryAccount != address(0), "burnToken: invalid account");

        HtsSystemContract(token)._update(treasuryAccount, address(0), uint256(uint64(amount)));

        responseCode = 22; // HederaResponseCodes.SUCCESS
        newTotalSupply = int64(uint64(IERC20(token).totalSupply()));
        require(newTotalSupply >= 0, "burnToken: invalid total supply");
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

        _initTokenData();

        if (keccak256(bytes(tokenType)) == keccak256(bytes("NOT_FOUND"))) {
            revert("redirectForToken: token not found");
        }

        // Internal redirects for HTS methods.
        if (msg.sender == HTS_ADDRESS) {
            if (selector == this.getTokenInfo.selector) {
                require(msg.data.length >= 28, "getTokenInfo: Not enough calldata");
                return abi.encode(22, _tokenInfo);
            }
            if (selector == this.getTokenCustomFees.selector) {
                require(msg.data.length >= 28, "getTokenCustomFees: Not enough calldata");
                return abi.encode(22, _tokenInfo.fixedFees, _tokenInfo.fractionalFees, _tokenInfo.royaltyFees);
            }
            if (selector == this.getTokenDefaultKycStatus.selector) {
                require(msg.data.length >= 28, "getTokenDefaultKycStatus: Not enough calldata");
                return abi.encode(22, _tokenInfo.defaultKycStatus);
            }
            if (selector == this.getTokenDefaultFreezeStatus.selector) {
                require(msg.data.length >= 28, "getTokenDefaultFreezeStatus: Not enough calldata");
                return abi.encode(22, _tokenInfo.token.freezeDefault);
            }
            if (selector == this.getTokenExpiryInfo.selector) {
                require(msg.data.length >= 28, "getTokenExpiryInfo: Not enough calldata");
                return abi.encode(22, _tokenInfo.token.expiry);
            }
            if (selector == this.associateToken.selector) {
                require(msg.data.length >= 48, "associateToken: Not enough calldata");
                address account = address(bytes20(msg.data[40:60]));
                bytes32 slot = _isAssociatedSlot(account);
                assembly { sstore(slot, true) }
                return abi.encode(22);
            }
            if (selector == this.dissociateToken.selector) {
                require(msg.data.length >= 48, "dissociateToken: Not enough calldata");
                address account = address(bytes20(msg.data[40:60]));
                bytes32 slot = _isAssociatedSlot(account);
                assembly { sstore(slot, false) }
                return abi.encode(22);
            }
            if (selector == this.getTokenType.selector) {
                require(msg.data.length >= 28, "getTokenType: Not enough calldata");
                if (keccak256(abi.encodePacked(tokenType)) == keccak256("FUNGIBLE_COMMON")) {
                    return abi.encode(22, int32(0));
                }
                if (keccak256(abi.encodePacked(tokenType)) == keccak256("NON_FUNGIBLE_UNIQUE")) {
                    return abi.encode(22, int32(1));
                }
                return abi.encode(22, int32(-1));
            }
            if (selector == this._transferAsHTS.selector) {
                require(msg.data.length >= 124, "transferAsHTS: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                uint256 amount = uint256(bytes32(msg.data[92:124]));
                _transferAsHTS(from, to, amount);
                return abi.encode(true);
            }
            if (selector == this._transferNFTAsHTS.selector) {
                require(msg.data.length >= 124, "transferNFTAsHTS: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                uint256 serialId = uint256(bytes32(msg.data[92:124]));
                _transferNFTAsHTS(from, to, serialId);
                return abi.encode(true);
            }
            if (selector == this.approve.selector) {
                require(msg.data.length >= 124, "approve: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                uint256 amount = uint256(bytes32(msg.data[92:124]));
                _approve(from, to, amount);
                emit Approval(from, to, amount);
                return abi.encode(true);
            }
            if (selector == this.approveNFT.selector) {
                require(msg.data.length >= 124, "approveNFT: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                uint256 serialId = uint256(bytes32(msg.data[92:124]));
                _approveAsHTS(from, to, serialId, true);
                return abi.encode(true);
            }
            if (selector == this.setApprovalForAll.selector) {
                require(msg.data.length >= 124, "setApprovalForAll: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                bool approved = uint256(bytes32(msg.data[92:124])) == 1;
                _setApprovalForAllAsHTS(from, to, approved);
                return abi.encode(true);
            }
            if (selector == this._update.selector) {
                require(msg.data.length >= 124, "update: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                uint256 amount = uint256(bytes32(msg.data[92:124]));
                _update(from, to, amount);
                return abi.encode(true);
            }
        }

        // Redirect to the appropriate ERC20 method if the token type is fungible.
        if (keccak256(bytes(tokenType)) == keccak256(bytes("FUNGIBLE_COMMON"))) {
            return _redirectForERC20(selector);
        }

        // Redirect to the appropriate ERC721 method if the token type is non-fungible.
        if (keccak256(bytes(tokenType)) == keccak256(bytes("NON_FUNGIBLE_UNIQUE"))) {
            return _redirectForERC721(selector);
        }

        revert ("redirectForToken: token type not supported");
    }

    function _redirectForERC20(bytes4 selector) private returns (bytes memory) {
        if (selector == IERC20.name.selector) {
            return abi.encode(name);
        }
        if (selector == IERC20.decimals.selector) {
            return abi.encode(decimals);
        }
        if (selector == IERC20.totalSupply.selector) {
            return abi.encode(totalSupply);
        }
        if (selector == IERC20.symbol.selector) {
            return abi.encode(symbol);
        }
        if (selector == IERC20.balanceOf.selector) {
            require(msg.data.length >= 60, "balanceOf: Not enough calldata");

            address account = address(bytes20(msg.data[40:60]));
            return abi.encode(__balanceOf(account));
        }
        if (selector == IERC20.transfer.selector) {
            require(msg.data.length >= 92, "transfer: Not enough calldata");

            address to = address(bytes20(msg.data[40:60]));
            uint256 amount = uint256(bytes32(msg.data[60:92]));
            address owner = msg.sender;
            _transfer(owner, to, amount);
            return abi.encode(true);
        }
        if (selector == IERC20.transferFrom.selector) {
            require(msg.data.length >= 124, "transferF: Not enough calldata");

            address from = address(bytes20(msg.data[40:60]));
            address to = address(bytes20(msg.data[72:92]));
            uint256 amount = uint256(bytes32(msg.data[92:124]));
            address spender = msg.sender;

            _spendAllowance(from, spender, amount);
            _transfer(from, to, amount);
            return abi.encode(true);
        }
        if (selector == IERC20.allowance.selector) {
            require(msg.data.length >= 92, "allowance: Not enough calldata");

            address owner = address(bytes20(msg.data[40:60]));
            address spender = address(bytes20(msg.data[72:92]));
            return abi.encode(__allowance(owner, spender));
        }
        if (selector == IERC20.approve.selector) {
            require(msg.data.length >= 92, "approve: Not enough calldata");

            address spender = address(bytes20(msg.data[40:60]));
            uint256 amount = uint256(bytes32(msg.data[60:92]));
            address owner = msg.sender;
            _approve(owner, spender, amount);
            emit Approval(owner, spender, amount);
            return abi.encode(true);
        }
        return _redirectForHRC719(selector);
    }

    function _redirectForERC721(bytes4 selector) private returns (bytes memory) {
        if (selector == IERC721.name.selector) {
            return abi.encode(name);
        }
        if (selector == IERC721.symbol.selector) {
            return abi.encode(symbol);
        }
        if (selector == IERC721.tokenURI.selector) {
            require(msg.data.length >= 60, "tokenURI: Not enough calldata");
            uint256 serialId = uint256(bytes32(msg.data[28:60]));
            return abi.encode(__tokenURI(serialId));
        }
        if (selector == IERC721.totalSupply.selector) {
            return abi.encode(totalSupply);
        }
        if (selector == IERC721.balanceOf.selector) {
            require(msg.data.length >= 60, "balanceOf: Not enough calldata");
            address owner = address(bytes20(msg.data[40:60]));
            return abi.encode(__balanceOf(owner));
        }
        if (selector == IERC721.ownerOf.selector) {
            require(msg.data.length >= 60, "ownerOf: Not enough calldata");
            uint256 serialId = uint256(bytes32(msg.data[28:60]));
            return abi.encode(__ownerOf(serialId));
        }
        if (selector == IERC721.transferFrom.selector) {
            require(msg.data.length >= 124, "transferFrom: Not enough calldata");
            address from = address(bytes20(msg.data[40:60]));
            address to = address(bytes20(msg.data[72:92]));
            uint256 serialId = uint256(bytes32(msg.data[92:124]));
            _transferNFT(from, to, serialId);
            return abi.encode(true);
        }
        if (selector == IERC721.approve.selector) {
            require(msg.data.length >= 92, "approve: Not enough calldata");
            address spender = address(bytes20(msg.data[40:60]));
            uint256 serialId = uint256(bytes32(msg.data[60:92]));
            _approve(spender, serialId, true);
            return abi.encode(true);
        }
        if (selector == IERC721.setApprovalForAll.selector) {
            require(msg.data.length >= 92, "setApprovalForAll: Not enough calldata");
            address operator = address(bytes20(msg.data[40:60]));
            bool approved = uint256(bytes32(msg.data[60:92])) == 1;
            _setApprovalForAll(operator, approved);
            return abi.encode(true);
        }
        if (selector == IERC721.getApproved.selector) {
            require(msg.data.length >= 60, "getApproved: Not enough calldata");
            uint256 serialId = uint256(bytes32(msg.data[28:60]));
            return abi.encode(__getApproved(serialId));
        }
        if (selector == IERC721.isApprovedForAll.selector) {
            require(msg.data.length >= 92, "isApprovedForAll: Not enough calldata");
            address owner = address(bytes20(msg.data[40:60]));
            address operator = address(bytes20(msg.data[72:92]));
            return abi.encode(__isApprovedForAll(owner, operator));
        }
        return _redirectForHRC719(selector);
    }

    function _redirectForHRC719(bytes4 selector) private returns (bytes memory) {
        if (selector == IHRC719.associate.selector) {
            bytes32 slot = _isAssociatedSlot(msg.sender);
            assembly { sstore(slot, true) }
            return abi.encode(true);
        }
        if (selector == IHRC719.dissociate.selector) {
            bytes32 slot = _isAssociatedSlot(msg.sender);
            assembly { sstore(slot, false) }
            return abi.encode(true);
        }
        if (selector == IHRC719.isAssociated.selector) {
            bytes32 slot = _isAssociatedSlot(msg.sender);
            bool res;
            assembly { res := sload(slot) }
            return abi.encode(res);
        }
        revert("redirectForToken: not supported");
    }

    function _initTokenData() internal virtual {
    }

    function _balanceOfSlot(address account) internal virtual returns (bytes32) {
        bytes4 selector = IERC20.balanceOf.selector;
        uint192 pad = 0x0;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(account);
        return bytes32(abi.encodePacked(selector, pad, accountId));
    }

    function _allowanceSlot(address owner, address spender) internal virtual returns (bytes32) {
        bytes4 selector = IERC20.allowance.selector;
        uint160 pad = 0x0;
        uint32 ownerId = HtsSystemContract(HTS_ADDRESS).getAccountId(owner);
        uint32 spenderId = HtsSystemContract(HTS_ADDRESS).getAccountId(spender);
        return bytes32(abi.encodePacked(selector, pad, spenderId, ownerId));
    }

    function _isAssociatedSlot(address account) internal virtual returns (bytes32) {
        bytes4 selector = IHRC719.isAssociated.selector;
        uint192 pad = 0x0;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(account);
        return bytes32(abi.encodePacked(selector, pad, accountId));
    }

    function _tokenUriSlot(uint32 serialId) internal virtual returns (bytes32) {
        bytes4 selector = IERC721.tokenURI.selector;
        uint192 pad = 0x0;
        return bytes32(abi.encodePacked(selector, pad, serialId));
    }

    function _ownerOfSlot(uint32 serialId) internal virtual returns (bytes32) {
        bytes4 selector = IERC721.ownerOf.selector;
        uint192 pad = 0x0;
        return bytes32(abi.encodePacked(selector, pad, serialId));
    }

    function _getApprovedSlot(uint32 serialId) internal virtual returns (bytes32) {
        bytes4 selector = IERC721.getApproved.selector;
        uint192 pad = 0x0;
        return bytes32(abi.encodePacked(selector, pad, serialId));
    }

    function _isApprovedForAllSlot(address owner, address operator) internal virtual returns (bytes32) {
        bytes4 selector = IERC721.isApprovedForAll.selector;
        uint160 pad = 0x0;
        uint32 ownerId = HtsSystemContract(HTS_ADDRESS).getAccountId(owner);
        uint32 operatorId = HtsSystemContract(HTS_ADDRESS).getAccountId(operator);
        return bytes32(abi.encodePacked(selector, pad, ownerId, operatorId));
    }

    function __balanceOf(address account) private returns (uint256 amount) {
        bytes32 slot = _balanceOfSlot(account);
        assembly { amount := sload(slot) }
    }

    function __allowance(address owner, address spender) private returns (uint256 amount) {
        bytes32 slot = _allowanceSlot(owner, spender);
        assembly { amount := sload(slot) }
    }

    function __tokenURI(uint256 serialId) private returns (string memory uri) {
        bytes32 slot = _tokenUriSlot(uint32(serialId));
        string storage _uri;
        assembly { _uri.slot := slot }
        uri = _uri;
    }

    function __ownerOf(uint256 serialId) private returns (address owner) {
        bytes32 slot = _ownerOfSlot(uint32(serialId));
        assembly { owner := sload(slot) }
    }

    function __getApproved(uint256 serialId) private returns (address approved) {
        bytes32 slot = _getApprovedSlot(uint32(serialId));
        assembly { approved := sload(slot) }
    }

    function __isApprovedForAll(address owner, address operator) private returns (bool approvedForAll) {
        bytes32 slot = _isApprovedForAllSlot(owner, operator);
        assembly { approvedForAll := sload(slot) }
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "hts: invalid sender");
        require(to != address(0), "hts: invalid receiver");
        _update(from, to, amount);
        emit Transfer(from, to, amount);
    }

    function _transferAsHTS(address from, address to, uint256 amount) public {
        require(msg.sender == HTS_ADDRESS, "hts: not permitted");
        _transfer(from, to, amount);
    }

    function _transferNFTAsHTS(address from, address to, uint256 serialId) public {
        require(msg.sender == HTS_ADDRESS, "hts: not permitted");
        _transferNFT(from, to, serialId);
    }

    function _transferNFT(address from, address to, uint256 serialId) private {
        require(from != address(0), "hts: invalid sender");
        require(to != address(0), "hts: invalid receiver");

        // Check if the sender is the owner of the token
        bytes32 slot = _ownerOfSlot(uint32(serialId));
        address owner;
        assembly { owner := sload(slot) }
        require(owner == from, "hts: sender is not owner");

        address sender = msg.sender;
        // If the sender is not the owner, check if the sender is approved
        if (sender == HTS_ADDRESS) {
            sender = from;
            require(sender == owner || __isApprovedForAll(owner, sender), "hts: unauthorized");
        }
        if (sender != owner) {
            require(sender == __getApproved(serialId) || __isApprovedForAll(from, sender), "hts: unauthorized");
        }

        // Clear approval
        bytes32 approvalSlot = _getApprovedSlot(uint32(serialId));
        assembly { sstore(approvalSlot, 0) }

        // Clear approval for all
        bytes32 isApprovedForAllSlot = _isApprovedForAllSlot(from, to);
        assembly { sstore(isApprovedForAllSlot, false) }

        // Set the new owner
        assembly { sstore(slot, to) }
        emit Transfer(from, to, serialId);
    }

    function _update(address from, address to, uint256 amount) public {
        if (from == address(0)) {
            totalSupply += amount;
        } else {
            bytes32 fromSlot = _balanceOfSlot(from);
            uint256 fromBalance;
            assembly { fromBalance := sload(fromSlot) }
            require(fromBalance >= amount, "_transfer: insufficient balance");
            assembly { sstore(fromSlot, sub(fromBalance, amount)) }
        }

        if (to == address(0)) {
            totalSupply -= amount;
        } else {
            bytes32 toSlot = _balanceOfSlot(to);
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
        bytes32 allowanceSlot = _allowanceSlot(owner, spender);
        assembly { sstore(allowanceSlot, amount) }
    }

    function _approveAsHTS(address caller, address spender, uint256 serialId, bool isApproved) private {
        require(msg.sender == HTS_ADDRESS, "_approveAsHTS: only allowed for HTS");
        // The caller must own the token or be an approved operator.
        address owner = __ownerOf(serialId);
        require(caller == owner || __getApproved(serialId) == caller || __isApprovedForAll(owner, caller), "_approveAsHTS: unauthorized");

        bytes32 slot = _getApprovedSlot(uint32(serialId));
        address newApproved = isApproved ? spender : address(0);
        assembly { sstore(slot, newApproved) }

        emit Approval(owner, spender, serialId);
    }


    function _setApprovalForAllAsHTS(address owner, address operator, bool approved) private {
        require(msg.sender == HTS_ADDRESS, "_setApprovalForAllAsHTS: only allowed for HTS");
        require(operator != address(0) && operator != owner, "_setApprovalForAllAsHTS: invalid operator");
        bytes32 slot = _isApprovedForAllSlot(owner, operator);
        assembly { sstore(slot, approved) }
        emit ApprovalForAll(owner, operator, approved);
    }

    function _approve(address spender, uint256 serialId, bool isApproved) private {
        // The caller must own the token or be an approved operator.
        address owner = __ownerOf(serialId);
        require(msg.sender == owner || __getApproved(serialId) == msg.sender || __isApprovedForAll(owner, msg.sender), "_approve: unauthorized");

        bytes32 slot = _getApprovedSlot(uint32(serialId));
        address newApproved = isApproved ? spender : address(0);
        assembly { sstore(slot, newApproved) }

        emit Approval(owner, spender, serialId);
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

    function _setApprovalForAll(address operator, bool approved) private {
        address owner = msg.sender;
        require(operator != address(0) && operator != owner, "setApprovalForAll: invalid operator");
        bytes32 slot = _isApprovedForAllSlot(owner, operator);
        assembly { sstore(slot, approved) }
        emit ApprovalForAll(owner, operator, approved);
    }
}
