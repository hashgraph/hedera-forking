// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.9.0;
// pragma experimental ABIEncoderV2;

// import "../../HederaTokenService.sol";
// import "../../ExpiryHelper.sol";
// import "../../KeyHelper.sol";

interface IHTS {

    /// Transfers cryptocurrency among two or more accounts by making the desired adjustments to their
    /// balances. Each transfer list can specify up to 10 adjustments. Each negative amount is withdrawn
    /// from the corresponding account (a sender), and each positive one is added to the corresponding
    /// account (a receiver). The amounts list must sum to zero. Each amount is a number of tinybars
    /// (there are 100,000,000 tinybars in one hbar).  If any sender account fails to have sufficient
    /// hbars, then the entire transaction fails, and none of those transfers occur, though the
    /// transaction fee is still charged. This transaction must be signed by the keys for all the sending
    /// accounts, and for any receiving accounts that have receiverSigRequired == true. The signatures
    /// are in the same order as the accounts, skipping those accounts that don't need a signature.
    /// @custom:version 0.3.0 previous version did not include isApproval
    struct AccountAmount {
        // The Account ID, as a solidity address, that sends/receives cryptocurrency or tokens
        address accountID;

        // The amount of  the lowest denomination of the given token that
        // the account sends(negative) or receives(positive)
        int64 amount;

        // If true then the transfer is expected to be an approved allowance and the
        // accountID is expected to be the owner. The default is false (omitted).
        bool isApproval;
    }

    /// A sender account, a receiver account, and the serial number of an NFT of a Token with
    /// NON_FUNGIBLE_UNIQUE type. When minting NFTs the sender will be the default AccountID instance
    /// (0.0.0 aka 0x0) and when burning NFTs, the receiver will be the default AccountID instance.
    /// @custom:version 0.3.0 previous version did not include isApproval
    struct NftTransfer {
        // The solidity address of the sender
        address senderAccountID;

        // The solidity address of the receiver
        address receiverAccountID;

        // The serial number of the NFT
        int64 serialNumber;

        // If true then the transfer is expected to be an approved allowance and the
        // accountID is expected to be the owner. The default is false (omitted).
        bool isApproval;
    }

    struct TokenTransferList {
        // The ID of the token as a solidity address
        address token;

        // Applicable to tokens of type FUNGIBLE_COMMON. Multiple list of AccountAmounts, each of which
        // has an account and amount.
        AccountAmount[] transfers;

        // Applicable to tokens of type NON_FUNGIBLE_UNIQUE. Multiple list of NftTransfers, each of
        // which has a sender and receiver account, including the serial number of the NFT
        NftTransfer[] nftTransfers;
    }

    struct TransferList {
        // Multiple list of AccountAmounts, each of which has an account and amount.
        // Used to transfer hbars between the accounts in the list.
        AccountAmount[] transfers;
    }

    /// Expiry properties of a Hedera token - second, autoRenewAccount, autoRenewPeriod
    struct Expiry {
        // The epoch second at which the token should expire; if an auto-renew account and period are
        // specified, this is coerced to the current epoch second plus the autoRenewPeriod
        int64 second;

        // ID of an account which will be automatically charged to renew the token's expiration, at
        // autoRenewPeriod interval, expressed as a solidity address
        address autoRenewAccount;

        // The interval at which the auto-renew account will be charged to extend the token's expiry
        int64 autoRenewPeriod;
    }

    /// A Key can be a public key from either the Ed25519 or ECDSA(secp256k1) signature schemes, where
    /// in the ECDSA(secp256k1) case we require the 33-byte compressed form of the public key. We call
    /// these public keys <b>primitive keys</b>.
    /// A Key can also be the ID of a smart contract instance, which is then authorized to perform any
    /// precompiled contract action that requires this key to sign.
    /// Note that when a Key is a smart contract ID, it <i>doesn't</i> mean the contract with that ID
    /// will actually create a cryptographic signature. It only means that when the contract calls a
    /// precompiled contract, the resulting "child transaction" will be authorized to perform any action
    /// controlled by the Key.
    /// Exactly one of the possible values should be populated in order for the Key to be valid.
    struct KeyValue {

        // if set to true, the key of the calling Hedera account will be inherited as the token key
        bool inheritAccountKey;

