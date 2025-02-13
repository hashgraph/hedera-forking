// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "./IERC20.sol";
import {IERC721} from "./IERC721.sol";
import {IHRC719} from "./IHRC719.sol";
import {IHederaTokenService} from "./IHederaTokenService.sol";
import {HederaResponseCodes} from "./HederaResponseCodes.sol";
import {KeyLib} from "./KeyLib.sol";

address constant HTS_ADDRESS = address(0x167);

contract HtsSystemContract is IHederaTokenService {

    /**
     * The slot's value contains the next token ID to use when a token is being created.
     *
     * This slot is used in the `0x167` address.
     * It cannot be used as a state variable directly.
     * This is because JS' `getHtsStorageAt` implementation assumes all state variables
     * declared here are part of the token address space.
     */
    bytes32 private constant _nextTokenIdSlot = keccak256("HtsSystemContract::_nextTokenIdSlot");

    // All state variables belong to an instantiated Fungible/Non-Fungible token.
    // These state variables are accessed with a `delegatecall` from the Token Proxy bytecode.
    // That is, they live in the token address storage space, not in the space of HTS `0x167`.
    // See `__redirectForToken` for more details.
    //
    // Moreover, these variables must match the slots defined in `SetTokenInfo`.
    string internal tokenType;
    uint8 internal decimals;
    TokenInfo internal _tokenInfo;

    /**
     * @dev Prevents delegatecall into the modified method.
     */
    modifier htsCall() {
        require(address(this) == HTS_ADDRESS, "htsCall: delegated call");
        _;
    }

    modifier kyc(address token) {
        require(_isValidKyc(token), "kyc: no kyc granted");
        _;
    }

    modifier notPaused(address token) {
        (, TokenInfo memory info) = getTokenInfo(token);
        require (!_isPaused(token), "unpaused: token paused");
        _;
    }

    modifier notFrozen(address token) {
        (, bool frozen) = isFrozen(token, msg.sender);
        require(!frozen, "notFrozen: token frozen");
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


    /**
     * @dev Performs a cryptocurrency transfer. It takes two input parameters.
     * - transferList - This should be a list of HBAR transactions (send them in the transferList.transfers property)
     *                  that need to be performed when executing this method.
     *                  Remember that this method is non-payable, so you can't use msg.value to send this amount.
     *                  On the Hedera mainnet, HTS is solely responsible for performing this operation.
     *                  It is a service outside of the EVM itself, which makes this possible. However, it is much more
     *                  difficult to perform on a standalone fork created by a third party, such as Hardhat.
     *                  Forge supports cheat codes, so in the version of the Hedera-forking library dedicated to Foundry,
     *                  HBAR transactions are supported.
     *                  It will NOT be supported on the Hardhat plugin, though. Make sure not to use it.
     * - tokenTransfers - Each object in tokenTransfers shares the token address field, but each of them additionally
     *                    supports separate lists of fungible and non-fungible tokens, respectively. NFT transaction
     *                    interfaces are similar to IERC721, so to understand how to prepare a request, refer to the
     *                    IERC721 transfer methods description.
     *                    The isApproval flag indicates that the sender of the transaction (msg.sender) is attempting
     *                    to transfer someone else's token (ownerId != msg.sender).
     *                    Make sure to set the proper value of this flag when using the crypto transfer method.
     *                    It is not enough to simply specify whose token you want to send and to whom.
     *                    You must explicitly indicate that you are aware you are not the owner of the token by setting
     *                    isApproval = true (or if you are sending your own token, set isApproval = false).
     *                    Remember that this method, unlike IERC721, will not revert if you attempt an operation
     *                    you are not authorized to perform. Instead, it will return a non-success response code,
     *                    but the transaction will still be mined, and the associated fees will be collected.
     *
     * The interface for fungible token and HBAR transfers is completely different from the default ERC20 interface.
     * In ERC20, you specify who sends a given amount to whom. However, in Hedera's crypto transfer, it is a bit
     * more complex. You must explicitly define the expected balance changes for each account in the array.
     *
     * For example, to transfer an amount of 5 from account A to account B, you need to send two transactions in
     * the array: the first transaction should record a balance change of -5 on account A, and the second transaction
     * should record a balance change of +5 on account B.
     *
     * When creating the "from" transaction (where a negative amount indicates the spender), if you intend to spend
     * an allowance granted by another account (accountID !== msg.sender), you must explicitly indicate this by
     * setting the isApproval flag to true. If the spender account (the account in the array with a negative amount)
     * is the same as msg.sender, keep the isApproval flag set to false.
     *
     * By implementing the method in this way, it is possible to send a specified amount of HBAR or tokens from one
     * account to multiple recipients within a single transaction. You can also facilitate multiple senders transferring
     * to a single recipient, or multiple senders to multiple recipients.
     * Just remember that the total sum of all transactions (which actually represent balance changes rather than
     * transactions per se—think of them that way) must equal zero. If account B is to receive an amount of 1,
     * you must ensure that the sum of all transfers with negative amounts totals -1.
     */
    function cryptoTransfer(TransferList memory transferList, TokenTransferList[] memory tokenTransfers)
        htsCall external returns (int64) {
        int64 responseCode = _checkCryptoFungibleTransfers(address(0), transferList.transfers);
        if (responseCode != HederaResponseCodes.SUCCESS) return responseCode;

        for (uint256 tokenIndex = 0; tokenIndex < tokenTransfers.length; tokenIndex++) {
            require(tokenTransfers[tokenIndex].token != address(0), "cryptoTransfer: invalid token");
            require(!_isFrozen(tokenTransfers[tokenIndex].token), "cryptoTransfer: frozen");
            require(_isValidKyc(tokenTransfers[tokenIndex].token), "cryptoTransfer: no kyc granted");
            require(!_isPaused(tokenTransfers[tokenIndex].token), "cryptoTransfer: is paused");
            // Processing fungible token transfers
            responseCode = _checkCryptoFungibleTransfers(tokenTransfers[tokenIndex].token, tokenTransfers[tokenIndex].transfers);
            if (responseCode != HederaResponseCodes.SUCCESS) return responseCode;
            AccountAmount[] memory transfers = tokenTransfers[tokenIndex].transfers;
            for (uint256 from = 0; from < transfers.length; from++) {
                if (transfers[from].amount >= 0) continue;
                for (uint256 to = 0; to < transfers.length; to++) {
                    if (transfers[to].amount <= 0) continue;
                    int64 transferAmount = transfers[to].amount < -transfers[from].amount
                        ? transfers[to].amount : -transfers[from].amount;
                    transferToken(
                        tokenTransfers[tokenIndex].token,
                        transfers[from].accountID,
                        transfers[to].accountID,
                        transferAmount
                    );
                    transfers[from].amount += transferAmount;
                    transfers[to].amount -= transferAmount;
                    if (transfers[from].amount == 0) break;
                }
            }

            // Processing non-fungible token transfers
            // The IERC721 interface already handles all crucial validations and operations,
            // but HTS interface need to return correct response code instead of reverting the whole operations.
            for (uint256 nftIndex = 0; nftIndex < tokenTransfers[tokenIndex].nftTransfers.length; nftIndex++) {
                NftTransfer memory transfer = tokenTransfers[tokenIndex].nftTransfers[nftIndex];

                // Check if NFT transfer is feasible.
                if (transfer.senderAccountID != msg.sender) {
                    if (!transfer.isApproval) return HederaResponseCodes.SENDER_DOES_NOT_OWN_NFT_SERIAL_NO;
                    address token = tokenTransfers[tokenIndex].token;
                    bool approvedForAll = IERC721(token).isApprovedForAll(transfer.senderAccountID, msg.sender);
                    bool approved = IERC721(token).getApproved(uint256(uint64(transfer.serialNumber))) == msg.sender;
                    if (!approvedForAll && !approved) return HederaResponseCodes.SENDER_DOES_NOT_OWN_NFT_SERIAL_NO;
                }
                transferNFT(
                    tokenTransfers[tokenIndex].token,
                    transfer.senderAccountID,
                    transfer.receiverAccountID,
                    transfer.serialNumber
                );
            }
        }

        // Processing HBAR transfers
        // To ensure stability, this operation is performed last since the Foundry library implementation
        // uses forge cheat codes and FT or NFT transfers may potentially trigger reverts.
        for (uint256 i = 0; i < transferList.transfers.length; i++) {
            bool from = transferList.transfers[i].amount < 0;
            address account = transferList.transfers[i].isApproval || !from
                ? transferList.transfers[i].accountID
                : msg.sender;
            uint256 amount = uint256(uint64(
                from ? -transferList.transfers[i].amount : transferList.transfers[i].amount
            ));
            int64 updatingResult = _updateHbarBalanceOnAccount(
                account, from ? account.balance - amount : account.balance + amount
            );
            if (updatingResult != HederaResponseCodes.SUCCESS) revert("cryptoTransfer: hbar transfer is not supported without vm cheatcodes in forked network");
            if (from && account != msg.sender) {
                _approve(account, msg.sender, __allowance(account, msg.sender) - amount);
            }
        }

        return HederaResponseCodes.SUCCESS;
    }


    function mintToken(address token, int64 amount, bytes[] memory) htsCall
        notFrozen(token) kyc(token) notPaused(token) external returns (
        int64 responseCode,
        int64 newTotalSupply,
        int64[] memory serialNumbers
    ) {
        return _mintToken(token, amount, true);
    }

    function _mintToken(address token, int64 amount, bool checkSupplyKey) private returns (
        int64 responseCode,
        int64 newTotalSupply,
        int64[] memory serialNumbers
    ) {
        require(amount > 0, "mintToken: invalid amount");

        (int64 tokenInfoResponseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        if (checkSupplyKey && !KeyLib.keyExists(0x10, tokenInfo)) { // 0x10 - supply key
            return (HederaResponseCodes.TOKEN_HAS_NO_SUPPLY_KEY, tokenInfo.totalSupply, new int64[](0));
        }
        require(tokenInfoResponseCode == HederaResponseCodes.SUCCESS, "mintToken: failed to get token info");

        address treasuryAccount = tokenInfo.token.treasury;
        require(treasuryAccount != address(0), "mintToken: invalid account");

        HtsSystemContract(token)._update(address(0), treasuryAccount, uint256(uint64(amount)));

        responseCode = HederaResponseCodes.SUCCESS;
        newTotalSupply = int64(uint64(IERC20(token).totalSupply()));
        serialNumbers = new int64[](0);
        require(newTotalSupply >= 0, "mintToken: invalid total supply");
    }

    function burnToken(address token, int64 amount, int64[] memory) htsCall
        notFrozen(token) kyc(token) notPaused(token) external returns (
        int64 responseCode,
        int64 newTotalSupply
    ) {
        require(amount > 0, "burnToken: invalid amount");
        (int64 tokenInfoResponseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        if (!KeyLib.keyExists(0x10, tokenInfo)) {
            return (HederaResponseCodes.TOKEN_HAS_NO_SUPPLY_KEY, tokenInfo.totalSupply);
        }
        require(tokenInfoResponseCode == HederaResponseCodes.SUCCESS, "burnToken: failed to get token info");

        address treasuryAccount = tokenInfo.token.treasury;
        require(treasuryAccount != address(0), "burnToken: invalid account");

        HtsSystemContract(token)._update(treasuryAccount, address(0), uint256(uint64(amount)));

        responseCode = HederaResponseCodes.SUCCESS;
        newTotalSupply = int64(uint64(IERC20(token).totalSupply()));
        require(newTotalSupply >= 0, "burnToken: invalid total supply");
    }

    function associateTokens(address account, address[] memory tokens) htsCall public returns (int64 responseCode) {
        require(tokens.length > 0, "associateTokens: missing tokens");
        require(
            account == msg.sender,
            "associateTokens: Must be signed by the provided Account's key or called from the accounts contract key"
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "associateTokens: invalid token");
            require(!_isFrozen(tokens[i]), "associateTokens: frozen");
            require(_isValidKyc(tokens[i]), "associateTokens: no kyc granted");
            require(!_isPaused(tokens[i]), "associateTokens: paused");
            int64 associationResponseCode = IHederaTokenService(tokens[i]).associateToken(account, tokens[i]);
            require(
                associationResponseCode == HederaResponseCodes.SUCCESS,
                "associateTokens: Failed to associate token"
            );
        }
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function associateToken(address account, address token) htsCall
        notFrozen(token) kyc(token) notPaused(token) external returns (int64 responseCode) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        return associateTokens(account, tokens);
    }

    function dissociateTokens(address account, address[] memory tokens) htsCall public returns (int64 responseCode) {
        require(tokens.length > 0, "dissociateTokens: missing tokens");
        require(account == msg.sender, "dissociateTokens: Must be signed by the provided Account's key or called from the accounts contract key");
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "dissociateTokens: invalid token");
            require(!_isFrozen(tokens[i]), "dissociateTokens: frozen");
            require(_isValidKyc(tokens[i]), "dissociateTokens: no kyc granted");
            require(!_isPaused(tokens[i]), "dissociateTokens: paused");
            int64 dissociationResponseCode = IHederaTokenService(tokens[i]).dissociateToken(account, tokens[i]);
            require(dissociationResponseCode == HederaResponseCodes.SUCCESS, "dissociateTokens: Failed to dissociate token");
        }
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function dissociateToken(address account, address token) htsCall
        notFrozen(token) kyc(token) notPaused(token) external returns (int64 responseCode) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        return dissociateTokens(account, tokens);
    }

    /**
     * The side effect of this function is to "deploy" proxy bytecode at `tokenAddress`.
     * The `sload` will trigger a `eth_getStorageAt` in the Forwarder that enables the
     * proxy bytecode at `tokenAddress`.
     */
    function deployHIP719Proxy(address tokenAddress) virtual internal {
        bytes4 selector = 0x400f4ef3; // cast sig 'deployHIP719Proxy(address)'
        bytes32 slot = bytes32(abi.encodePacked(selector, uint64(0), tokenAddress));
        // add `sstore` to avoid `sload` from getting optimized away
        assembly { sstore(slot, add(sload(slot), 1)) }
    }

    function _createToken(
        string memory tokenType_,
        HederaToken memory token,
        int64 initialTotalSupply,
        int32 decimals_,
        FixedFee[] memory fixedFees,
        FractionalFee[] memory fractionalFees,
        RoyaltyFee[] memory royaltyFees
    ) private returns (int64 responseCode, address tokenAddress) {
        require(msg.value > 0, "HTS: must send HBARs");
        require(bytes(token.name).length > 0, "HTS: name cannot be empty");
        require(bytes(token.symbol).length > 0, "HTS: symbol cannot be empty");
        require(token.treasury != address(0), "HTS: treasury cannot be zero-address");
        require(initialTotalSupply >= 0, "HTS: initialTotalSupply cannot be negative");
        require(decimals_ >= 0, "HTS: decimals cannot be negative");

        TokenInfo memory tokenInfo;
        tokenInfo.token = token;
        tokenInfo.totalSupply = 0;
        tokenInfo.deleted = false;
        tokenInfo.defaultKycStatus = true;
        tokenInfo.pauseStatus = false;
        tokenInfo.fixedFees = fixedFees;
        tokenInfo.fractionalFees = fractionalFees;
        tokenInfo.royaltyFees = royaltyFees;
        tokenInfo.ledgerId = "0x03";

        bytes32 nextTokenIdSlot = _nextTokenIdSlot;
        uint160 nextTokenId;
        assembly { nextTokenId := sload(nextTokenIdSlot) }
        if (nextTokenId == 0) {
            nextTokenId = 1031;
        }
        nextTokenId++;
        assembly { sstore(nextTokenIdSlot, nextTokenId) }

        tokenAddress = address(nextTokenId);

        deployHIP719Proxy(tokenAddress);
        HtsSystemContract(tokenAddress).__setTokenInfo(tokenType_, tokenInfo, decimals_);

        if (initialTotalSupply > 0) {
            _mintToken(tokenAddress, initialTotalSupply, false);
        }

        responseCode = HederaResponseCodes.SUCCESS;
    }

    function createFungibleToken(
        HederaToken memory token,
        int64 initialTotalSupply,
        int32 decimals_
    ) htsCall external payable returns (int64 responseCode, address tokenAddress) {
        FixedFee[] memory fixedFees = new FixedFee[](0);
        FractionalFee[] memory fractionalFees = new FractionalFee[](0);
        RoyaltyFee[] memory royaltyFees = new RoyaltyFee[](0);
        return _createToken("FUNGIBLE_COMMON", token, initialTotalSupply, decimals_, fixedFees, fractionalFees, royaltyFees);
    }

    function createFungibleTokenWithCustomFees(
        HederaToken memory token,
        int64 initialTotalSupply,
        int32 decimals_,
        FixedFee[] memory fixedFees,
        FractionalFee[] memory fractionalFees
    ) htsCall external payable returns (int64 responseCode, address tokenAddress) {
        RoyaltyFee[] memory royaltyFees = new RoyaltyFee[](0);
        return _createToken("FUNGIBLE_COMMON", token, initialTotalSupply, decimals_, fixedFees, fractionalFees, royaltyFees);
    }

    function createNonFungibleToken(
        HederaToken memory token
    ) htsCall external payable returns (int64 responseCode, address tokenAddress) {
        FixedFee[] memory fixedFees = new FixedFee[](0);
        FractionalFee[] memory fractionalFees = new FractionalFee[](0);
        RoyaltyFee[] memory royaltyFees = new RoyaltyFee[](0);
        return _createToken("NON_FUNGIBLE_UNIQUE", token, 0, 0, fixedFees, fractionalFees, royaltyFees);
    }

    function createNonFungibleTokenWithCustomFees(
        HederaToken memory token,
        FixedFee[] memory fixedFees,
        RoyaltyFee[] memory royaltyFees
    ) htsCall external payable returns (int64 responseCode, address tokenAddress) {
        FractionalFee[] memory fractionalFees = new FractionalFee[](0);
        return _createToken("NON_FUNGIBLE_UNIQUE", token, 0, 0, fixedFees, fractionalFees, royaltyFees);
    }

    function transferTokens(
        address token,
        address[] memory accountId,
        int64[] memory amount
    ) htsCall notFrozen(token) kyc(token) notPaused(token) external returns (int64 responseCode) {
        require(accountId.length > 0, "transferTokens: missing recipients");
        require(amount.length == accountId.length, "transferTokens: inconsistent input");
        for (uint256 i = 0; i < accountId.length; i++) {
            responseCode = transferToken(token, msg.sender, accountId[i], amount[i]);
            require(responseCode == HederaResponseCodes.SUCCESS, "transferTokens: transfer failed");
        }
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function transferNFTs(
        address token,
        address[] memory sender,
        address[] memory receiver,
        int64[] memory serialNumber
    ) htsCall notFrozen(token) kyc(token) notPaused(token) external returns (int64 responseCode) {
        require(token != address(0), "transferNFTs: invalid token");
        require(sender.length > 0, "transferNFTs: missing recipients");
        require(receiver.length == sender.length, "transferNFTs: inconsistent input");
        require(serialNumber.length == sender.length, "transferNFTs: inconsistent input");
        for (uint256 i = 0; i < sender.length; i++) {
            transferNFT(token, sender[i], receiver[i], serialNumber[i]);
        }
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function transferToken(
        address token,
        address sender,
        address recipient,
        int64 amount
    ) htsCall notFrozen(token) kyc(token) notPaused(token) public returns (int64 responseCode) {
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
        HtsSystemContract(token).transferFrom(msg.sender, from, to, uint256(uint64(amount)));
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function transferNFT(
        address token,
        address sender,
        address recipient,
        int64 serialNumber
    ) htsCall notFrozen(token) kyc(token) notPaused(token) public returns (int64 responseCode) {
        uint256 serialId = uint256(uint64(serialNumber));
        HtsSystemContract(token).transferFromNFT(msg.sender, sender, recipient, serialId);
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function approve(address token, address spender, uint256 amount) htsCall
        notFrozen(token) kyc(token) notPaused(token) public returns (int64 responseCode) {
        HtsSystemContract(token).approve(msg.sender, spender, amount);
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function transferFrom(
        address token,
        address sender,
        address recipient,
        uint256 amount
    ) htsCall notFrozen(token) kyc(token) notPaused(token) external returns (int64) {
        return transferToken(token, sender, recipient, int64(int256(amount)));
    }

    function allowance(address token, address owner, address spender) htsCall
        notFrozen(token) kyc(token) notPaused(token) external view returns (int64, uint256) {
        return (HederaResponseCodes.SUCCESS, IERC20(token).allowance(owner, spender));
    }

    function approveNFT(
        address token,
        address approved,
        uint256 serialNumber
    ) htsCall notFrozen(token) kyc(token) notPaused(token) public returns (int64 responseCode) {
        HtsSystemContract(token).approveNFT(msg.sender, approved, serialNumber);
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function transferFromNFT(
        address token,
        address from,
        address to,
        uint256 serialNumber
    ) htsCall notFrozen(token) kyc(token) notPaused(token) external returns (int64) {
        return transferNFT(token, from, to, int64(int256(serialNumber)));
    }

    function getApproved(address token, uint256 serialNumber)
        htsCall external view returns (int64 responseCode, address approved) {
        require(token != address(0), "getApproved: invalid token");
        (responseCode, approved) = (HederaResponseCodes.SUCCESS, IERC721(token).getApproved(serialNumber));
    }

    function setApprovalForAll(
        address token,
        address operator,
        bool approved
    ) htsCall notFrozen(token) kyc(token) notPaused(token) external returns (int64 responseCode) {
        HtsSystemContract(token).setApprovalForAll(msg.sender, operator, approved);
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function isApprovedForAll(
        address token,
        address owner,
        address operator
    ) htsCall external view returns (int64, bool) {
        require(token != address(0), "isApprovedForAll: invalid token");
        return (HederaResponseCodes.SUCCESS, IERC721(token).isApprovedForAll(owner, operator));
    }

    function isKyc(address token, address account) htsCall public view returns (int64, bool) {
        return IHederaTokenService(token).isKyc(msg.sender, account);
    }

    function _isValidKyc(address token) private view returns (bool) {
        if (msg.sender == HTS_ADDRESS) return true; // Usable only on the highest level call
        (, TokenInfo memory info) = getTokenInfo(token);
        address allowed = getKeyOwner(token, 0x2);
        if (allowed == address(0) || allowed == msg.sender) return true;
        (, bool hasKyc) =  isKyc(token, msg.sender);
        return hasKyc;
    }

    function _isPaused(address token) private view returns (bool) {
        if (msg.sender == HTS_ADDRESS) return true; // Usable only on the highest level call
        (, TokenInfo memory info) = getTokenInfo(token);
        return info.pauseStatus;
    }

    function isFrozen(address token, address account) htsCall public view returns (int64, bool) {
        if (token == address(0)) {
            return (HederaResponseCodes.SUCCESS, false);
        }
        return IHederaTokenService(token).isFrozen(token, account);
    }

    function _isFrozen(address token) private view returns (bool frozenStatus) {
        (, frozenStatus)  = isFrozen(token, msg.sender);
    }

    function getTokenCustomFees(
        address token
    ) htsCall external view returns (int64, FixedFee[] memory, FractionalFee[] memory, RoyaltyFee[] memory) {
        (int64 responseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        return (responseCode, tokenInfo.fixedFees, tokenInfo.fractionalFees, tokenInfo.royaltyFees);
    }

    function getTokenDefaultFreezeStatus(address token) htsCall external view returns (int64, bool) {
        (int64 responseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        return (responseCode, tokenInfo.token.freezeDefault);
    }

    function getTokenDefaultKycStatus(address token) htsCall external view returns (int64, bool) {
        (int64 responseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        return (responseCode, tokenInfo.defaultKycStatus);
    }

    function getTokenExpiryInfo(address token) htsCall external view returns (int64, Expiry memory expiry) {
        (int64 responseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        return (responseCode, tokenInfo.token.expiry);
    }

    function getFungibleTokenInfo(address token) htsCall external view returns (int64, FungibleTokenInfo memory) {
        (int64 responseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        require(responseCode == HederaResponseCodes.SUCCESS, "getFungibleTokenInfo: failed to get token data");
        FungibleTokenInfo memory fungibleTokenInfo;
        fungibleTokenInfo.tokenInfo = tokenInfo;
        fungibleTokenInfo.decimals =  int32(int8(IERC20(token).decimals()));

        return (responseCode, fungibleTokenInfo);
    }

    function getTokenInfo(address token) htsCall public view returns (int64, TokenInfo memory) {
        require(token != address(0), "getTokenInfo: invalid token");

        return IHederaTokenService(token).getTokenInfo(token);
    }

    function getTokenKey(address token, uint keyType) htsCall view external returns (int64, KeyValue memory) {
        (int64 responseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        require(responseCode == HederaResponseCodes.SUCCESS, "getTokenKey: failed to get token data");
        for (uint256 i = 0; i < tokenInfo.token.tokenKeys.length; i++) {
            if (tokenInfo.token.tokenKeys[i].keyType == keyType) {
                return (HederaResponseCodes.SUCCESS, tokenInfo.token.tokenKeys[i].key);
            }
        }
        KeyValue memory emptyKey;
        return (HederaResponseCodes.SUCCESS, emptyKey);
    }

    function getNonFungibleTokenInfo(address token, int64 serialNumber)
        htsCall external view
        returns (int64, NonFungibleTokenInfo memory) {
        (int64 responseCode, TokenInfo memory tokenInfo) = getTokenInfo(token);
        require(responseCode == HederaResponseCodes.SUCCESS, "getNonFungibleTokenInfo: failed to get token data");
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

    function freezeToken(address token, address account) htsCall kyc(token) notPaused(token) external returns (int64 responseCode) {
        require(getKeyOwner(token, 0x4) == msg.sender, "freezeToken: only allowed for freezable tokens");
        responseCode = IHederaTokenService(token).freezeToken(token, account);
    }

    function unfreezeToken(address token, address account) htsCall kyc(token) notPaused(token) external returns (int64 responseCode) {
        require(getKeyOwner(token, 0x4) == msg.sender, "unfreezeToken: Only allowed for freezable key");
        responseCode = IHederaTokenService(token).unfreezeToken(token, account);
    }

    function grantTokenKyc(address token, address account) htsCall
        notFrozen(token) kyc(token) notPaused(token) external returns (int64 responseCode) {
        require(getKeyOwner(token, 0x2) != address(0), "grantTokenKyc: only allowed for kyc tokens");
        responseCode = IHederaTokenService(token).grantTokenKyc(token, account);
    }

    function revokeTokenKyc(address token, address account) htsCall
        notFrozen(token) kyc(token) notPaused(token) external returns (int64 responseCode) {
        require(getKeyOwner(token, 0x2) != address(0), "revokeTokenKyc: only allowed for kyc tokens");
        responseCode = IHederaTokenService(token).revokeTokenKyc(token, account);
    }

    function pauseToken(address token) htsCall notFrozen(token) kyc(token) external returns (int64 responseCode) {
        require(getKeyOwner(token, 0x40) == msg.sender, "pauseToken: only allowed for pause key");
        responseCode = IHederaTokenService(token).pauseToken(token);
    }

    function unpauseToken(address token) htsCall notFrozen(token)  kyc(token) external returns (int64 responseCode) {
        require(getKeyOwner(token, 0x40) == msg.sender, "pauseToken: only allowed for pause key");
        responseCode = IHederaTokenService(token).unpauseToken(token);
    }

    function isToken(address token) htsCall external view returns (int64, bool) {
        bytes memory payload = abi.encodeWithSignature("getTokenType(address)", token);
        (bool success, bytes memory returnData) = token.staticcall(payload);
        return (HederaResponseCodes.SUCCESS, success && returnData.length > 0);
    }

    function getTokenType(address token) htsCall external view returns (int64, int32) {
        require(token != address(0), "getTokenType: invalid address");
        return IHederaTokenService(token).getTokenType(token);
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

        // If a token is being created locally, then there is not remote data to fetch.
        // That is why `__setTokenInfo` must be called before `_initTokenData`.
        if (msg.sender == HTS_ADDRESS && selector == this.__setTokenInfo.selector) {
            (string memory tokenType_, IHederaTokenService.TokenInfo memory tokenInfo, int32 decimals_) = abi.decode(msg.data[28:], (string, IHederaTokenService.TokenInfo, int32));
            __setTokenInfo(tokenType_, tokenInfo, decimals_);
            return abi.encode(true);
        }

        _initTokenData();

        if (keccak256(bytes(tokenType)) == keccak256(bytes("NOT_FOUND"))) {
            revert("redirectForToken: token not found");
        }

        // Internal redirects for HTS methods.
        if (msg.sender == HTS_ADDRESS) {
            if (selector == this.getTokenInfo.selector) {
                require(msg.data.length >= 28, "getTokenInfo: Not enough calldata");
                return abi.encode(HederaResponseCodes.SUCCESS, _tokenInfo);
            }
            if (selector == this.associateToken.selector) {
                require(msg.data.length >= 48, "associateToken: Not enough calldata");
                address account = address(bytes20(msg.data[40:60]));
                bytes32 slot = _isAssociatedSlot(account);
                assembly { sstore(slot, true) }
                return abi.encode(HederaResponseCodes.SUCCESS);
            }
            if (selector == this.dissociateToken.selector) {
                require(msg.data.length >= 48, "dissociateToken: Not enough calldata");
                address account = address(bytes20(msg.data[40:60]));
                bytes32 slot = _isAssociatedSlot(account);
                assembly { sstore(slot, false) }
                return abi.encode(HederaResponseCodes.SUCCESS);
            }
            if (selector == this.getTokenType.selector) {
                require(msg.data.length >= 28, "getTokenType: Not enough calldata");
                if (keccak256(abi.encodePacked(tokenType)) == keccak256("FUNGIBLE_COMMON")) {
                    return abi.encode(HederaResponseCodes.SUCCESS, int32(0));
                }
                if (keccak256(abi.encodePacked(tokenType)) == keccak256("NON_FUNGIBLE_UNIQUE")) {
                    return abi.encode(HederaResponseCodes.SUCCESS, int32(1));
                }
                return abi.encode(HederaResponseCodes.SUCCESS, int32(-1));
            }
            if (selector == this.isFrozen.selector) {
                require(msg.data.length >= 92, "approve: Not enough calldata");
                address account = address(bytes20(msg.data[72:92]));
                return abi.encode(HederaResponseCodes.SUCCESS, __isFrozen(account));
            }
            if (selector == this.transferFrom.selector) {
                require(msg.data.length >= 156, "transferFrom: Not enough calldata");
                address sender = address(bytes20(msg.data[40:60]));
                address from = address(bytes20(msg.data[72:92]));
                address to = address(bytes20(msg.data[104:124]));
                uint256 amount = uint256(bytes32(msg.data[124:156]));
                if (from != sender) {
                    _spendAllowance(from, sender, amount);
                }
                _transfer(from, to, amount);
                return abi.encode(true);
            }
            if (selector == this.transferFromNFT.selector) {
                require(msg.data.length >= 156, "transferFromNFT: Not enough calldata");
                address sender = address(bytes20(msg.data[40:60]));
                address from = address(bytes20(msg.data[72:92]));
                address to = address(bytes20(msg.data[104:124]));
                uint256 serialId = uint256(bytes32(msg.data[124:156]));
                _transferNFT(sender, from, to, serialId);
                return abi.encode(true);
            }
            if (selector == this.approve.selector) {
                require(msg.data.length >= 124, "approve: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                uint256 amount = uint256(bytes32(msg.data[92:124]));
                _approve(from, to, amount);
                emit IERC20.Approval(from, to, amount);
                return abi.encode(true);
            }
            if (selector == this.approveNFT.selector) {
                require(msg.data.length >= 124, "approveNFT: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                uint256 serialId = uint256(bytes32(msg.data[92:124]));
                _approve(from, to, serialId, true);
                return abi.encode(true);
            }
            if (selector == this.isKyc.selector) {
                require(msg.data.length >= 48, "associateToken: Not enough calldata");
                address account = address(bytes20(msg.data[40:60]));
                return abi.encode(HederaResponseCodes.SUCCESS, __hasKycGranted(account));
            }
            if (selector == this.setApprovalForAll.selector) {
                require(msg.data.length >= 124, "setApprovalForAll: Not enough calldata");
                address from = address(bytes20(msg.data[40:60]));
                address to = address(bytes20(msg.data[72:92]));
                bool approved = uint256(bytes32(msg.data[92:124])) == 1;
                _setApprovalForAll(from, to, approved);
                return abi.encode(true);
            }
            if (selector == this.freezeToken.selector) {
                require(msg.data.length >= 92, "freezeToken: Not enough calldata");
                address account = address(bytes20(msg.data[72:92]));
                _updateFreeze(account, true);
                return abi.encode(HederaResponseCodes.SUCCESS);
            }
            if (selector == this.unfreezeToken.selector) {
                require(msg.data.length >= 92, "unfreezeToken: Not enough calldata");
                address account = address(bytes20(msg.data[72:92]));
                _updateFreeze(account, false);
                return abi.encode(HederaResponseCodes.SUCCESS);
            }
            if (selector == this.grantTokenKyc.selector) {
                require(msg.data.length >= 92, "grantTokenKyc: Not enough calldata");
                address account = address(bytes20(msg.data[72:92]));
                _updateKyc(account, true);
                return abi.encode(HederaResponseCodes.SUCCESS);
            }
            if (selector == this.revokeTokenKyc.selector) {
                require(msg.data.length >= 92, "revokeTokenKyc: Not enough calldata");
                address account = address(bytes20(msg.data[72:92]));
                _updateKyc(account, false);
                return abi.encode(HederaResponseCodes.SUCCESS);
            }
            if (selector == this.pauseToken.selector) {
                _tokenInfo.pauseStatus = true;
                return abi.encode(HederaResponseCodes.SUCCESS);
            }
            if (selector == this.unpauseToken.selector) {
                _tokenInfo.pauseStatus = false;
                return abi.encode(HederaResponseCodes.SUCCESS);
            }
            if (selector == this.getKeyOwner.selector) {
                require(msg.data.length >= 30, "getKeyOwner: Not enough calldata");
                uint8 keyType = uint8(bytes1(msg.data[91:92]));
                return abi.encode(__keyOwner(keyType));
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
        if (_isTokenInteraction(selector)) {
            require(!__isFrozen(msg.sender), "__redirectForToken: frozen");
            address allowed = __keyOwner(0x2);
            require(
                allowed == address(0) || allowed == msg.sender || __hasKycGranted(msg.sender),
                "__redirectForToken: no kyc granted"
            );
        }

        require(!_tokenInfo.pauseStatus, "__redirectForToken: paused");

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

    function _isTokenInteraction(bytes4 selector) private pure returns (bool)  {
        return selector == IERC20.transfer.selector ||
            selector == IERC20.transferFrom.selector ||
            selector == IERC20.approve.selector ||
            selector == IERC721.transferFrom.selector ||
            selector == IERC721.approve.selector ||
            selector == IERC721.setApprovalForAll.selector;
    }

    function _redirectForERC20(bytes4 selector) private returns (bytes memory) {
        if (selector == IERC20.name.selector) {
            return abi.encode(_tokenInfo.token.name);
        }
        if (selector == IERC20.decimals.selector) {
            return abi.encode(decimals);
        }
        if (selector == IERC20.totalSupply.selector) {
            return abi.encode(_tokenInfo.totalSupply);
        }
        if (selector == IERC20.symbol.selector) {
            return abi.encode(_tokenInfo.token.symbol);
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
            emit IERC20.Approval(owner, spender, amount);
            return abi.encode(true);
        }
        return _redirectForHRC719(selector);
    }

    function _redirectForERC721(bytes4 selector) private returns (bytes memory) {
        if (selector == IERC721.name.selector) {
            return abi.encode(_tokenInfo.token.name);
        }
        if (selector == IERC721.symbol.selector) {
            return abi.encode(_tokenInfo.token.symbol);
        }
        if (selector == IERC721.tokenURI.selector) {
            require(msg.data.length >= 60, "tokenURI: Not enough calldata");
            uint256 serialId = uint256(bytes32(msg.data[28:60]));
            return abi.encode(__tokenURI(serialId));
        }
        if (selector == IERC721.totalSupply.selector) {
            return abi.encode(_tokenInfo.totalSupply);
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
            _transferNFT(msg.sender, from, to, serialId);
            return abi.encode(true);
        }
        if (selector == IERC721.approve.selector) {
            require(msg.data.length >= 92, "approve: Not enough calldata");
            address spender = address(bytes20(msg.data[40:60]));
            uint256 serialId = uint256(bytes32(msg.data[60:92]));
            _approve(msg.sender, spender, serialId, true);
            return abi.encode(true);
        }
        if (selector == IERC721.setApprovalForAll.selector) {
            require(msg.data.length >= 92, "setApprovalForAll: Not enough calldata");
            address operator = address(bytes20(msg.data[40:60]));
            bool approved = uint256(bytes32(msg.data[60:92])) == 1;
            _setApprovalForAll(msg.sender, operator, approved);
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

    function __setTokenInfo(string memory tokenType_, IHederaTokenService.TokenInfo memory tokenInfo, int32 decimals_) public virtual {
        tokenType = tokenType_;
        decimals = uint8(uint32(decimals_));

        // The assignment
        //
        // _tokenInfo = tokenInfo;
        //
        // cannot be used directly because it triggers the following compilation error
        //
        // Error (1834): Copying of type struct IHederaTokenService.TokenKey memory[] memory to storage is not supported in legacy (only supported by the IR pipeline).
        // Hint: try compiling with `--via-ir` (CLI) or the equivalent `viaIR: true` (Standard JSON)
        //
        // More specifically, the assigment
        //
        // _tokenInfo.token.tokenKeys = tokenInfo.token.tokenKeys;
        //
        // triggers the above error as well.
        //
        // Array assignments from memory to storage are not supported in legacy codegen https://github.com/ethereum/solidity/issues/3446#issuecomment-1924761902.
        // And using the `--via-ir` flag as mentioned above increases compilation time substantially
        // That is why we are better off copying the struct to storage manually.

        _tokenInfo.token.name = tokenInfo.token.name;
        _tokenInfo.token.symbol = tokenInfo.token.symbol;
        _tokenInfo.token.treasury = tokenInfo.token.treasury;
        _tokenInfo.token.memo = tokenInfo.token.memo;
        _tokenInfo.token.tokenSupplyType = tokenInfo.token.tokenSupplyType;
        _tokenInfo.token.maxSupply = tokenInfo.token.maxSupply;
        _tokenInfo.token.freezeDefault = tokenInfo.token.freezeDefault;

        for (uint256 i = 0; i < tokenInfo.token.tokenKeys.length; i++) {
            _tokenInfo.token.tokenKeys.push(tokenInfo.token.tokenKeys[i]);
        }

        _tokenInfo.token.expiry = tokenInfo.token.expiry;

        _tokenInfo.totalSupply = tokenInfo.totalSupply;
        _tokenInfo.deleted = tokenInfo.deleted;
        _tokenInfo.defaultKycStatus = tokenInfo.defaultKycStatus;
        _tokenInfo.pauseStatus = tokenInfo.pauseStatus;

        // The same copying issue as mentioned above for fee arrays.
        // _tokenInfo.fixedFees = tokenInfo.fixedFees;
        for (uint256 i = 0; i < tokenInfo.fixedFees.length; i++) {
            _tokenInfo.fixedFees.push(tokenInfo.fixedFees[i]);
        }
        // _tokenInfo.fractionalFees = tokenInfo.fractionalFees;
        for (uint256 i = 0; i < tokenInfo.fractionalFees.length; i++) {
            _tokenInfo.fractionalFees.push(tokenInfo.fractionalFees[i]);
        }
        // _tokenInfo.royaltyFees = tokenInfo.royaltyFees;
        for (uint256 i = 0; i < tokenInfo.royaltyFees.length; i++) {
            _tokenInfo.royaltyFees.push(tokenInfo.royaltyFees[i]);
        }

        _tokenInfo.ledgerId = tokenInfo.ledgerId;
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

    function _isFrozenSlot(address account) internal virtual returns (bytes32) {
        bytes4 selector = IHederaTokenService.isFrozen.selector;
        uint192 pad = 0x0;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(account);
        return bytes32(abi.encodePacked(selector, pad, accountId));
    }

    function _hasKycGrantedSlot(address account) internal virtual returns (bytes32) {
        bytes4 selector = IHederaTokenService.isKyc.selector;
        uint192 pad = 0x0;
        uint32 accountId = HtsSystemContract(HTS_ADDRESS).getAccountId(account);
        return bytes32(abi.encodePacked(selector, pad, accountId));
    }

    function _keyOwnerSlot(uint8 keyType) internal virtual returns (bytes32) {
        bytes4 selector = IHederaTokenService.getTokenKey.selector;
        uint192 pad = 0x0;
        return bytes32(abi.encodePacked(selector, pad, keyType));
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

    function __isFrozen(address account) private returns (bool frozenStatus) {
        bytes32 slot = _isFrozenSlot(account);
        assembly { frozenStatus := sload(slot) }
    }

    function __hasKycGranted(address account) private returns (bool hasKycGranted) {
        bytes32 slot = _hasKycGrantedSlot(account);
        assembly { hasKycGranted := sload(slot) }
    }

    function __keyOwner(uint8 keyType) private returns (address keyOwner) {
        bytes32 slot = _keyOwnerSlot(keyType);
        assembly { keyOwner := sload(slot) }
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "hts: invalid sender");
        require(to != address(0), "hts: invalid receiver");
        _update(from, to, amount);
        emit IERC20.Transfer(from, to, amount);
    }

    function _transferNFT(address sender, address from, address to, uint256 serialId) private {
        require(from != address(0), "hts: invalid sender");
        require(to != address(0), "hts: invalid receiver");

        // Check if the sender is the owner of the token
        bytes32 slot = _ownerOfSlot(uint32(serialId));
        address owner;
        assembly { owner := sload(slot) }
        require(owner == from, "hts: sender is not owner");
        if (sender != owner) {
            require(sender == __getApproved(serialId) || __isApprovedForAll(owner, sender), "hts: unauthorized");
        }

        // Clear approval
        bytes32 approvalSlot = _getApprovedSlot(uint32(serialId));
        assembly { sstore(approvalSlot, 0) }

        // Clear approval for all
        if (owner != sender) {
            bytes32 isApprovedForAllSlot = _isApprovedForAllSlot(owner, sender);
            assembly { sstore(isApprovedForAllSlot, false) }
        }

        // Set the new owner
        assembly { sstore(slot, to) }
        emit IERC721.Transfer(from, to, serialId);
    }

    function _updateKyc(address account, bool hasKycGranted) public {
        bytes32 kycSlot = _hasKycGrantedSlot(account);
        assembly { sstore(kycSlot, hasKycGranted) }
    }

    function _updateFreeze(address account, bool frozenStatus) public {
        bytes32 isFrozenSlot = _isFrozenSlot(account);
        assembly { sstore(isFrozenSlot, frozenStatus) }
    }

    function _update(address from, address to, uint256 amount) public {
        if (from == address(0)) {
            _tokenInfo.totalSupply += int64(int256(amount));
        } else {
            bytes32 fromSlot = _balanceOfSlot(from);
            uint256 fromBalance;
            assembly { fromBalance := sload(fromSlot) }
            require(fromBalance >= amount, "_transfer: insufficient balance");
            assembly { sstore(fromSlot, sub(fromBalance, amount)) }
        }

        if (to == address(0)) {
            _tokenInfo.totalSupply -= int64(int256(amount));
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

    function _approve(address sender, address spender, uint256 serialId, bool isApproved) private {
        // The caller must own the token or be an approved operator.
        address owner = __ownerOf(serialId);
        require(
            sender == owner || __getApproved(serialId) == sender || __isApprovedForAll(owner, sender),
            "_approve: unauthorized"
        );

        bytes32 slot = _getApprovedSlot(uint32(serialId));
        address newApproved = isApproved ? spender : address(0);
        assembly { sstore(slot, newApproved) }
        emit IERC721.Approval(owner, spender, serialId);
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

    function _setApprovalForAll(address sender, address operator, bool approved) private {
        require(operator != address(0) && operator != sender, "setApprovalForAll: invalid operator");
        bytes32 slot = _isApprovedForAllSlot(sender, operator);
        assembly { sstore(slot, approved) }
        emit IERC721.ApprovalForAll(sender, operator, approved);
    }

    function _checkCryptoFungibleTransfers(address token, AccountAmount[] memory transfers) internal returns (int64) {
        int64 total = 0;
        AccountAmount[] memory spends = new AccountAmount[](transfers.length);
        uint256 spendsCount = 0;

        // This loop checks whether allowances and balances are sufficient to execute all requested transactions.
        // Additionally, it collects data on the amount in each transfer to ensure that the total sum balances out.
        for (uint256 i = 0; i < transfers.length; i++) {
            total += transfers[i].amount;

            // What matters most is the spender's ability to send the amount to the recipient,
            // not the other way around, so we can ignore the recipients for now.
            if (transfers[i].amount > 0) {
                continue;
            }

            // We calculate the total expenditures for each account up to this point to ensure that all account
            // balances are sufficient to proceed with the transaction.
            // Allowances are also checked.
            uint256 accountSpendIndex;
            for (accountSpendIndex = 0; accountSpendIndex <= spendsCount; accountSpendIndex++) {
                if (accountSpendIndex == spendsCount) {
                    spends[spendsCount] = AccountAmount(transfers[i].accountID, -transfers[i].amount, false);
                    spendsCount++;
                    break;
                }
                if (spends[accountSpendIndex].accountID == transfers[i].accountID) {
                    spends[accountSpendIndex].amount -= transfers[i].amount;
                    break;
                }
            }
            bool isApproval = transfers[i].accountID != msg.sender;
            if (transfers[i].isApproval != isApproval) return HederaResponseCodes.SPENDER_DOES_NOT_HAVE_ALLOWANCE;
            uint256 totalAccountSpend = uint256(uint64(spends[accountSpendIndex].amount));
            if (isApproval) {
                uint256 allowanceLimit = token == address(0) ?
                    __allowance(transfers[i].accountID, msg.sender) :
                    IERC20(token).allowance(transfers[i].accountID, msg.sender);
                if (allowanceLimit < totalAccountSpend) return HederaResponseCodes.MAX_ALLOWANCES_EXCEEDED;
            }
            if (token == address(0) && transfers[i].accountID.balance < totalAccountSpend) {
                return HederaResponseCodes.INSUFFICIENT_ACCOUNT_BALANCE;
            }
            if (token != address(0) && IERC20(token).balanceOf(transfers[i].accountID) < totalAccountSpend) {
                return HederaResponseCodes.INSUFFICIENT_TOKEN_BALANCE;
            }
        }

        // The same account cannot be used twice in the same context.
        // For example, you cannot create two transactions from the same account with different amounts
        // for a single token within one transaction.
        for (uint256 first = 0; first < transfers.length; first++) {
            for (uint256 second = 0; second < transfers.length; second++) {
                if (first == second) continue;
                bool bothToOrFrom = (transfers[first].amount > 0) == (transfers[second].amount > 0);
                if (transfers[first].accountID == transfers[second].accountID && bothToOrFrom) {
                    return HederaResponseCodes.ACCOUNT_REPEATED_IN_ACCOUNT_AMOUNTS;
                }
            }
        }

        // All transfer amounts must sum to zero. Crypto transfer cannot be used to mint or burn tokens.
        return total == 0 ? HederaResponseCodes.SUCCESS : HederaResponseCodes.INVALID_ACCOUNT_AMOUNTS;
    }

    function _updateHbarBalanceOnAccount(address account, uint256 newBalance) internal virtual returns (int64) {
        if (newBalance == account.balance) return HederaResponseCodes.SUCCESS; // No change required anyway.

        return HederaResponseCodes.NOT_SUPPORTED;
    }

    function getKeyOwner(address token, uint8 keyType) public view htsCall returns (address) {
        return HtsSystemContract(token).getKeyOwner(token, keyType);
    }
}
