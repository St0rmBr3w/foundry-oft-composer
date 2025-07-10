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
        string rpc;  // Will be loaded from environment variables
        address deployer;  // Deprecated - will use private key
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
        
        console.log("=== DEPLOYMENT SCRIPT ===");
        console.log("Deployer address from private key:", deployer);
        
        // Parse deployment config
        string memory configJson = vm.readFile(configPath);
        
        // Parse the full config
        DeployConfig memory config = parseConfig(configJson);
        
        console.log(string.concat("Deploying ", config.tokenName, " (", config.tokenSymbol, ")"));
        console.log("Number of chains:", config.chains.length);
        
        // Deploy to each chain one at a time to avoid nonce issues
        for (uint256 i = 0; i < config.chains.length; i++) {
            console.log(string.concat("\n[", vm.toString(i + 1), "/", vm.toString(config.chains.length), "] Deploying to ", config.chains[i].name));
            deployToChain(config.chains[i], config.tokenName, config.tokenSymbol, deployerPrivateKey);
        }
        
        // Output deployment summary
        console.log("\n=== Deployment Summary ===");
        for (uint256 i = 0; i < config.chains.length; i++) {
            console.log(string.concat(config.chains[i].name, ": ", vm.toString(deployedOFTs[config.chains[i].name])));
        }
        
        // Save deployment addresses to file (this will be done after broadcast)
        console.log("\nSaving deployment artifacts...");
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
            
            // Try to parse RPC from config (for backward compatibility)
            try vm.parseJsonString(json, string.concat(basePath, ".rpc")) returns (string memory rpc) {
                config.chains[i].rpc = rpc;
            } catch {
                // Will load from environment variable later
                config.chains[i].rpc = "";
            }
            
            // Deployer is deprecated - we use private key
            try vm.parseJsonAddress(json, string.concat(basePath, ".deployer")) returns (address deployer) {
                config.chains[i].deployer = deployer;
            } catch {
                config.chains[i].deployer = address(0);
            }
            
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
        console.log("LayerZero Endpoint:", chain.lzEndpoint);
        console.log("Deployer:", deployer);
        
        // Get RPC URL from environment if not in config
        string memory rpcUrl = chain.rpc;
        if (bytes(rpcUrl).length == 0) {
            rpcUrl = getRpcUrl(chain.name);
        }
        console.log(string.concat("RPC: ", rpcUrl));
        
        // Switch to chain
        vm.createSelectFork(rpcUrl);
        
        // Start broadcast with private key
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MyOFT - this should be the only transaction
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
        // Keep the old format for backward compatibility
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
        
        // Write to file (old format) - this is safe outside broadcast context
        vm.writeJson(deployments, "./deployments/myoft-deployments.json");
        console.log("\nDeployments saved to deployments/myoft-deployments.json");
        
        // Also save in new standardized format
        saveStandardizedDeployment(chains);
    }
    
    /// @notice Save deployment in standardized format
    function saveStandardizedDeployment(ChainConfig[] memory chains) internal {
        string memory contractName = "MyOFT";
        string memory environment = "mainnet";
        try vm.envString("DEPLOYMENT_ENV") returns (string memory env) {
            environment = env;
        } catch {
            // Use default
        }
        
        // Build the deployment JSON manually for better control
        string memory json = "{";
        json = string.concat(json, '"contractName": "', contractName, '",');
        json = string.concat(json, '"contractType": "OFT",');
        json = string.concat(json, '"timestamp": "', vm.toString(block.timestamp), '",');
        json = string.concat(json, '"environment": "', environment, '",');
        json = string.concat(json, '"chains": {');
        
        for (uint256 i = 0; i < chains.length; i++) {
            string memory chainName = chains[i].name;
            address oftAddress = deployedOFTs[chainName];
            
            json = string.concat(json, '"', chainName, '": {');
            json = string.concat(json, '"eid": ', vm.toString(chains[i].eid), ',');
            json = string.concat(json, '"address": "', vm.toString(oftAddress), '",');
            json = string.concat(json, '"blockNumber": ', vm.toString(block.number), ',');
            json = string.concat(json, '"transactionHash": "0x0000000000000000000000000000000000000000000000000000000000000000"'); // Placeholder
            json = string.concat(json, '}');
            
            if (i < chains.length - 1) {
                json = string.concat(json, ',');
            }
        }
        
        json = string.concat(json, '}}');
        
        // Create directory if it doesn't exist
        string memory dirPath = string.concat("deployments/", environment);
        
        // Save to standardized location
        string memory filePath = string.concat(dirPath, "/", contractName, ".json");
        vm.writeJson(json, filePath);
        
        console.log(string.concat("\nStandardized deployment saved to ", filePath));
    }
    
    /// @notice Get RPC URL from environment variable
    function getRpcUrl(string memory chainName) internal view returns (string memory) {
        // Convert chain name to uppercase for env var
        string memory envVar = string.concat(toUpper(chainName), "_RPC");
        
        // Get RPC from environment
        string memory rpc = "";
        try vm.envString(envVar) returns (string memory envRpc) {
            rpc = envRpc;
        } catch {
            // Not found
        }
        require(bytes(rpc).length > 0, string.concat("RPC not found for chain: ", chainName, ". Set ", envVar, " environment variable."));
        
        return rpc;
    }
    
    /// @notice Convert string to uppercase
    function toUpper(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(strBytes.length);
        
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] >= 0x61 && strBytes[i] <= 0x7A) {
                // Convert lowercase to uppercase
                result[i] = bytes1(uint8(strBytes[i]) - 32);
            } else {
                result[i] = strBytes[i];
            }
        }
        
        return string(result);
    }
} 