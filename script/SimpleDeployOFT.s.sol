// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MyOFT } from "../src/MyOFT.sol";

/// @title Simple Deploy MyOFT Script
/// @notice Simplified deployment script for MyOFT contracts
contract SimpleDeployOFT is Script {
    /// @notice Main deployment function
    function run() external {
        // Hardcoded LayerZero V2 endpoint (same on all major chains)
        address lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
        
        // Token details
        string memory tokenName = "My Omnichain Token";
        string memory tokenSymbol = "MYOFT";
        
        // Get deployer from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Base deployment
        console.log("\n=== Deploying to Base ===");
        vm.createSelectFork("https://base-mainnet.g.alchemy.com/v2/demo");
        
        vm.startBroadcast(deployerPrivateKey);
        MyOFT baseOFT = new MyOFT(
            tokenName,
            tokenSymbol,
            lzEndpoint,
            deployer
        );
        vm.stopBroadcast();
        
        console.log("Base OFT deployed at:", address(baseOFT));
        
        // Arbitrum deployment
        console.log("\n=== Deploying to Arbitrum ===");
        vm.createSelectFork("https://arb-mainnet.g.alchemy.com/v2/demo");
        
        vm.startBroadcast(deployerPrivateKey);
        MyOFT arbOFT = new MyOFT(
            tokenName,
            tokenSymbol,
            lzEndpoint,
            deployer
        );
        vm.stopBroadcast();
        
        console.log("Arbitrum OFT deployed at:", address(arbOFT));
        
        // Summary
        console.log("\n=== Deployment Summary ===");
        console.log("Base OFT:", address(baseOFT));
        console.log("Arbitrum OFT:", address(arbOFT));
        console.log("\nNext steps:");
        console.log("1. Update wire-config-base-arbitrum.json with these addresses");
        console.log("2. Run the WireOApp script to connect the OApps");
    }
} 