        // smart contract instance that is authorized as if it had signed with a key
        address contractId;

        // Ed25519 public key bytes
        bytes ed25519;

        // Compressed ECDSA(secp256k1) public key bytes
        bytes ECDSA_secp256k1;

        // A smart contract that, if the recipient of the active message frame, should be treated
        // as having signed. (Note this does not mean the <i>code being executed in the frame</i>
        // will belong to the given contract, since it could be running another contract's code via
        // <tt>delegatecall</tt>. So setting this key is a more permissive version of setting the
        // contractID key, which also requires the code in the active message frame belong to the
        // the contract with the given id.)
        address delegatableContractId;
    }

    /// A list of token key types the key should be applied to and the value of the key
    struct TokenKey {

        // bit field representing the key type. Keys of all types that have corresponding bits set to 1
        // will be created for the token.
        // 0th bit: adminKey
        // 1st bit: kycKey
        // 2nd bit: freezeKey
        // 3rd bit: wipeKey
        // 4th bit: supplyKey
        // 5th bit: feeScheduleKey
        // 6th bit: pauseKey
        // 7th bit: ignored
        uint keyType;

        // the value that will be set to the key type
        KeyValue key;
    }

    /// Basic properties of a Hedera Token - name, symbol, memo, tokenSupplyType, maxSupply,
    /// treasury, freezeDefault. These properties are related both to Fungible and NFT token types.
    struct HederaToken {
        // The publicly visible name of the token. The token name is specified as a Unicode string.
        // Its UTF-8 encoding cannot exceed 100 bytes, and cannot contain the 0 byte (NUL).
        string name;

        // The publicly visible token symbol. The token symbol is specified as a Unicode string.
        // Its UTF-8 encoding cannot exceed 100 bytes, and cannot contain the 0 byte (NUL).
        string symbol;

        // The ID of the account which will act as a treasury for the token as a solidity address.
        // This account will receive the specified initial supply or the newly minted NFTs in
        // the case for NON_FUNGIBLE_UNIQUE Type
        address treasury;

        // The memo associated with the token (UTF-8 encoding max 100 bytes)
        string memo;

        // IWA compatibility. Specified the token supply type. Defaults to INFINITE
        bool tokenSupplyType;

        // IWA Compatibility. Depends on TokenSupplyType. For tokens of type FUNGIBLE_COMMON - the
        // maximum number of tokens that can be in circulation. For tokens of type NON_FUNGIBLE_UNIQUE -
        // the maximum number of NFTs (serial numbers) that can be minted. This field can never be changed!
        int64 maxSupply;

        // The default Freeze status (frozen or unfrozen) of Hedera accounts relative to this token. If
        // true, an account must be unfrozen before it can receive the token
        bool freezeDefault;

        // list of keys to set to the token
        TokenKey[] tokenKeys;

        // expiry properties of a Hedera token - second, autoRenewAccount, autoRenewPeriod
        Expiry expiry;
    }

    /// Additional post creation fungible and non fungible properties of a Hedera Token.
    struct TokenInfo {
        /// Basic properties of a Hedera Token
        HederaToken token;

        /// The number of tokens (fungible) or serials (non-fungible) of the token
        int64 totalSupply;

        /// Specifies whether the token is deleted or not
        bool deleted;

        /// Specifies whether the token kyc was defaulted with KycNotApplicable (true) or Revoked (false)
        bool defaultKycStatus;

        /// Specifies whether the token is currently paused or not
        bool pauseStatus;

        /// The fixed fees collected when transferring the token
        FixedFee[] fixedFees;

        /// The fractional fees collected when transferring the token
        FractionalFee[] fractionalFees;

        /// The royalty fees collected when transferring the token
        RoyaltyFee[] royaltyFees;

        /// The ID of the network ledger
        string ledgerId;
    }

    /// Additional fungible properties of a Hedera Token.
    struct FungibleTokenInfo {
        /// The shared hedera token info
        TokenInfo tokenInfo;

        /// The number of decimal places a token is divisible by
        int32 decimals;
    }

    /// Additional non fungible properties of a Hedera Token.
    struct NonFungibleTokenInfo {
        /// The shared hedera token info
        TokenInfo tokenInfo;

