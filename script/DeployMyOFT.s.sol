// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MyOFT } from "../src/MyOFT.sol";

/// @title Deploy MyOFT Script
/// @notice Deploys MyOFT contracts to multiple chains using configuration from JSON
contract DeployMyOFT is Script {
    // Structs for JSON parsing
    struct ChainConfig {
        string name;
        uint32 eid;
        string rpc;
        address deployer;
        address lzEndpoint;
    }
    
    struct DeployConfig {
        string tokenName;
        string tokenSymbol;
        ChainConfig[] chains;
    }
    
    // Storage for deployments
    mapping(string => address) public deployedOFTs;
    
    /// @notice Main deployment function
    /// @param configPath Path to deployment configuration JSON
    function run(string memory configPath) external {
        // Get the private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address from private key:", deployer);
        
        // Parse deployment config
        string memory configJson = vm.readFile(configPath);
        
        // Parse the full config
        DeployConfig memory config = parseConfig(configJson);
        
        console.log(string.concat("Deploying ", config.tokenName, " (", config.tokenSymbol, ")"));
        console.log("Number of chains:", config.chains.length);
        
        // Deploy to each chain
        for (uint256 i = 0; i < config.chains.length; i++) {
            deployToChain(config.chains[i], config.tokenName, config.tokenSymbol, deployerPrivateKey);
        }
        
        // Output deployment summary
        console.log("\n=== Deployment Summary ===");
        for (uint256 i = 0; i < config.chains.length; i++) {
            console.log(string.concat(config.chains[i].name, ": ", vm.toString(deployedOFTs[config.chains[i].name])));
        }
        
        // Save deployment addresses to file
        saveDeployments(config.chains);
    }
    
    /// @notice Parse the deployment configuration from JSON
    function parseConfig(string memory json) internal pure returns (DeployConfig memory) {
        DeployConfig memory config;
        
        // Parse token details
        config.tokenName = vm.parseJsonString(json, ".tokenName");
        config.tokenSymbol = vm.parseJsonString(json, ".tokenSymbol");
        
        // Count the number of chains by trying to access array elements
        uint256 numChains = 0;
        while (true) {
            try vm.parseJsonString(json, string.concat(".chains[", vm.toString(numChains), "].name")) returns (string memory) {
                numChains++;
            } catch {
                break;
            }
        }
        
        // Initialize chains array
        config.chains = new ChainConfig[](numChains);
        
        // Parse each chain individually
        for (uint256 i = 0; i < numChains; i++) {
            string memory basePath = string.concat(".chains[", vm.toString(i), "]");
            
            config.chains[i].name = vm.parseJsonString(json, string.concat(basePath, ".name"));
            config.chains[i].eid = uint32(vm.parseJsonUint(json, string.concat(basePath, ".eid")));
            config.chains[i].rpc = vm.parseJsonString(json, string.concat(basePath, ".rpc"));
            config.chains[i].deployer = vm.parseJsonAddress(json, string.concat(basePath, ".deployer"));
            config.chains[i].lzEndpoint = vm.parseJsonAddress(json, string.concat(basePath, ".lzEndpoint"));
        }
        
        return config;
    }
    
    /// @notice Deploy MyOFT to a specific chain
    function deployToChain(
        ChainConfig memory chain,
        string memory tokenName,
        string memory tokenSymbol,
        uint256 deployerPrivateKey
    ) internal {
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log(string.concat("\nDeploying to ", chain.name));
        console.log("EID:", chain.eid);
        console.log(string.concat("RPC: ", chain.rpc));
        console.log("LayerZero Endpoint:", chain.lzEndpoint);
        console.log("Deployer:", deployer);
        
        // Switch to chain
        vm.createSelectFork(chain.rpc);
        
        // Start broadcast with private key
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MyOFT
        MyOFT oft = new MyOFT(
            tokenName,
            tokenSymbol,
            chain.lzEndpoint,
            deployer
        );
        
        console.log("MyOFT deployed at:", address(oft));
        console.log("Owner:", deployer);
        
        vm.stopBroadcast();
        
        // Store deployment
        deployedOFTs[chain.name] = address(oft);
    }
    
    /// @notice Save deployment addresses to a JSON file
    function saveDeployments(ChainConfig[] memory chains) internal {
        string memory deployments = "{";
        
        for (uint256 i = 0; i < chains.length; i++) {
            string memory chainName = chains[i].name;
            address oftAddress = deployedOFTs[chainName];
            
            deployments = string.concat(
                deployments,
                '"',
                chainName,
                '": { "oft": "',
                vm.toString(oftAddress),
                '", "eid": ',
                vm.toString(chains[i].eid),
                ', "lzEndpoint": "',
                vm.toString(chains[i].lzEndpoint),
                '" }'
            );
            
            if (i < chains.length - 1) {
                deployments = string.concat(deployments, ", ");
            }
        }
        
        deployments = string.concat(deployments, "}");
        
        // Write to file
        vm.writeJson(deployments, "./deployments/myoft-deployments.json");
        console.log("\nDeployments saved to deployments/myoft-deployments.json");
    }
} 