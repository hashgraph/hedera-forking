// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.9 <0.9.0;

interface IHederaAccounts {
    /// @notice Checks if the account is created on the hedera network
    /// @dev This function returns the existence status of the queried account
    /// @return exists True if the account exists, false otherwise
    function accountExists(address account) external view returns (bool exists);
}