        /// The serial number of the nft
        int64 serialNumber;

        /// The account id specifying the owner of the non fungible token
        address ownerId;

        /// The epoch second at which the token was created.
        int64 creationTime;

        /// The unique metadata of the NFT
        bytes metadata;

        /// The account id specifying an account that has been granted spending permissions on this nft
        address spenderId;
    }

    /// A fixed number of units (hbar or token) to assess as a fee during a transfer of
    /// units of the token to which this fixed fee is attached. The denomination of
    /// the fee depends on the values of tokenId, useHbarsForPayment and
    /// useCurrentTokenForPayment. Exactly one of the values should be set.
    struct FixedFee {

        int64 amount;

        // Specifies ID of token that should be used for fixed fee denomination
        address tokenId;

        // Specifies this fixed fee should be denominated in Hbar
        bool useHbarsForPayment;

        // Specifies this fixed fee should be denominated in the Token currently being created
        bool useCurrentTokenForPayment;

        // The ID of the account to receive the custom fee, expressed as a solidity address
        address feeCollector;
    }

    /// A fraction of the transferred units of a token to assess as a fee. The amount assessed will never
    /// be less than the given minimumAmount, and never greater than the given maximumAmount.  The
    /// denomination is always units of the token to which this fractional fee is attached.
    struct FractionalFee {
        // A rational number's numerator, used to set the amount of a value transfer to collect as a custom fee
        int64 numerator;

        // A rational number's denominator, used to set the amount of a value transfer to collect as a custom fee
        int64 denominator;

        // The minimum amount to assess
        int64 minimumAmount;

        // The maximum amount to assess (zero implies no maximum)
        int64 maximumAmount;
        bool netOfTransfers;

        // The ID of the account to receive the custom fee, expressed as a solidity address
        address feeCollector;
    }

    /// A fee to assess during a transfer that changes ownership of an NFT. Defines the fraction of
    /// the fungible value exchanged for an NFT that the ledger should collect as a royalty. ("Fungible
    /// value" includes both ℏ and units of fungible HTS tokens.) When the NFT sender does not receive
    /// any fungible value, the ledger will assess the fallback fee, if present, to the new NFT owner.
    /// Royalty fees can only be added to tokens of type type NON_FUNGIBLE_UNIQUE.
    struct RoyaltyFee {
        // A fraction's numerator of fungible value exchanged for an NFT to collect as royalty
        int64 numerator;

        // A fraction's denominator of fungible value exchanged for an NFT to collect as royalty
        int64 denominator;

        // If present, the fee to assess to the NFT receiver when no fungible value
        // is exchanged with the sender. Consists of:
        // amount: the amount to charge for the fee
        // tokenId: Specifies ID of token that should be used for fixed fee denomination
        // useHbarsForPayment: Specifies this fee should be denominated in Hbar
        int64 amount;
        address tokenId;
        bool useHbarsForPayment;

        // The ID of the account to receive the custom fee, expressed as a solidity address
        address feeCollector;
    }

    function createFungibleToken(
        HederaToken memory token,
        int64 initialTotalSupply,
        int32 decimals
    ) external payable returns (int64 responseCode, address tokenAddress);
}

