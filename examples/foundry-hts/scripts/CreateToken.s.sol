// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {HTS_ADDRESS} from "hedera-forking/HtsSystemContract.sol";
import {IHederaTokenService} from "hedera-forking/IHederaTokenService.sol";
import {HederaResponseCodes} from "hedera-forking/HederaResponseCodes.sol";
import {htsSetup} from "hedera-forking/htsSetup.sol";

contract CreateTokenScript is Script {
    uint256 PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

    function run() public {
        htsSetup();

        address signer = vm.addr(PRIVATE_KEY);
        console.log("Signer address %s", signer);

        vm.startBroadcast(PRIVATE_KEY);

        IHederaTokenService.KeyValue memory keyValue;
        keyValue.inheritAccountKey = true;

        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](1);
        keys[0] = IHederaTokenService.TokenKey(1, keyValue);

        IHederaTokenService.Expiry memory expiry;
        expiry.second = 0;
        expiry.autoRenewAccount = signer;
        expiry.autoRenewPeriod = 8000000;

        IHederaTokenService.HederaToken memory token;
        token.name = "HTS Token Example Created with Foundry";
        token.symbol = "FDRY";
        token.treasury = signer;
        token.memo = "This HTS Token was created using `forge script` together with HTS emulation";
        token.tokenKeys = keys;
        token.expiry = expiry;

        (int64 responseCode, address tokenAddress) = IHederaTokenService(HTS_ADDRESS).createFungibleToken{value: 10 ether}(token, 10000, 4);
        console.log("Response code %d", int(responseCode));
        console.log("Token address %s", tokenAddress);

        vm.stopBroadcast();
    }
}
