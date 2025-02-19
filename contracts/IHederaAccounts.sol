// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.9 <0.9.0;

interface IHederaAccounts {
     /// @dev Returns the account id (omitting both shard and realm numbers) of the given `address`.
     /// The storage adapter, _i.e._, `getHtsStorageAt`, assumes that both shard and realm numbers are zero.
     /// Thus, they can be omitted from the account id.
     ///
     /// See https://docs.hedera.com/hedera/core-concepts/accounts/account-properties
     /// for more info on account properties.
    function getAccountId(address account) external view returns (uint32 accountId);

    /// @notice Checks if the account is created on the hedera network
    /// @dev This function returns the existence status of the queried account
    /// @return exists True if the account exists, false otherwise
    function accountExists(address account) external view returns (bool exists);
}