abstract contract KeyHelper {
    using Bits for uint256;
    address supplyContract;

    mapping(KeyType => uint256) keyTypes;

    enum KeyType {
        ADMIN,
        KYC,
        FREEZE,
        WIPE,
        SUPPLY,
        FEE,
        PAUSE
    }
    enum KeyValueType {
        INHERIT_ACCOUNT_KEY,
        CONTRACT_ID,
        ED25519,
        SECP256K1,
        DELEGETABLE_CONTRACT_ID
    }

    constructor() {
        keyTypes[KeyType.ADMIN] = 1;
        keyTypes[KeyType.KYC] = 2;
        keyTypes[KeyType.FREEZE] = 4;
        keyTypes[KeyType.WIPE] = 8;
        keyTypes[KeyType.SUPPLY] = 16;
        keyTypes[KeyType.FEE] = 32;
        keyTypes[KeyType.PAUSE] = 64;
    }

    function getDefaultKeys() internal view returns (IHTS.TokenKey[] memory keys) {
        keys = new IHTS.TokenKey[](2);
        keys[0] = getSingleKey(KeyType.KYC, KeyValueType.CONTRACT_ID, '');
        keys[1] = IHTS.TokenKey(
            getDuplexKeyType(KeyType.SUPPLY, KeyType.PAUSE),
            getKeyValueType(KeyValueType.CONTRACT_ID, '')
        );
    }

    function getAllTypeKeys(KeyValueType keyValueType, bytes memory key)
        internal
        view
        returns (IHTS.TokenKey[] memory keys)
    {
        keys = new IHTS.TokenKey[](1);
        keys[0] = IHTS.TokenKey(getAllKeyTypes(), getKeyValueType(keyValueType, key));
    }

    function getCustomSingleTypeKeys(
        KeyType keyType,
        KeyValueType keyValueType,
        bytes memory key
    ) internal view returns (IHTS.TokenKey[] memory keys) {
        keys = new IHTS.TokenKey[](1);
        keys[0] = IHTS.TokenKey(getKeyType(keyType), getKeyValueType(keyValueType, key));
    }

    function getCustomDuplexTypeKeys(
        KeyType firstType,
        KeyType secondType,
        KeyValueType keyValueType,
        bytes memory key
    ) internal view returns (IHTS.TokenKey[] memory keys) {
        keys = new IHTS.TokenKey[](1);
        keys[0] = IHTS.TokenKey(
            getDuplexKeyType(firstType, secondType),
            getKeyValueType(keyValueType, key)
        );
    }

    function getSingleKey(
        KeyType keyType,
        KeyValueType keyValueType,
        bytes memory key
    ) internal view returns (IHTS.TokenKey memory tokenKey) {
        tokenKey = IHTS.TokenKey(getKeyType(keyType), getKeyValueType(keyValueType, key));
    }

    function getSingleKey(
        KeyType keyType,
        KeyValueType keyValueType,
        address key
    ) internal view returns (IHTS.TokenKey memory tokenKey) {
        tokenKey = IHTS.TokenKey(getKeyType(keyType), getKeyValueType(keyValueType, key));
    }

    function getSingleKey(
        KeyType firstType,
        KeyType secondType,
        KeyValueType keyValueType,
        bytes memory key
    ) internal view returns (IHTS.TokenKey memory tokenKey) {
        tokenKey = IHTS.TokenKey(
            getDuplexKeyType(firstType, secondType),
            getKeyValueType(keyValueType, key)
        );
    }

    function getDuplexKeyType(KeyType firstType, KeyType secondType) internal pure returns (uint256 keyType) {
        keyType = keyType.setBit(uint8(firstType));
        keyType = keyType.setBit(uint8(secondType));
    }

    function getAllKeyTypes() internal pure returns (uint256 keyType) {
        keyType = keyType.setBit(uint8(KeyType.ADMIN));
        keyType = keyType.setBit(uint8(KeyType.KYC));
        keyType = keyType.setBit(uint8(KeyType.FREEZE));
        keyType = keyType.setBit(uint8(KeyType.WIPE));
        keyType = keyType.setBit(uint8(KeyType.SUPPLY));
        keyType = keyType.setBit(uint8(KeyType.FEE));
        keyType = keyType.setBit(uint8(KeyType.PAUSE));
    }

    function getKeyType(KeyType keyType) internal view returns (uint256) {
        return keyTypes[keyType];
    }

    function getKeyValueType(KeyValueType keyValueType, bytes memory key)
        internal
        view
        returns (IHTS.KeyValue memory keyValue)
    {
        if (keyValueType == KeyValueType.INHERIT_ACCOUNT_KEY) {
            keyValue.inheritAccountKey = true;
        } else if (keyValueType == KeyValueType.CONTRACT_ID) {
            keyValue.contractId = supplyContract;
        } else if (keyValueType == KeyValueType.ED25519) {
            keyValue.ed25519 = key;
        } else if (keyValueType == KeyValueType.SECP256K1) {
            keyValue.ECDSA_secp256k1 = key;
        } else if (keyValueType == KeyValueType.DELEGETABLE_CONTRACT_ID) {
            keyValue.delegatableContractId = supplyContract;
        }
    }

    function getKeyValueType(KeyValueType keyValueType, address keyAddress)
        internal
        pure
        returns (IHTS.KeyValue memory keyValue)
    {
        if (keyValueType == KeyValueType.CONTRACT_ID) {
            keyValue.contractId = keyAddress;
        } else if (keyValueType == KeyValueType.DELEGETABLE_CONTRACT_ID) {
            keyValue.delegatableContractId = keyAddress;
        }
    }
}

