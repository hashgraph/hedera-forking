// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.9 <0.9.0;

interface IHederaAccounts {
    /// @dev Returns the account ID and a flag indicating whether the account exists on the network we are forking from.
    /// - `accountId`: A `uint32` representing the account ID (excluding both shard and realm numbers)
    ///   for the given `address`. The storage adapter, _i.e._, `getHtsStorageAt`, assumes that both shard and realm
    ///   numbers are zero, allowing them to be omitted from the account ID.
    /// - `exists`: A boolean flag indicating whether the account exists on the forked network.
    ///
    /// See https://docs.hedera.com/hedera/core-concepts/accounts/account-properties
    /// for more info on account properties.
    function getAccountId(address account) external view returns (uint32 accountId, bool exists);
}
