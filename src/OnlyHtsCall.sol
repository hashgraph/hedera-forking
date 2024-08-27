// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @title Prevents delegatecall to a contract
/// @notice Base contract that provides a modifier for preventing delegatecall to methods in a child contract
abstract contract OnlyHtsCall {
    
    address internal constant HTS_PRECOMPILE = address(0x167);

    /// @notice Prevents delegatecall into the modified method
    modifier onlyHtsCall() {
        require(address(this) == HTS_PRECOMPILE, "NO_DELEGATECALL");
        _;
    }
}
