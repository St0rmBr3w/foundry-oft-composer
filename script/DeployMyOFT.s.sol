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
        address lzEndpoint;  // Will be fetched from deployments JSON
    }
    
    struct DeployConfig {
        string tokenName;
        string tokenSymbol;
        ChainConfig[] chains;
    }
    
    // Storage for deployments
    mapping(string => address) public deployedOFTs;
    
    // Storage for LayerZero endpoints
    mapping(uint32 => address) public eidToEndpoint;
    
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
    
    /// @notice Fetch JSON data from API or local file
    /// @param source The source URL or file path
    /// @return The JSON string data
    function fetchJsonData(string memory source) internal returns (string memory) {
        // Check if it's a URL (starts with http:// or https://)
        bytes memory sourceBytes = bytes(source);
        bool isUrl = false;
        
        if (sourceBytes.length >= 7) {
            // Check for "http://" or "https://"
            if ((sourceBytes[0] == 'h' && sourceBytes[1] == 't' && sourceBytes[2] == 't' && sourceBytes[3] == 'p') &&
                ((sourceBytes[4] == ':' && sourceBytes[5] == '/' && sourceBytes[6] == '/') ||
                 (sourceBytes[4] == 's' && sourceBytes[5] == ':' && sourceBytes[6] == '/' && sourceBytes[7] == '/'))) {
                isUrl = true;
            }
        }
        
        if (isUrl) {
            console.log(string.concat("  Fetching from API: ", source));
            
            // Use curl to fetch data
            string[] memory curlCommand = new string[](7);
            curlCommand[0] = "curl";
            curlCommand[1] = "-s"; // Silent mode
            curlCommand[2] = "-X";
            curlCommand[3] = "GET";
            curlCommand[4] = source;
            curlCommand[5] = "-H";
            curlCommand[6] = "accept: application/json";
            
            try vm.ffi(curlCommand) returns (bytes memory result) {
                return string(result);
            } catch {
                revert(string.concat("Failed to fetch data from API: ", source));
            }
        } else {
            console.log(string.concat("  Reading from file: ", source));
            return vm.readFile(source);
        }
    }
    

    
    /// @notice Extract base EID from full EID (remove 30xxx or 40xxx prefix)
    function extractBaseEid(string memory fullEid) internal pure returns (string memory) {
        bytes memory eidBytes = bytes(fullEid);
        if (eidBytes.length >= 5) {
            // Return everything after the first 2 digits
            bytes memory baseBytes = new bytes(eidBytes.length - 2);
            for (uint256 i = 2; i < eidBytes.length; i++) {
                baseBytes[i - 2] = eidBytes[i];
            }
            return string(baseBytes);
        }
        return fullEid;
    }
    
    /// @notice Determine if we should check this chain based on name patterns
    function shouldCheckChain(string memory chainKey, bool isMainnet, string memory baseEid) internal pure returns (bool) {
        // Skip testnet chains if we're looking for mainnet EID
        if (isMainnet && containsTestnet(chainKey)) {
            return false;
        }
        
        // Skip mainnet chains if we're looking for testnet EID
        if (!isMainnet && !containsTestnet(chainKey)) {
            return false;
        }
        
        // Skip sandbox chains (they have different EID patterns)
        if (containsSandbox(chainKey)) {
            return false;
        }
        
        // Skip chains that are clearly not relevant (like non-EVM chains)
        if (isNonEVMChain(chainKey)) {
            return false;
        }
        
        return true;
    }
    
    /// @notice Check if chain name contains "sandbox"
    function containsSandbox(string memory chainName) internal pure returns (bool) {
        bytes memory nameBytes = bytes(chainName);
        bytes memory sandboxBytes = bytes("sandbox");
        
        for (uint256 i = 0; i <= nameBytes.length - sandboxBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < sandboxBytes.length; j++) {
                if (nameBytes[i + j] != sandboxBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }
    
    /// @notice Check if chain is non-EVM (can be extended with more patterns)
    function isNonEVMChain(string memory chainName) internal pure returns (bool) {
        // Add patterns for non-EVM chains that we want to skip
        // This can be extended based on the actual chain names in the JSON
        bytes memory nameBytes = bytes(chainName);
        
        // Skip chains that are clearly not EVM (this is a starting point)
        // We can add more patterns as needed
        return false; // For now, check all chains
    }
    
    /// @notice Check if EID is mainnet (starts with 30xxx)
    function isMainnetEid(string memory eid) internal pure returns (bool) {
        bytes memory eidBytes = bytes(eid);
        if (eidBytes.length >= 5) {
            // Check if it starts with "30"
            return eidBytes[0] == '3' && eidBytes[1] == '0';
        }
        return false;
    }
    
    /// @notice Check if EID is valid for v2 (at least 5 characters)
    function isValidV2Eid(string memory eid) internal pure returns (bool) {
        return bytes(eid).length >= 5;
    }
    
    /// @notice Check if chain name contains "testnet"
    function containsTestnet(string memory chainName) internal pure returns (bool) {
        bytes memory nameBytes = bytes(chainName);
        bytes memory testnetBytes = bytes("testnet");
        
        // Simple substring check for "testnet"
        for (uint256 i = 0; i <= nameBytes.length - testnetBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < testnetBytes.length; j++) {
                if (nameBytes[i + j] != testnetBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }
    
    /// @notice Search a specific chain for an EID (optimized for 2 deployments)
    function searchChainForEid(string memory json, string memory chainKey, string memory targetEid) internal view returns (address) {
        string memory chainPath = string.concat(".", chainKey, ".deployments");
        
        // Since we know there are typically only 2 deployments, check them directly
        // First check deployment[1] (likely version 2) - most efficient path
        try vm.parseJsonString(json, string.concat(chainPath, "[1].eid")) returns (string memory eidStr) {
            // Check if this is our target EID
            if (keccak256(bytes(eidStr)) == keccak256(bytes(targetEid))) {
                // Check if it's version 2
                try vm.parseJsonUint(json, string.concat(chainPath, "[1].version")) returns (uint256 version) {
                    if (version == 2) {
                        // Get the endpointV2 address
                        try vm.parseJsonAddress(json, string.concat(chainPath, "[1].endpointV2.address")) returns (address endpoint) {
                            return endpoint;
                        } catch {
                            // No endpointV2 found
                            return address(0);
                        }
                    }
                } catch {
                    // No version field
                    return address(0);
                }
            }
        } catch {
            // No deployment[1], try deployment[0]
        }
        
        // Fallback to deployment[0] if deployment[1] didn't work
        try vm.parseJsonString(json, string.concat(chainPath, "[0].eid")) returns (string memory eidStr) {
            // Check if this is our target EID
            if (keccak256(bytes(eidStr)) == keccak256(bytes(targetEid))) {
                // Check if it's version 2
                try vm.parseJsonUint(json, string.concat(chainPath, "[0].version")) returns (uint256 version) {
                    if (version == 2) {
                        // Get the endpointV2 address
                        try vm.parseJsonAddress(json, string.concat(chainPath, "[0].endpointV2.address")) returns (address endpoint) {
                            return endpoint;
                        } catch {
                            // No endpointV2 found
                            return address(0);
                        }
                    }
                } catch {
                    // No version field
                    return address(0);
                }
            }
        } catch {
            // No deployments in this chain
            return address(0);
        }
        
        return address(0);
    }
    

    

    

    
    /// @notice Convert uint32 array to string for logging
    function arrayToString(uint32[] memory arr) internal pure returns (string memory) {
        if (arr.length == 0) return "[]";
        
        string memory result = "[";
        for (uint256 i = 0; i < arr.length; i++) {
            result = string.concat(result, vm.toString(arr[i]));
            if (i < arr.length - 1) {
                result = string.concat(result, ", ");
            }
        }
        result = string.concat(result, "]");
        return result;
    }
    
    /// @notice Get the EIDs we need from our config
    function getNeededEids() internal view returns (uint32[] memory) {
        // Read config to get EIDs
        string memory configJson = vm.readFile("utils/deploy.config.json");
        
        // Count the number of chains
        uint256 numChains = 0;
        while (true) {
            try vm.parseJsonString(configJson, string.concat(".chains[", vm.toString(numChains), "].name")) returns (string memory) {
                numChains++;
            } catch {
                break;
            }
        }
        
        uint32[] memory eids = new uint32[](numChains);
        
        for (uint256 i = 0; i < numChains; i++) {
            string memory basePath = string.concat(".chains[", vm.toString(i), "]");
            eids[i] = uint32(vm.parseJsonUint(configJson, string.concat(basePath, ".eid")));
        }
        
        return eids;
    }
    
    /// @notice Check if an EID is in our needed list
    function isEidNeeded(uint32 eid, uint32[] memory neededEids) internal pure returns (bool) {
        for (uint256 i = 0; i < neededEids.length; i++) {
            if (neededEids[i] == eid) {
                return true;
            }
        }
        return false;
    }
    
    /// @notice Verify we found all needed EIDs
    function verifyAllEidsFound(uint32[] memory neededEids) internal view {
        for (uint256 i = 0; i < neededEids.length; i++) {
            uint32 eid = neededEids[i];
            if (eidToEndpoint[eid] == address(0)) {
                revert(string.concat("LayerZero endpoint not found for EID: ", vm.toString(eid)));
            }
        }
        console.log(string.concat("Successfully loaded endpoints for all ", vm.toString(neededEids.length), " EIDs"));
    }
    
    /// @notice Parse the deployment configuration from JSON
    function parseConfig(string memory json) internal view returns (DeployConfig memory) {
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
            
            // Require lzEndpoint provided directly in config
            try vm.parseJsonAddress(json, string.concat(basePath, ".lzEndpoint")) returns (address endpoint) {
                require(endpoint != address(0), "Invalid lzEndpoint address in config");
                config.chains[i].lzEndpoint = endpoint;
            } catch {
                revert(string.concat("lzEndpoint address missing for chain: ", config.chains[i].name));
            }
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
        
        // Ensure deployments directory exists
        string[] memory mk = new string[](3);
        mk[0] = "mkdir";
        mk[1] = "-p";
        mk[2] = "deployments";
        vm.ffi(mk);
        
        // Write to file
        vm.writeJson(deployments, "./deployments/MyOFT.json");
        console.log("\nDeployments saved to deployments/MyOFT.json");
        
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
        string[] memory mk2 = new string[](3);
        mk2[0] = "mkdir";
        mk2[1] = "-p";
        mk2[2] = dirPath;
        vm.ffi(mk2);
        
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