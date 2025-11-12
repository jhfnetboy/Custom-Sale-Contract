// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {SaleContract} from "../src/SaleContract.sol";

contract DeploySaleContract is Script {
    function run() external returns (SaleContract) {
        // TODO: Replace with your actual GToken address and Treasury address for deployment
        address gTokenAddress = address(0); // IMPORTANT: REPLACE THIS
        address treasuryAddress = address(0); // IMPORTANT: REPLACE THIS
        address ownerAddress = msg.sender; // Or a multisig address

        vm.startBroadcast();

        SaleContract saleContract = new SaleContract(gTokenAddress, treasuryAddress, ownerAddress);

        console.log("SaleContract deployed at:", address(saleContract));

        vm.stopBroadcast();
        return saleContract;
    }
}
