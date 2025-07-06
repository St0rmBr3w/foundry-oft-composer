// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { SetConfigParam } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { UlnConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import { ExecutorConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import { IOAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

// Interface for accessing enforcedOptions mapping
interface IOAppWithEnforcedOptions {
    function enforcedOptions(uint32 eid, uint16 msgType) external view returns (bytes memory);
}

/// @title LayerZero OApp Wire Script
/// @notice Automatically wires LayerZero pathways using deployment artifacts from JSON API
/// @dev Uses vm.parseJson to read LayerZero deployment contracts and configure pathways
contract WireOApp is Script {
    using OptionsBuilder for bytes;
    
    // Config types for LayerZero
    uint32 constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 constant ULN_CONFIG_TYPE = 2;
    
    // Message types
    uint16 constant MSG_TYPE_STANDARD = 1;
    uint16 constant MSG_TYPE_COMPOSED = 2;

    // Structs to match JSON deployment structure
    struct Deployment {
        uint32 eid;
        EndpointInfo endpointV2;
        EndpointInfo sendUln302;
        EndpointInfo receiveUln302;
        EndpointInfo executor;
        uint256 version;
    }

    struct EndpointInfo {
        address addr; // renamed from 'address' to avoid keyword conflict
    }

    struct ChainDeployments {
        Deployment[] deployments;
    }

    // Configuration structures
    struct ChainConfig {
        uint32 eid;
        string rpc;
        address signer;
        address oapp; // OApp address on this chain
    }

    struct PathwayConfig {
        uint32 srcEid;
        uint32 dstEid;
        address srcOApp;
        address dstOApp;
        uint64 confirmations;
        uint8 requiredDVNCount;
        address[] srcRequiredDVNs;    // DVNs on source chain for send config
        address[] dstRequiredDVNs;    // DVNs on destination chain for receive config
        address[] srcOptionalDVNs;    // Optional DVNs on source chain
        address[] dstOptionalDVNs;    // Optional DVNs on destination chain
        uint8 optionalDVNThreshold;
        uint32 maxMessageSize;
        EnforcedOptions enforcedOptions;
    }

    struct RawPathwayConfig {
        string from;
        string to;
        string[] requiredDVNs;
        string[] optionalDVNs;
        uint8 optionalDVNThreshold;
        uint64[] confirmations; // [AtoB, BtoA]
        uint32 maxMessageSize;
        EnforcedOptions[] enforcedOptions; // [AtoB, BtoA]
    }
    
    struct EnforcedOptions {
        uint128 lzReceiveGas;        // Gas for standard message (msgType 1)
        uint128 lzReceiveValue;      // Value for standard message (msgType 1)
        uint128 lzComposeGas;        // Gas for composed message (msgType 2)
        uint16 lzComposeIndex;       // Index for composed message (msgType 2)
        uint128 lzNativeDropAmount;  // Amount for native drop
        address lzNativeDropRecipient; // Recipient for native drop
    }

    struct WireConfig {
        PathwayConfig[] pathways;
        bool bidirectional;
    }

    // Storage for parsed deployments
    mapping(uint32 => Deployment) public deployments;
    
    // Storage for RPC and signer mappings
    mapping(uint32 => string) public eidToRpc;
    mapping(uint32 => address) public eidToSigner; // DEPRECATED - will use private key
    
    // Storage for chain name to config mapping
    mapping(string => ChainConfig) public chainConfigs;
    
    // Storage for DVN name to chain to address mapping
    mapping(string => mapping(string => address)) public dvnAddresses;
    
    // Storage for private key
    uint256 private deployerPrivateKey;
    
    // Storage for configured chain names
    string[] private configuredChainNames;
    
    /// @notice Main function to wire all pathways for an OApp
    /// @param configPath Path to JSON config file containing pathway configurations
    /// @param deploymentJsonPath Path to JSON file with LayerZero deployments
    /// @param dvnJsonPath Path to JSON file with LayerZero DVN metadata
    function run(string memory configPath, string memory deploymentJsonPath, string memory dvnJsonPath) external {
        // Get the private key from environment
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(deployerPrivateKey);
        console.log("Signer address from private key:", signer);
        
        // Check if we're in check-only mode
        bool checkOnly = vm.envOr("CHECK_ONLY", false);
        if (checkOnly) {
            console.log("\n*** RUNNING IN CHECK-ONLY MODE ***\n");
        }
        
        // Read config JSON
        string memory configJson = vm.readFile(configPath);
        
        // Parse basic configuration and chain configs first
        bool bidirectional = vm.parseJsonBool(configJson, ".bidirectional");
        parseChainConfigs(configJson);
        parseDVNOverrides(configJson);
        
        // Parse LayerZero deployments (only for configured chains)
        parseDeployments(deploymentJsonPath);
        
        // Parse LayerZero DVN metadata
        parseDVNMetadata(dvnJsonPath);
        
        // Now parse pathways after DVN metadata is loaded
        PathwayConfig[] memory pathways = parsePathways(configJson, bidirectional);
        
        if (checkOnly) {
            // Just check status without wiring
            console.log("\n=== CONFIGURATION STATUS ===");
            for (uint256 i = 0; i < pathways.length; i++) {
                checkPathwayStatus(pathways[i]);
            }
            console.log("\n=== END STATUS CHECK ===");
        } else {
            // Wire each pathway
            for (uint256 i = 0; i < pathways.length; i++) {
                // Check status before
                console.log("\n[BEFORE] Checking pathway status...");
                checkPathwayStatus(pathways[i]);
                
                // Wire the pathway
                wirePathway(pathways[i]);
                
                // Check status after
                console.log("\n[AFTER] Checking pathway status...");
                checkPathwayStatus(pathways[i]);
            }
            
            console.log("Successfully wired all pathways");
        }
    }

    /// @notice Parse wire configuration from JSON
    function parseWireConfig(string memory configPath) internal returns (WireConfig memory config) {
        string memory json = vm.readFile(configPath);
        
        config.bidirectional = vm.parseJsonBool(json, ".bidirectional");
        
        // Parse chain configurations
        parseChainConfigs(json);
        
        // Parse DVN mappings (optional - for overrides)
        parseDVNOverrides(json);
        
        // Parse raw pathways and convert to PathwayConfig
        config.pathways = parsePathways(json, config.bidirectional);
        
        return config;
    }
    
    /// @notice Parse chain configurations from JSON
    function parseChainConfigs(string memory json) internal {
        // Get all chain names
        string[] memory chainNames = vm.parseJsonKeys(json, ".chains");
        
        // Store chain names for later use
        configuredChainNames = chainNames;
        
        for (uint256 i = 0; i < chainNames.length; i++) {
            string memory chainName = chainNames[i];
            string memory chainPath = string.concat(".chains.", chainName);
            
            ChainConfig memory chainConfig;
            chainConfig.eid = uint32(vm.parseJsonUint(json, string.concat(chainPath, ".eid")));
            chainConfig.rpc = vm.parseJsonString(json, string.concat(chainPath, ".rpc"));
            // signer field is now deprecated, but we still parse it for backward compatibility
            try vm.parseJsonAddress(json, string.concat(chainPath, ".signer")) returns (address signer) {
                chainConfig.signer = signer;
            } catch {
                // If signer is not provided or is invalid, we'll use the one from private key
                chainConfig.signer = address(0);
            }
            chainConfig.oapp = vm.parseJsonAddress(json, string.concat(chainPath, ".oapp"));
            
            // Store in mappings
            chainConfigs[chainName] = chainConfig;
            eidToRpc[chainConfig.eid] = chainConfig.rpc;
            // Don't store signer anymore - we'll use private key
        }
    }
    
    /// @notice Parse DVN metadata from LayerZero API JSON
    function parseDVNMetadata(string memory jsonPath) internal {
        console.log("Starting to parse DVN metadata from:", jsonPath);
        string memory json = vm.readFile(jsonPath);
        
        // Only parse DVN metadata for chains we're actually using
        for (uint256 i = 0; i < configuredChainNames.length; i++) {
            string memory chainName = configuredChainNames[i];
            
            // Map to deployment chain name
            string memory deploymentChainName = mapChainName(chainName);
            
            // Try to parse DVNs for this chain
            try vm.parseJsonKeys(json, string.concat(".", deploymentChainName, ".dvns")) returns (string[] memory dvnAddressList) {
                string memory chainPath = string.concat(".", deploymentChainName, ".dvns");
                
                for (uint256 j = 0; j < dvnAddressList.length; j++) {
                    string memory dvnAddress = dvnAddressList[j];
                    string memory dvnPath = string.concat(chainPath, ".", dvnAddress);
                    
                    // Check if DVN is deprecated
                    bool deprecated;
                    try vm.parseJsonBool(json, string.concat(dvnPath, ".deprecated")) returns (bool dep) {
                        deprecated = dep;
                    } catch {
                        deprecated = false;
                    }
                    
                    // Check if DVN is lzReadCompatible (read-only, not for validation)
                    bool lzReadCompatible;
                    try vm.parseJsonBool(json, string.concat(dvnPath, ".lzReadCompatible")) returns (bool readOnly) {
                        lzReadCompatible = readOnly;
                    } catch {
                        lzReadCompatible = false;
                    }
                    
                    if (!deprecated && !lzReadCompatible) {
                        // Get canonical name
                        string memory canonicalName = vm.parseJsonString(json, string.concat(dvnPath, ".canonicalName"));
                        
                        // Log LayerZero Labs specifically
                        if (keccak256(bytes(canonicalName)) == keccak256(bytes("LayerZero Labs"))) {
                            console.log("Storing LayerZero Labs for", chainName, ":", dvnAddress);
                        }
                        
                        // Store mapping from canonical name to address
                        // Store under the original chain name (not deployment name) for easier lookup
                        dvnAddresses[canonicalName][chainName] = vm.parseAddress(dvnAddress);
                        
                        // Verify storage
                        if (keccak256(bytes(canonicalName)) == keccak256(bytes("LayerZero Labs"))) {
                            console.log("Verification - LayerZero Labs stored for", chainName, ":", dvnAddresses[canonicalName][chainName]);
                        }
                    }
                }
                
                console.log("Loaded DVN metadata for", chainName);
            } catch {
                console.log("Warning: No DVN metadata found for chain:", chainName);
            }
        }
        
        console.log("Loaded DVN metadata for", configuredChainNames.length, "configured chains");
    }
    
    /// @notice Parse DVN overrides from config JSON (optional)
    function parseDVNOverrides(string memory json) internal {
        // Check if dvns section exists
        try vm.parseJsonKeys(json, ".dvns") returns (string[] memory dvnNames) {
            for (uint256 i = 0; i < dvnNames.length; i++) {
                string memory dvnName = dvnNames[i];
                string memory dvnPath = string.concat(".dvns.", dvnName);
                
                // Get all chains for this DVN
                string[] memory chainNames = vm.parseJsonKeys(json, dvnPath);
                
                for (uint256 j = 0; j < chainNames.length; j++) {
                    string memory chainName = chainNames[j];
                    address dvnAddress = vm.parseJsonAddress(json, string.concat(dvnPath, ".", chainName));
                    dvnAddresses[dvnName][chainName] = dvnAddress;
                }
            }
            console.log("Applied DVN overrides for", dvnNames.length, "DVNs");
        } catch {
            // No DVN overrides provided, which is fine
        }
    }
    
    /// @notice Parse pathways from JSON and convert to PathwayConfig array
    function parsePathways(string memory json, bool bidirectional) internal view returns (PathwayConfig[] memory) {
        // Count the number of pathways
        uint256 pathwayCount = 0;
        while (true) {
            try vm.parseJsonString(json, string.concat(".pathways[", vm.toString(pathwayCount), "].from")) returns (string memory) {
                pathwayCount++;
            } catch {
                break;
            }
        }
        
        // Calculate total pathways (double if bidirectional)
        uint256 totalPathways = bidirectional ? pathwayCount * 2 : pathwayCount;
        PathwayConfig[] memory pathways = new PathwayConfig[](totalPathways);
        
        uint256 pathwayIndex = 0;
        for (uint256 i = 0; i < pathwayCount; i++) {
            // Parse raw pathway
            RawPathwayConfig memory raw = parseRawPathway(json, i);
            
            // Create forward pathway
            pathways[pathwayIndex] = createPathwayConfig(raw);
            pathwayIndex++;
            
            // Create reverse pathway if bidirectional
            if (bidirectional) {
                pathways[pathwayIndex] = createReversePathwayConfig(raw);
                pathwayIndex++;
            }
        }
        
        return pathways;
    }
    
    /// @notice Parse a single raw pathway from JSON
    function parseRawPathway(string memory json, uint256 index) internal pure returns (RawPathwayConfig memory) {
        string memory basePath = string.concat(".pathways[", vm.toString(index), "]");
        RawPathwayConfig memory raw;
        
        // Parse basic fields
        raw.from = vm.parseJsonString(json, string.concat(basePath, ".from"));
        raw.to = vm.parseJsonString(json, string.concat(basePath, ".to"));
        raw.optionalDVNThreshold = uint8(vm.parseJsonUint(json, string.concat(basePath, ".optionalDVNThreshold")));
        raw.maxMessageSize = uint32(vm.parseJsonUint(json, string.concat(basePath, ".maxMessageSize")));
        
        // Parse required DVNs
        uint256 requiredDVNCount = 0;
        while (true) {
            try vm.parseJsonString(json, string.concat(basePath, ".requiredDVNs[", vm.toString(requiredDVNCount), "]")) returns (string memory) {
                requiredDVNCount++;
            } catch {
                break;
            }
        }
        raw.requiredDVNs = new string[](requiredDVNCount);
        for (uint256 i = 0; i < requiredDVNCount; i++) {
            raw.requiredDVNs[i] = vm.parseJsonString(json, string.concat(basePath, ".requiredDVNs[", vm.toString(i), "]"));
        }
        
        // Parse optional DVNs
        uint256 optionalDVNCount = 0;
        while (true) {
            try vm.parseJsonString(json, string.concat(basePath, ".optionalDVNs[", vm.toString(optionalDVNCount), "]")) returns (string memory) {
                optionalDVNCount++;
            } catch {
                break;
            }
        }
        raw.optionalDVNs = new string[](optionalDVNCount);
        for (uint256 i = 0; i < optionalDVNCount; i++) {
            raw.optionalDVNs[i] = vm.parseJsonString(json, string.concat(basePath, ".optionalDVNs[", vm.toString(i), "]"));
        }
        
        // Parse confirmations array
        uint256 confirmationCount = 0;
        while (true) {
            try vm.parseJsonUint(json, string.concat(basePath, ".confirmations[", vm.toString(confirmationCount), "]")) returns (uint256) {
                confirmationCount++;
            } catch {
                break;
            }
        }
        raw.confirmations = new uint64[](confirmationCount);
        for (uint256 i = 0; i < confirmationCount; i++) {
            raw.confirmations[i] = uint64(vm.parseJsonUint(json, string.concat(basePath, ".confirmations[", vm.toString(i), "]")));
        }
        
        // Parse enforced options array
        uint256 enforcedOptionsCount = 0;
        while (true) {
            try vm.parseJsonUint(json, string.concat(basePath, ".enforcedOptions[", vm.toString(enforcedOptionsCount), "].lzReceiveGas")) returns (uint256) {
                enforcedOptionsCount++;
            } catch {
                break;
            }
        }
        raw.enforcedOptions = new EnforcedOptions[](enforcedOptionsCount);
        for (uint256 i = 0; i < enforcedOptionsCount; i++) {
            string memory optPath = string.concat(basePath, ".enforcedOptions[", vm.toString(i), "]");
            raw.enforcedOptions[i].lzReceiveGas = uint128(vm.parseJsonUint(json, string.concat(optPath, ".lzReceiveGas")));
            raw.enforcedOptions[i].lzReceiveValue = uint128(vm.parseJsonUint(json, string.concat(optPath, ".lzReceiveValue")));
            raw.enforcedOptions[i].lzComposeGas = uint128(vm.parseJsonUint(json, string.concat(optPath, ".lzComposeGas")));
            raw.enforcedOptions[i].lzComposeIndex = uint16(vm.parseJsonUint(json, string.concat(optPath, ".lzComposeIndex")));
            raw.enforcedOptions[i].lzNativeDropAmount = uint128(vm.parseJsonUint(json, string.concat(optPath, ".lzNativeDropAmount")));
            raw.enforcedOptions[i].lzNativeDropRecipient = vm.parseJsonAddress(json, string.concat(optPath, ".lzNativeDropRecipient"));
        }
        
        return raw;
    }
    
    /// @notice Create a PathwayConfig from a RawPathwayConfig
    function createPathwayConfig(RawPathwayConfig memory raw) internal view returns (PathwayConfig memory) {
        PathwayConfig memory pathway;
        
        // Get chain configs
        ChainConfig memory fromChain = chainConfigs[raw.from];
        ChainConfig memory toChain = chainConfigs[raw.to];
        
        pathway.srcEid = fromChain.eid;
        pathway.dstEid = toChain.eid;
        pathway.srcOApp = fromChain.oapp;
        pathway.dstOApp = toChain.oapp;
        // Use first element for A->B confirmations
        // This value is used for both source send config and destination receive config
        pathway.confirmations = raw.confirmations.length > 0 ? raw.confirmations[0] : 15;
        pathway.optionalDVNThreshold = raw.optionalDVNThreshold;
        pathway.maxMessageSize = raw.maxMessageSize;
        // Use first element for A->B enforced options
        pathway.enforcedOptions = raw.enforcedOptions.length > 0 ? raw.enforcedOptions[0] : EnforcedOptions({
            lzReceiveGas: 200000,
            lzReceiveValue: 0,
            lzComposeGas: 0,
            lzComposeIndex: 0,
            lzNativeDropAmount: 0,
            lzNativeDropRecipient: address(0)
        });
        
        // Resolve required DVN names to addresses for SOURCE chain (for send config)
        pathway.srcRequiredDVNs = new address[](raw.requiredDVNs.length);
        for (uint256 i = 0; i < raw.requiredDVNs.length; i++) {
            console.log("Looking for DVN:", raw.requiredDVNs[i], "on source chain:", raw.from);
            address dvnAddress = dvnAddresses[raw.requiredDVNs[i]][raw.from];
            console.log("Found address:", dvnAddress);
            
            require(dvnAddress != address(0), 
                string.concat("Required DVN '", raw.requiredDVNs[i], "' not found in metadata for source chain '", raw.from, "'"));
            pathway.srcRequiredDVNs[i] = dvnAddress;
        }
        
        // Resolve required DVN names to addresses for DESTINATION chain (for receive config)
        pathway.dstRequiredDVNs = new address[](raw.requiredDVNs.length);
        for (uint256 i = 0; i < raw.requiredDVNs.length; i++) {
            console.log("Looking for DVN:", raw.requiredDVNs[i], "on destination chain:", raw.to);
            address dvnAddress = dvnAddresses[raw.requiredDVNs[i]][raw.to];
            console.log("Found address:", dvnAddress);
            
            require(dvnAddress != address(0), 
                string.concat("Required DVN '", raw.requiredDVNs[i], "' not found in metadata for destination chain '", raw.to, "'"));
            pathway.dstRequiredDVNs[i] = dvnAddress;
        }
        pathway.requiredDVNCount = uint8(pathway.srcRequiredDVNs.length);
        
        // Resolve optional DVN names to addresses for SOURCE chain
        pathway.srcOptionalDVNs = new address[](raw.optionalDVNs.length);
        for (uint256 i = 0; i < raw.optionalDVNs.length; i++) {
            address dvnAddress = dvnAddresses[raw.optionalDVNs[i]][raw.from];
            
            // Optional DVNs can be missing, but log a warning
            if (dvnAddress == address(0)) {
                console.log("Warning: Optional DVN not found in metadata:", raw.optionalDVNs[i], "on source", raw.from);
            }
            
            pathway.srcOptionalDVNs[i] = dvnAddress;
        }
        
        // Resolve optional DVN names to addresses for DESTINATION chain
        pathway.dstOptionalDVNs = new address[](raw.optionalDVNs.length);
        for (uint256 i = 0; i < raw.optionalDVNs.length; i++) {
            address dvnAddress = dvnAddresses[raw.optionalDVNs[i]][raw.to];
            
            // Optional DVNs can be missing, but log a warning
            if (dvnAddress == address(0)) {
                console.log("Warning: Optional DVN not found in metadata:", raw.optionalDVNs[i], "on destination", raw.to);
            }
            
            pathway.dstOptionalDVNs[i] = dvnAddress;
        }
        
        return pathway;
    }
    
    /// @notice Create a reverse PathwayConfig from a RawPathwayConfig
    function createReversePathwayConfig(RawPathwayConfig memory raw) internal view returns (PathwayConfig memory) {
        PathwayConfig memory pathway;
        
        // Get chain configs (reversed)
        ChainConfig memory fromChain = chainConfigs[raw.to];
        ChainConfig memory toChain = chainConfigs[raw.from];
        
        pathway.srcEid = fromChain.eid;
        pathway.dstEid = toChain.eid;
        pathway.srcOApp = fromChain.oapp;
        pathway.dstOApp = toChain.oapp;
        // Use second element for B->A confirmations, or first if only one provided
        // This value is used for both source send config and destination receive config
        pathway.confirmations = raw.confirmations.length > 1 ? raw.confirmations[1] : 
                               (raw.confirmations.length > 0 ? raw.confirmations[0] : 15);
        pathway.optionalDVNThreshold = raw.optionalDVNThreshold;
        pathway.maxMessageSize = raw.maxMessageSize;
        // Use second element for B->A enforced options, or first if only one provided
        pathway.enforcedOptions = raw.enforcedOptions.length > 1 ? raw.enforcedOptions[1] : 
                                 (raw.enforcedOptions.length > 0 ? raw.enforcedOptions[0] : EnforcedOptions({
            lzReceiveGas: 200000,
            lzReceiveValue: 0,
            lzComposeGas: 0,
            lzComposeIndex: 0,
            lzNativeDropAmount: 0,
            lzNativeDropRecipient: address(0)
        }));
        
        // Resolve required DVN names to addresses for SOURCE chain (for send config)
        pathway.srcRequiredDVNs = new address[](raw.requiredDVNs.length);
        for (uint256 i = 0; i < raw.requiredDVNs.length; i++) {
            console.log("Looking for DVN:", raw.requiredDVNs[i], "on source chain:", raw.to);
            address dvnAddress = dvnAddresses[raw.requiredDVNs[i]][raw.to];
            console.log("Found address:", dvnAddress);
            
            require(dvnAddress != address(0), 
                string.concat("Required DVN '", raw.requiredDVNs[i], "' not found in metadata for source chain '", raw.to, "'"));
            pathway.srcRequiredDVNs[i] = dvnAddress;
        }
        
        // Resolve required DVN names to addresses for DESTINATION chain (for receive config)
        pathway.dstRequiredDVNs = new address[](raw.requiredDVNs.length);
        for (uint256 i = 0; i < raw.requiredDVNs.length; i++) {
            console.log("Looking for DVN:", raw.requiredDVNs[i], "on destination chain:", raw.from);
            address dvnAddress = dvnAddresses[raw.requiredDVNs[i]][raw.from];
            console.log("Found address:", dvnAddress);
            
            require(dvnAddress != address(0), 
                string.concat("Required DVN '", raw.requiredDVNs[i], "' not found in metadata for destination chain '", raw.from, "'"));
            pathway.dstRequiredDVNs[i] = dvnAddress;
        }
        pathway.requiredDVNCount = uint8(pathway.dstRequiredDVNs.length);
        
        // Resolve optional DVN names to addresses for SOURCE chain (raw.to in reverse)
        pathway.srcOptionalDVNs = new address[](raw.optionalDVNs.length);
        for (uint256 i = 0; i < raw.optionalDVNs.length; i++) {
            address dvnAddress = dvnAddresses[raw.optionalDVNs[i]][raw.to];
            
            // Optional DVNs can be missing, but log a warning
            if (dvnAddress == address(0)) {
                console.log("Warning: Optional DVN not found in metadata:", raw.optionalDVNs[i], "on source", raw.to);
            }
            
            pathway.srcOptionalDVNs[i] = dvnAddress;
        }
        
        // Resolve optional DVN names to addresses for DESTINATION chain (raw.from in reverse)
        pathway.dstOptionalDVNs = new address[](raw.optionalDVNs.length);
        for (uint256 i = 0; i < raw.optionalDVNs.length; i++) {
            address dvnAddress = dvnAddresses[raw.optionalDVNs[i]][raw.from];
            
            // Optional DVNs can be missing, but log a warning
            if (dvnAddress == address(0)) {
                console.log("Warning: Optional DVN not found in metadata:", raw.optionalDVNs[i], "on destination", raw.from);
            }
            
            pathway.dstOptionalDVNs[i] = dvnAddress;
        }
        
        return pathway;
    }

    /// @notice Parse LayerZero deployments from JSON
    function parseDeployments(string memory jsonPath) internal {
        string memory json;
        
        // Check if it's a URL or file path
        if (bytes(jsonPath).length > 4 && keccak256(bytes(substring(jsonPath, 0, 4))) == keccak256(bytes("http"))) {
            // For URL, you'd need to fetch via curl or another method
            revert("URL fetching not implemented - use local JSON file");
        } else {
            json = vm.readFile(jsonPath);
        }
        
        // Only parse deployments for chains we're actually using
        for (uint256 i = 0; i < configuredChainNames.length; i++) {
            string memory chainName = configuredChainNames[i];
            
            // Map common chain name variations (use deployment-specific mapping)
            string memory deploymentChainName = mapChainNameForDeployment(chainName);
            
            // Skip if this chain doesn't exist in the deployments
            try vm.parseJson(json, string.concat(".", deploymentChainName, ".deployments[0]")) returns (bytes memory) {
                // Count deployments for this chain
                uint256 deploymentCount = 0;
                while (true) {
                    try vm.parseJsonUint(json, string.concat(".", deploymentChainName, ".deployments[", vm.toString(deploymentCount), "].eid")) returns (uint256) {
                        deploymentCount++;
                    } catch {
                        break;
                    }
                }
                
                // Parse each deployment individually
                for (uint256 j = 0; j < deploymentCount; j++) {
                    string memory deploymentPath = string.concat(".", deploymentChainName, ".deployments[", vm.toString(j), "]");
                    
                    // Check version first
                    uint256 version = vm.parseJsonUint(json, string.concat(deploymentPath, ".version"));
                    
                    // Only process V2 deployments
                    if (version == 2) {
                        Deployment memory deployment;
                        deployment.eid = uint32(vm.parseJsonUint(json, string.concat(deploymentPath, ".eid")));
                        deployment.version = version;
                        
                        // Parse endpoint addresses
                        deployment.endpointV2.addr = vm.parseJsonAddress(json, string.concat(deploymentPath, ".endpointV2.address"));
                        deployment.sendUln302.addr = vm.parseJsonAddress(json, string.concat(deploymentPath, ".sendUln302.address"));
                        deployment.receiveUln302.addr = vm.parseJsonAddress(json, string.concat(deploymentPath, ".receiveUln302.address"));
                        deployment.executor.addr = vm.parseJsonAddress(json, string.concat(deploymentPath, ".executor.address"));
                        
                        // Store deployment
                        deployments[deployment.eid] = deployment;
                        console.log("Loaded deployment for", chainName, "EID:", deployment.eid);
                    }
                }
            } catch {
                console.log("Warning: No deployment found for chain:", deploymentChainName);
            }
        }
    }
    
    /// @notice Map chain names to their deployment JSON keys
    function mapChainName(string memory chainName) internal pure returns (string memory) {
        // For DVN JSON, chains are typically stored without the "-mainnet" suffix
        // Just return the chain name as-is for now
        // If we need different mappings, we can add them here
        return chainName;
    }
    
    /// @notice Map chain names to their deployment JSON keys for deployment files
    function mapChainNameForDeployment(string memory chainName) internal pure returns (string memory) {
        // For deployment JSON, chains are typically stored with the "-mainnet" suffix
        return string.concat(chainName, "-mainnet");
    }

    /// @notice Wire a single pathway between source and destination
    function wirePathway(PathwayConfig memory pathway) internal {
        // Get deployments
        Deployment memory srcDeployment = deployments[pathway.srcEid];
        Deployment memory dstDeployment = deployments[pathway.dstEid];
        
        require(srcDeployment.endpointV2.addr != address(0), "Source deployment not found");
        require(dstDeployment.endpointV2.addr != address(0), "Destination deployment not found");
        
        console.log("\n========================================");
        console.log("Wiring pathway:");
        console.log("  From:", pathway.srcEid, "OApp:", pathway.srcOApp);
        console.log("  To:", pathway.dstEid, "OApp:", pathway.dstOApp);
        console.log("  Confirmations:", pathway.confirmations);
        console.log("========================================\n");
        
        // Wire source chain (setSendLibrary, setPeer, setEnforcedOptions and send configs for source OApp)
        console.log(">>> Configuring source chain...");
        wireSourceChain(
            pathway.srcOApp,
            pathway,
            srcDeployment,
            eidToRpc[pathway.srcEid]
        );
        
        // Wire destination chain (setReceiveLibrary, setPeer and receive configs for destination OApp)
        console.log("\n>>> Configuring destination chain...");
        wireDestinationChain(
            pathway.dstOApp,
            pathway,
            dstDeployment,
            eidToRpc[pathway.dstEid]
        );
        
        console.log("\n>>> Pathway configuration complete!");
    }

    /// @notice Configure source chain (setSendLibrary + send configs on source OApp)
    function wireSourceChain(
        address oapp,
        PathwayConfig memory pathway,
        Deployment memory deployment,
        string memory rpcUrl
    ) internal {
        // Switch to source chain
        vm.createSelectFork(rpcUrl);
        
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(deployment.endpointV2.addr);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check and set send library on the source OApp for the destination chain
        address currentSendLib = endpoint.getSendLibrary(oapp, pathway.dstEid);
        if (currentSendLib != deployment.sendUln302.addr) {
            endpoint.setSendLibrary(oapp, pathway.dstEid, deployment.sendUln302.addr);
            console.log("Set send library for pathway", pathway.srcEid, "->", pathway.dstEid);
        } else {
            console.log("Send library already set for pathway", pathway.srcEid, "->", pathway.dstEid);
        }
        
        // Check and set peer on source OApp for the destination OApp
        bytes32 expectedPeer = bytes32(uint256(uint160(pathway.dstOApp)));
        bytes32 currentPeer = IOAppCore(oapp).peers(pathway.dstEid);
        if (currentPeer != expectedPeer) {
            IOAppCore(oapp).setPeer(pathway.dstEid, expectedPeer);
            console.log("Set peer on source OApp", oapp, "for destination", pathway.dstOApp);
        } else {
            console.log("Peer already set on source OApp", oapp, "for destination", pathway.dstOApp);
        }
        
        // Set enforced options on source OApp
        setEnforcedOptions(oapp, pathway.dstEid, pathway.enforcedOptions);
        
        // Set send configurations
        setSendConfigurations(
            endpoint,
            oapp,
            deployment.sendUln302.addr,
            pathway,
            deployment.executor.addr
        );
        
        vm.stopBroadcast();
    }

    /// @notice Configure destination chain (setReceiveLibrary, setPeer and receive configs on destination OApp)
    function wireDestinationChain(
        address oapp,
        PathwayConfig memory pathway,
        Deployment memory deployment,
        string memory rpcUrl
    ) internal {
        // Switch to destination chain
        vm.createSelectFork(rpcUrl);
        
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(deployment.endpointV2.addr);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check and set receive library on the destination OApp for the source chain
        (address currentReceiveLib, ) = endpoint.getReceiveLibrary(oapp, pathway.srcEid);
        if (currentReceiveLib != deployment.receiveUln302.addr) {
            endpoint.setReceiveLibrary(oapp, pathway.srcEid, deployment.receiveUln302.addr, 0);
            console.log("Set receive library for pathway", pathway.srcEid, "->", pathway.dstEid);
        } else {
            console.log("Receive library already set for pathway", pathway.srcEid, "->", pathway.dstEid);
        }
        
        // Check and set peer on destination OApp for the source OApp
        bytes32 expectedPeer = bytes32(uint256(uint160(pathway.srcOApp)));
        bytes32 currentPeer = IOAppCore(oapp).peers(pathway.srcEid);
        if (currentPeer != expectedPeer) {
            IOAppCore(oapp).setPeer(pathway.srcEid, expectedPeer);
            console.log("Set peer on destination OApp", oapp, "for source", pathway.srcOApp);
        } else {
            console.log("Peer already set on destination OApp", oapp, "for source", pathway.srcOApp);
        }
        
        // Set receive configurations
        setReceiveConfigurations(
            endpoint,
            oapp,
            deployment.receiveUln302.addr,
            pathway
        );
        
        vm.stopBroadcast();
    }

    /// @notice Set send configurations (ULN + Executor)
    function setSendConfigurations(
        ILayerZeroEndpointV2 endpoint,
        address oapp,
        address sendLib,
        PathwayConfig memory pathway,
        address executorAddr
    ) internal {
        // Configure ULN
        UlnConfig memory ulnConfig = UlnConfig({
            confirmations: pathway.confirmations,
            requiredDVNCount: pathway.requiredDVNCount,
            optionalDVNCount: uint8(pathway.srcOptionalDVNs.length),
            optionalDVNThreshold: pathway.optionalDVNThreshold,
            requiredDVNs: pathway.srcRequiredDVNs,
            optionalDVNs: pathway.srcOptionalDVNs
        });
        
        // Configure Executor
        ExecutorConfig memory execConfig = ExecutorConfig({
            maxMessageSize: pathway.maxMessageSize,
            executor: executorAddr
        });
        
        // Check current configurations
        SetConfigParam[] memory params = new SetConfigParam[](0);
        uint256 paramCount = 0;
        
        // Check executor config
        try endpoint.getConfig(oapp, sendLib, pathway.dstEid, EXECUTOR_CONFIG_TYPE) returns (bytes memory currentExecConfig) {
            if (currentExecConfig.length > 0) {
                ExecutorConfig memory currentExec = abi.decode(currentExecConfig, (ExecutorConfig));
                if (currentExec.maxMessageSize != execConfig.maxMessageSize || currentExec.executor != execConfig.executor) {
                    paramCount++;
                    console.log("Executor config needs update");
                } else {
                    console.log("Executor config already set correctly");
                }
            } else {
                paramCount++;
                console.log("Executor config not set");
            }
        } catch {
            paramCount++;
            console.log("Executor config not set");
        }
        
        // Check ULN config
        try endpoint.getConfig(oapp, sendLib, pathway.dstEid, ULN_CONFIG_TYPE) returns (bytes memory currentUlnConfig) {
            if (currentUlnConfig.length > 0) {
                UlnConfig memory currentUln = abi.decode(currentUlnConfig, (UlnConfig));
                if (!isUlnConfigEqual(currentUln, ulnConfig)) {
                    paramCount++;
                    console.log("ULN config needs update");
                } else {
                    console.log("ULN config already set correctly");
                }
            } else {
                paramCount++;
                console.log("ULN config not set");
            }
        } catch {
            paramCount++;
            console.log("ULN config not set");
        }
        
        // Only set configurations if needed
        if (paramCount > 0) {
            params = new SetConfigParam[](paramCount);
            uint256 paramIndex = 0;
            
            // Add executor config if needed
            try endpoint.getConfig(oapp, sendLib, pathway.dstEid, EXECUTOR_CONFIG_TYPE) returns (bytes memory currentExecConfig) {
                if (currentExecConfig.length == 0) {
                    params[paramIndex++] = SetConfigParam(pathway.dstEid, EXECUTOR_CONFIG_TYPE, abi.encode(execConfig));
                } else {
                    ExecutorConfig memory currentExec = abi.decode(currentExecConfig, (ExecutorConfig));
                    if (currentExec.maxMessageSize != execConfig.maxMessageSize || currentExec.executor != execConfig.executor) {
                        params[paramIndex++] = SetConfigParam(pathway.dstEid, EXECUTOR_CONFIG_TYPE, abi.encode(execConfig));
                    }
                }
            } catch {
                params[paramIndex++] = SetConfigParam(pathway.dstEid, EXECUTOR_CONFIG_TYPE, abi.encode(execConfig));
            }
            
            // Add ULN config if needed
            try endpoint.getConfig(oapp, sendLib, pathway.dstEid, ULN_CONFIG_TYPE) returns (bytes memory currentUlnConfig) {
                if (currentUlnConfig.length == 0) {
                    params[paramIndex++] = SetConfigParam(pathway.dstEid, ULN_CONFIG_TYPE, abi.encode(ulnConfig));
                } else {
                    UlnConfig memory currentUln = abi.decode(currentUlnConfig, (UlnConfig));
                    if (!isUlnConfigEqual(currentUln, ulnConfig)) {
                        params[paramIndex++] = SetConfigParam(pathway.dstEid, ULN_CONFIG_TYPE, abi.encode(ulnConfig));
                    }
                }
            } catch {
                params[paramIndex++] = SetConfigParam(pathway.dstEid, ULN_CONFIG_TYPE, abi.encode(ulnConfig));
            }
            
            // Set configurations
            endpoint.setConfig(oapp, sendLib, params);
            console.log("Set send configurations for destination EID:", pathway.dstEid);
        } else {
            console.log("Send configurations already set correctly for destination EID:", pathway.dstEid);
        }
    }

    /// @notice Set receive configurations (ULN only)
    function setReceiveConfigurations(
        ILayerZeroEndpointV2 endpoint,
        address oapp,
        address receiveLib,
        PathwayConfig memory pathway
    ) internal {
        // Configure ULN (same as send side)
        UlnConfig memory ulnConfig = UlnConfig({
            confirmations: pathway.confirmations,
            requiredDVNCount: pathway.requiredDVNCount,
            optionalDVNCount: uint8(pathway.dstOptionalDVNs.length),
            optionalDVNThreshold: pathway.optionalDVNThreshold,
            requiredDVNs: pathway.dstRequiredDVNs,
            optionalDVNs: pathway.dstOptionalDVNs
        });
        
        // Check current ULN config
        bool needsUpdate = false;
        try endpoint.getConfig(oapp, receiveLib, pathway.srcEid, ULN_CONFIG_TYPE) returns (bytes memory currentUlnConfig) {
            if (currentUlnConfig.length > 0) {
                UlnConfig memory currentUln = abi.decode(currentUlnConfig, (UlnConfig));
                if (!isUlnConfigEqual(currentUln, ulnConfig)) {
                    needsUpdate = true;
                    console.log("Receive ULN config needs update");
                } else {
                    console.log("Receive ULN config already set correctly");
                }
            } else {
                needsUpdate = true;
                console.log("Receive ULN config not set");
            }
        } catch {
            needsUpdate = true;
            console.log("Receive ULN config not set");
        }
        
        // Only set configuration if needed
        if (needsUpdate) {
            // Encode configuration
            bytes memory encodedUln = abi.encode(ulnConfig);
            
            // Create config params
            SetConfigParam[] memory params = new SetConfigParam[](1);
            params[0] = SetConfigParam(pathway.srcEid, ULN_CONFIG_TYPE, encodedUln);
            
            // Set configuration
            endpoint.setConfig(oapp, receiveLib, params);
            console.log("Set receive configurations for source EID:", pathway.srcEid);
        } else {
            console.log("Receive configurations already set correctly for source EID:", pathway.srcEid);
        }
    }

    /// @notice Set enforced options on the OApp
    function setEnforcedOptions(
        address oapp,
        uint32 dstEid,
        EnforcedOptions memory options
    ) internal {
        // Count how many options we actually need
        uint256 optionCount = 0;
        if (options.lzReceiveGas > 0) optionCount++;
        if (options.lzComposeGas > 0) optionCount++;
        
        if (optionCount == 0) {
            console.log("No enforced options to set for destination EID:", dstEid);
            return;
        }
        
        // Build expected options and check against current
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](0);
        uint256 paramsNeeded = 0;
        
        // Check standard message options
        if (options.lzReceiveGas > 0) {
            bytes memory expectedOptions = OptionsBuilder.newOptions()
                .addExecutorLzReceiveOption(options.lzReceiveGas, options.lzReceiveValue);
            
            // Add native drop if specified
            if (options.lzNativeDropAmount > 0 && options.lzNativeDropRecipient != address(0)) {
                expectedOptions = OptionsBuilder.addExecutorNativeDropOption(
                    expectedOptions,
                    options.lzNativeDropAmount,
                    bytes32(uint256(uint160(options.lzNativeDropRecipient)))
                );
            }
            
            bytes memory currentOptions = IOAppWithEnforcedOptions(oapp).enforcedOptions(dstEid, MSG_TYPE_STANDARD);
            if (!areOptionsEqual(currentOptions, expectedOptions)) {
                paramsNeeded++;
                console.log("Standard message enforced options need update");
            } else {
                console.log("Standard message enforced options already set correctly");
            }
        }
        
        // Check composed message options
        if (options.lzComposeGas > 0) {
            bytes memory expectedOptions = OptionsBuilder.newOptions()
                .addExecutorLzComposeOption(options.lzComposeIndex, options.lzComposeGas, 0);
            
            bytes memory currentOptions = IOAppWithEnforcedOptions(oapp).enforcedOptions(dstEid, MSG_TYPE_COMPOSED);
            if (!areOptionsEqual(currentOptions, expectedOptions)) {
                paramsNeeded++;
                console.log("Composed message enforced options need update");
            } else {
                console.log("Composed message enforced options already set correctly");
            }
        }
        
        if (paramsNeeded == 0) {
            console.log("Enforced options already set correctly for destination EID:", dstEid);
            return;
        }
        
        params = new EnforcedOptionParam[](paramsNeeded);
        uint256 paramIndex = 0;
        
        // Build options for standard message (msgType 1)
        if (options.lzReceiveGas > 0) {
            bytes memory expectedOptions = OptionsBuilder.newOptions()
                .addExecutorLzReceiveOption(options.lzReceiveGas, options.lzReceiveValue);
            
            // Add native drop if specified
            if (options.lzNativeDropAmount > 0 && options.lzNativeDropRecipient != address(0)) {
                expectedOptions = OptionsBuilder.addExecutorNativeDropOption(
                    expectedOptions,
                    options.lzNativeDropAmount,
                    bytes32(uint256(uint160(options.lzNativeDropRecipient)))
                );
            }
            
            bytes memory currentOptions = IOAppWithEnforcedOptions(oapp).enforcedOptions(dstEid, MSG_TYPE_STANDARD);
            if (!areOptionsEqual(currentOptions, expectedOptions)) {
                params[paramIndex] = EnforcedOptionParam({
                    eid: dstEid,
                    msgType: MSG_TYPE_STANDARD,
                    options: expectedOptions
                });
                paramIndex++;
            }
        }
        
        // Build options for composed message (msgType 2)
        if (options.lzComposeGas > 0) {
            bytes memory expectedOptions = OptionsBuilder.newOptions()
                .addExecutorLzComposeOption(options.lzComposeIndex, options.lzComposeGas, 0);
                
            bytes memory currentOptions = IOAppWithEnforcedOptions(oapp).enforcedOptions(dstEid, MSG_TYPE_COMPOSED);
            if (!areOptionsEqual(currentOptions, expectedOptions)) {
                params[paramIndex] = EnforcedOptionParam({
                    eid: dstEid,
                    msgType: MSG_TYPE_COMPOSED,
                    options: expectedOptions
                });
                paramIndex++;
            }
        }
        
        // Set enforced options on the OApp
        IOAppOptionsType3(oapp).setEnforcedOptions(params);
        console.log("Set enforced options for destination EID:", dstEid);
    }

    /// @notice Check if a pathway is fully configured
    function checkPathwayStatus(PathwayConfig memory pathway) internal {
        // Get deployments
        Deployment memory srcDeployment = deployments[pathway.srcEid];
        Deployment memory dstDeployment = deployments[pathway.dstEid];
        
        console.log("\n--- Configuration Status Check ---");
        console.log("Pathway:", pathway.srcEid, "->", pathway.dstEid);
        
        // Check source chain
        vm.createSelectFork(eidToRpc[pathway.srcEid]);
        ILayerZeroEndpointV2 srcEndpoint = ILayerZeroEndpointV2(srcDeployment.endpointV2.addr);
        
        address srcSendLib = srcEndpoint.getSendLibrary(pathway.srcOApp, pathway.dstEid);
        bytes32 srcPeer = IOAppCore(pathway.srcOApp).peers(pathway.dstEid);
        
        console.log("Source chain status:");
        console.log("  Send library set:", srcSendLib == srcDeployment.sendUln302.addr ? "YES" : "NO");
        console.log("  Peer set:", srcPeer == bytes32(uint256(uint160(pathway.dstOApp))) ? "YES" : "NO");
        
        // Check destination chain
        vm.createSelectFork(eidToRpc[pathway.dstEid]);
        ILayerZeroEndpointV2 dstEndpoint = ILayerZeroEndpointV2(dstDeployment.endpointV2.addr);
        
        (address dstReceiveLib, ) = dstEndpoint.getReceiveLibrary(pathway.dstOApp, pathway.srcEid);
        bytes32 dstPeer = IOAppCore(pathway.dstOApp).peers(pathway.srcEid);
        
        console.log("Destination chain status:");
        console.log("  Receive library set:", dstReceiveLib == dstDeployment.receiveUln302.addr ? "YES" : "NO");
        console.log("  Peer set:", dstPeer == bytes32(uint256(uint160(pathway.srcOApp))) ? "YES" : "NO");
        console.log("--- End Status Check ---\n");
    }

    /// @notice Helper function to extract substring
    function substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }
    
    /// @notice Compare two ULN configurations
    function isUlnConfigEqual(UlnConfig memory a, UlnConfig memory b) internal pure returns (bool) {
        // Compare basic fields
        if (a.confirmations != b.confirmations ||
            a.requiredDVNCount != b.requiredDVNCount ||
            a.optionalDVNCount != b.optionalDVNCount ||
            a.optionalDVNThreshold != b.optionalDVNThreshold) {
            return false;
        }
        
        // Compare required DVN arrays
        if (a.requiredDVNs.length != b.requiredDVNs.length) {
            return false;
        }
        for (uint256 i = 0; i < a.requiredDVNs.length; i++) {
            if (a.requiredDVNs[i] != b.requiredDVNs[i]) {
                return false;
            }
        }
        
        // Compare optional DVN arrays
        if (a.optionalDVNs.length != b.optionalDVNs.length) {
            return false;
        }
        for (uint256 i = 0; i < a.optionalDVNs.length; i++) {
            if (a.optionalDVNs[i] != b.optionalDVNs[i]) {
                return false;
            }
        }
        
        return true;
    }
    
    /// @notice Compare two bytes arrays for equality
    function areOptionsEqual(bytes memory a, bytes memory b) internal pure returns (bool) {
        if (a.length != b.length) {
            return false;
        }
        for (uint256 i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    /// @notice Wire only the source side of pathways
    /// @param configPath Path to JSON config file containing pathway configurations
    /// @param deploymentJsonPath Path to JSON file with LayerZero deployments
    /// @param dvnJsonPath Path to JSON file with LayerZero DVN metadata
    function runSourceOnly(string memory configPath, string memory deploymentJsonPath, string memory dvnJsonPath) external {
        runPartial(configPath, deploymentJsonPath, dvnJsonPath, true, false);
    }
    
    /// @notice Wire only the destination side of pathways
    /// @param configPath Path to JSON config file containing pathway configurations
    /// @param deploymentJsonPath Path to JSON file with LayerZero deployments
    /// @param dvnJsonPath Path to JSON file with LayerZero DVN metadata
    function runDestinationOnly(string memory configPath, string memory deploymentJsonPath, string memory dvnJsonPath) external {
        runPartial(configPath, deploymentJsonPath, dvnJsonPath, false, true);
    }
    
    /// @notice Partial wiring function
    /// @param configPath Path to JSON config file containing pathway configurations
    /// @param deploymentJsonPath Path to JSON file with LayerZero deployments
    /// @param dvnJsonPath Path to JSON file with LayerZero DVN metadata
    /// @param doSource Whether to wire source chains
    /// @param doDestination Whether to wire destination chains
    function runPartial(
        string memory configPath, 
        string memory deploymentJsonPath, 
        string memory dvnJsonPath,
        bool doSource,
        bool doDestination
    ) internal {
        // Get the private key from environment
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(deployerPrivateKey);
        console.log("Signer address from private key:", signer);
        
        if (doSource && doDestination) {
            console.log("WARNING: Wiring both source and destination in same run may cause nonce issues!");
        }
        
        // Read config JSON
        string memory configJson = vm.readFile(configPath);
        
        // Parse basic configuration and chain configs first
        bool bidirectional = vm.parseJsonBool(configJson, ".bidirectional");
        parseChainConfigs(configJson);
        parseDVNOverrides(configJson);
        
        // Parse LayerZero deployments (only for configured chains)
        parseDeployments(deploymentJsonPath);
        
        // Parse LayerZero DVN metadata
        parseDVNMetadata(dvnJsonPath);
        
        // Now parse pathways after DVN metadata is loaded
        PathwayConfig[] memory pathways = parsePathways(configJson, bidirectional);
        
        // Wire each pathway
        for (uint256 i = 0; i < pathways.length; i++) {
            wirePathwayPartial(pathways[i], doSource, doDestination);
        }
        
        if (doSource) {
            console.log("Successfully wired all source chains");
        }
        if (doDestination) {
            console.log("Successfully wired all destination chains");
        }
    }
    
    /// @notice Wire a pathway partially (source, destination, or both)
    function wirePathwayPartial(PathwayConfig memory pathway, bool doSource, bool doDestination) internal {
        // Get deployments
        Deployment memory srcDeployment = deployments[pathway.srcEid];
        Deployment memory dstDeployment = deployments[pathway.dstEid];
        
        require(srcDeployment.endpointV2.addr != address(0), "Source deployment not found");
        require(dstDeployment.endpointV2.addr != address(0), "Destination deployment not found");
        
        console.log("\n========================================");
        console.log("Wiring pathway (partial):");
        console.log("  From:", pathway.srcEid, "OApp:", pathway.srcOApp);
        console.log("  To:", pathway.dstEid, "OApp:", pathway.dstOApp);
        console.log("  Wiring source:", doSource);
        console.log("  Wiring destination:", doDestination);
        console.log("========================================\n");
        
        if (doSource) {
            // Wire source chain (setSendLibrary, setPeer, setEnforcedOptions and send configs for source OApp)
            console.log(">>> Configuring source chain...");
            wireSourceChain(
                pathway.srcOApp,
                pathway,
                srcDeployment,
                eidToRpc[pathway.srcEid]
            );
        }
        
        if (doDestination) {
            // Wire destination chain (setReceiveLibrary, setPeer and receive configs for destination OApp)
            console.log("\n>>> Configuring destination chain...");
            wireDestinationChain(
                pathway.dstOApp,
                pathway,
                dstDeployment,
                eidToRpc[pathway.dstEid]
            );
        }
        
        console.log("\n>>> Pathway configuration complete!");
    }
}
