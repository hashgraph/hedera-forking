// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * This interface is used to get the selectors and for testing.
 */
interface ITokenKey {
    /**
     * @dev Returns the account associated with the key type assigned tot the token.
     */
    function getKeyAddress(uint keyType) external view returns (address accountAddress);
}
