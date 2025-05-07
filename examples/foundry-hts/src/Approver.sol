// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "hedera-forking/IERC20.sol";
import {IHRC719} from "hedera-forking/IHRC719.sol";

contract Approver {
    function associate(address tokenAddress) external {
        IHRC719(tokenAddress).associate();
    }

    function approve(address tokenAddress, address account, uint256 amount) external {
        IERC20(tokenAddress).approve(account, amount);
    }
}
