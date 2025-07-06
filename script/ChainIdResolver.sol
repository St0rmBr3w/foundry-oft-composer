// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

/// @title ChainIdResolver
/// @notice Maps standard chain IDs to LayerZero configuration
/// @dev Reads from layerzero-deployments.json to resolve chain details
contract ChainIdResolver is Script {
    
    struct ChainInfo {
        string lzName;          // LayerZero chain name (e.g., "base-mainnet")
        uint32 eid;             // LayerZero endpoint ID
        address endpoint;       // EndpointV2 address
        string name;            // Human-readable name (e.g., "Base")
        bool found;             // Whether the chain was found
    }
    
    /// @notice Resolve chain information from a standard chain ID
    /// @param chainId Standard EVM chain ID (e.g., 8453 for Base)
    /// @param deploymentPath Path to layerzero-deployments.json
    /// @return info Chain information including LayerZero details
    function resolveChainId(uint256 chainId, string memory deploymentPath) public view returns (ChainInfo memory info) {
        string memory deploymentsJson = vm.readFile(deploymentPath);
        
        // Parse the JSON to get all top-level keys (chain names)
        string[] memory chainKeys = vm.parseJsonKeys(deploymentsJson, "$");
        
        // Search for the chain with matching nativeChainId
        for (uint256 i = 0; i < chainKeys.length; i++) {
            string memory chainKey = chainKeys[i];
            
            // Try to parse nativeChainId
            try vm.parseJsonUint(deploymentsJson, string.concat(".", chainKey, ".chainDetails.nativeChainId")) returns (uint256 nativeChainId) {
                if (nativeChainId == chainId) {
                    // Found the chain!
                    info.lzName = chainKey;
                    info.found = true;
                    
                    // Get chain name
                    info.name = vm.parseJsonString(deploymentsJson, string.concat(".", chainKey, ".chainDetails.name"));
                    
                    // Find V2 deployment
                    uint256 deploymentCount = getDeploymentCount(deploymentsJson, chainKey);
                    for (uint256 j = 0; j < deploymentCount; j++) {
                        string memory deployPath = string.concat(".", chainKey, ".deployments[", vm.toString(j), "]");
                        
                        // Check if this is V2
                        try vm.parseJsonUint(deploymentsJson, string.concat(deployPath, ".version")) returns (uint256 version) {
                            if (version == 2) {
                                // Get endpoint ID
                                info.eid = uint32(vm.parseJsonUint(deploymentsJson, string.concat(deployPath, ".eid")));
                                
                                // Get endpoint address
                                info.endpoint = vm.parseJsonAddress(deploymentsJson, string.concat(deployPath, ".endpointV2.address"));
                                
                                return info;
                            }
                        } catch {
                            // Not a V2 deployment, continue
                        }
                    }
                }
            } catch {
                // Chain doesn't have nativeChainId, skip it
            }
        }
        
        return info; // Not found
    }
    
    /// @notice Get the number of deployments for a chain
    function getDeploymentCount(string memory json, string memory chainKey) internal pure returns (uint256) {
        // Try to access deployment array elements until we hit an error
        uint256 count = 0;
        while (count < 10) { // Safety limit
            try vm.parseJsonUint(json, string.concat(".", chainKey, ".deployments[", vm.toString(count), "].version")) returns (uint256) {
                count++;
            } catch {
                break;
            }
        }
        return count;
    }
    
    /// @notice Helper to print chain info
    function printChainInfo(ChainInfo memory info) internal pure {
        if (!info.found) {
            console.log("Chain not found in LayerZero deployments");
            return;
        }
        
        console.log("=== Chain Information ===");
        console.log("Name:", info.name);
        console.log("LayerZero Name:", info.lzName);
        console.log("Endpoint ID:", info.eid);
        console.log("Endpoint Address:", info.endpoint);
    }
} 