library Bits {
    uint256 internal constant ONE = uint256(1);

    // Sets the bit at the given 'index' in 'self' to '1'.
    // Returns the modified value.
    function setBit(uint256 self, uint8 index) internal pure returns (uint256) {
        return self | (ONE << index);
    }
}

contract TokenCreator is KeyHelper {
    string name = "tokenName";
    string symbol = "tokenSymbol";
    string memo = "memo";
    int64 initialTotalSupply = 10000000000;
    int64 maxSupply = 20000000000;
    int32 decimals = 0;
    bool freezeDefaultStatus = false;

    int32 internal constant UNKNOWN = 21; // The responding node has submitted the transaction to the network. Its final status is still unknown.
    int32 internal constant SUCCESS = 22; // The transaction succeeded

    event TokenCreated(address tokenA);

    function createFungibleToken(address treasury, bytes memory adminKey) public payable {
        // IHTS.TokenKey[] memory keys = new IHTS.TokenKey[](1);
        // keys[0] = getSingleKey(KeyType.ADMIN, KeyType.ADMIN, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));

        // IHTS.TokenKey[] memory keys = new IHTS.TokenKey[](6);
        // keys[0] = getSingleKey(KeyType.ADMIN, KeyType.PAUSE, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        // keys[1] = getSingleKey(KeyType.KYC, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        // keys[2] = getSingleKey(KeyType.FREEZE, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        // keys[3] = getSingleKey(KeyType.WIPE, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        // keys[4] = getSingleKey(KeyType.SUPPLY, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        // keys[5] = getSingleKey(KeyType.FEE, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));

        IHTS.TokenKey[] memory keys = new IHTS.TokenKey[](6);
        keys[0] = getSingleKey(KeyType.ADMIN, KeyType.PAUSE, KeyValueType.SECP256K1, adminKey);
        keys[1] = getSingleKey(KeyType.KYC, KeyValueType.SECP256K1, adminKey);
        keys[2] = getSingleKey(KeyType.FREEZE, KeyValueType.SECP256K1, adminKey);
        keys[3] = getSingleKey(KeyType.SUPPLY, KeyValueType.SECP256K1, adminKey);
        keys[4] = getSingleKey(KeyType.WIPE, KeyValueType.SECP256K1, adminKey);
        keys[5] = getSingleKey(KeyType.FEE, KeyValueType.SECP256K1, adminKey);

        IHTS.Expiry memory expiry = IHTS.Expiry(
            0, treasury, 8000000
        );

        IHTS.HederaToken memory token = IHTS.HederaToken(
            name, symbol, treasury, memo, true, maxSupply, freezeDefaultStatus, keys, expiry
        );

        (int responseCode, address tokenAddress) = _createFungibleToken(token, initialTotalSupply, decimals);

        if (responseCode != SUCCESS) {
            revert ("error");
        }

        emit TokenCreated(tokenAddress);
    }

    function _createFungibleToken(
        IHTS.HederaToken memory token,
        int64 initialTotalSupply_,
        int32 decimals_) nonEmptyExpiry(token)
    internal returns (int responseCode, address tokenAddress) {
        (bool success, bytes memory result) = address(0x167).call{value : msg.value}(
            abi.encodeWithSelector(IHTS.createFungibleToken.selector,
            token, initialTotalSupply_, decimals_));

        (responseCode, tokenAddress) = success ? abi.decode(result, (int32, address)) : (UNKNOWN, address(0));
    }

    int32 constant defaultAutoRenewPeriod = 7776000;

    modifier nonEmptyExpiry(IHTS.HederaToken memory token)
    {
        if (token.expiry.second == 0 && token.expiry.autoRenewPeriod == 0) {
            token.expiry.autoRenewPeriod = defaultAutoRenewPeriod;
        }
        _;
    }
}
