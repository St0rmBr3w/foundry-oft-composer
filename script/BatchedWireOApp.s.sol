// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./WireOApp.s.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {IOAppOptionsType3, EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/// @title Batched LayerZero OApp Wire Script
/// @notice Solves nonce mismatch issues with --multi flag by batching transactions per chain
/// @dev Collects all transactions in Phase 1, then broadcasts by chain in Phase 2
contract BatchedWireOApp is WireOApp {
    using OptionsBuilder for bytes;
    
    // ============================================
    // TRANSACTION CACHING STRUCTURES
    // ============================================
    
    struct CachedTransaction {
        address target;
        bytes data;
        uint256 value;
        string description; // For logging what the transaction does
    }
    
    // Storage for cached transactions organized by chain EID
    mapping(uint32 => CachedTransaction[]) private transactionsByChain;
    
    // Track which chains have transactions
    uint32[] private chainsWithTransactions;
    mapping(uint32 => bool) private chainHasTransactions;
    
    // Control whether we're in caching mode
    bool private isCaching;
    
    // Track current chain context during caching
    uint32 private currentChainEid;
    
    // ============================================
    // MAIN ENTRY POINTS (OVERRIDE)
    // ============================================
    
    /// @notice Main function to wire all pathways with batching
    /// @param configPath Path to JSON config file containing pathway configurations
    function run(string memory configPath) external override {
        runWithSources(configPath, "", "");
    }
    
    /// @notice Wire pathways with specific deployment and DVN sources
    function run(string memory configPath, string memory deploymentSource, string memory dvnSource) external override {
        runWithSources(configPath, deploymentSource, dvnSource);
    }
    
    /// @notice Wire only source chains with batching
    function runSourceOnly(string memory configPath) external override {
        runPartialBatched(configPath, "", "", true, false);
    }
    
    /// @notice Wire only destination chains with batching
    function runDestinationOnly(string memory configPath) external override {
        runPartialBatched(configPath, "", "", false, true);
    }
    
    /// @notice Main batched wiring function
    function runWithSources(string memory configPath, string memory deploymentSource, string memory dvnSource) 
        public 
        override 
    {
        // Phase 1: Initialize and collect transactions
        isCaching = true;
        
        // Get the private key from environment
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(deployerPrivateKey);

        // Check if we're in check-only mode
        bool checkOnly = vm.envOr("CHECK_ONLY", false);

        // Print header
        printHeader("LAYERZERO BATCHED WIRE SCRIPT");
        console.log(string.concat("  Signer: ", shortAddress(signer)));
        console.log(string.concat("  Mode:   ", checkOnly ? "CHECK ONLY" : "CONFIGURE (BATCHED)"));

        // Read config JSON
        string memory configJson = vm.readFile(configPath);

        // Parse basic configuration and chain configs first
        bool bidirectional = vm.parseJsonBool(configJson, ".bidirectional");
        parseChainConfigs(configJson);
        parseDVNOverrides(configJson);
        
        // Handle deployment and DVN sources
        string memory deploymentsSource = deploymentSource;
        string memory dvnsSource = dvnSource;
        
        if (bytes(deploymentsSource).length == 0) {
            try vm.parseJsonString(configJson, ".deploymentsSource") returns (string memory configDeploymentSource) {
                deploymentsSource = configDeploymentSource;
            } catch {
                deploymentsSource = DEFAULT_DEPLOYMENTS_API;
            }
        }
        
        if (bytes(dvnsSource).length == 0) {
            try vm.parseJsonString(configJson, ".dvnsSource") returns (string memory configDvnSource) {
                dvnsSource = configDvnSource;
            } catch {
                dvnsSource = DEFAULT_DVNS_API;
            }
        }

        // Parse deployments and DVN metadata
        console.log("\n  Loading deployments...");
        parseDeployments(deploymentsSource);
        console.log("  Loading DVN metadata...");
        parseDVNMetadata(dvnsSource);

        // Parse pathways
        PathwayConfig[] memory pathways = parsePathways(configJson, bidirectional);

        // Pre-flight check
        uint256 needsConfig = preflightCheck(pathways);

        if (checkOnly) {
            console.log("\n  Check complete. Exiting.");
            return;
        }

        if (needsConfig == 0) {
            return;
        }

        // Collect transactions for pathways that need configuration
        printSubHeader("Phase 1: Collecting Transactions");
        uint256 pathwaysToWire = 0;

        for (uint256 i = 0; i < pathways.length; i++) {
            if (!isPathwayConfigured(pathways[i])) {
                pathwaysToWire++;
                console.log(
                    string.concat(
                        "\n[", vm.toString(pathwaysToWire), "/", vm.toString(needsConfig), "] Collecting transactions for pathway"
                    )
                );
                // This will cache transactions instead of broadcasting
                wirePathway(pathways[i]);
            }
        }
        
        // Phase 2: Broadcast by chain
        isCaching = false;
        printSubHeader("Phase 2: Broadcasting by Chain");
        broadcastByChain();
        
        printHeader("CONFIGURATION COMPLETE");
        printSuccess(string.concat("Successfully configured ", vm.toString(pathwaysToWire), " pathways"));
    }
    
    /// @notice Partial wiring with batching
    function runPartialBatched(
        string memory configPath,
        string memory deploymentSource,
        string memory dvnSource,
        bool doSource,
        bool doDestination
    ) internal {
        // Phase 1: Initialize and collect transactions
        isCaching = true;
        
        // Get the private key from environment
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(deployerPrivateKey);
        
        console.log("Batched partial wiring mode");
        console.log("Signer address from private key:", signer);
        console.log("Wiring source:", doSource);
        console.log("Wiring destination:", doDestination);

        // Read and parse config
        string memory configJson = vm.readFile(configPath);
        bool bidirectional = vm.parseJsonBool(configJson, ".bidirectional");
        parseChainConfigs(configJson);
        parseDVNOverrides(configJson);
        
        // Handle deployment and DVN sources
        string memory deploymentsSource = deploymentSource;
        string memory dvnsSource = dvnSource;
        
        if (bytes(deploymentsSource).length == 0) {
            try vm.parseJsonString(configJson, ".deploymentsSource") returns (string memory configDeploymentSource) {
                deploymentsSource = configDeploymentSource;
            } catch {
                deploymentsSource = DEFAULT_DEPLOYMENTS_API;
            }
        }
        
        if (bytes(dvnsSource).length == 0) {
            try vm.parseJsonString(configJson, ".dvnsSource") returns (string memory configDvnSource) {
                dvnsSource = configDvnSource;
            } catch {
                dvnsSource = DEFAULT_DVNS_API;
            }
        }
        
        // Parse deployments and DVN metadata
        parseDeployments(deploymentsSource);
        parseDVNMetadata(dvnsSource);

        // Parse pathways
        PathwayConfig[] memory pathways = parsePathways(configJson, bidirectional);
        
        // Collect transactions for each pathway
        for (uint256 i = 0; i < pathways.length; i++) {
            wirePathwayPartial(pathways[i], doSource, doDestination);
        }
        
        // Phase 2: Broadcast by chain
        isCaching = false;
        printSubHeader("Broadcasting by Chain");
        broadcastByChain();
        
        if (doSource) {
            console.log("Successfully wired all source chains");
        }
        if (doDestination) {
            console.log("Successfully wired all destination chains");
        }
    }
    
    // ============================================
    // OVERRIDE WIRE FUNCTIONS TO CACHE
    // ============================================
    
    /// @notice Override wireSourceChain to cache transactions instead of broadcasting
    function wireSourceChain(
        address oapp,
        PathwayConfig memory pathway,
        Deployment memory deployment,
        string memory rpcUrl
    ) internal override {
        if (!isCaching) {
            // If not caching, use parent implementation
            super.wireSourceChain(oapp, pathway, deployment, rpcUrl);
            return;
        }
        
        // Set current chain context
        currentChainEid = pathway.srcEid;
        
        // Track this chain
        if (!chainHasTransactions[currentChainEid]) {
            chainHasTransactions[currentChainEid] = true;
            chainsWithTransactions.push(currentChainEid);
        }
        
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(deployment.endpointV2.addr);
        
        // Check and cache setSendLibrary if needed
        vm.createSelectFork(rpcUrl); // We still need to fork to check current state
        address currentSendLib = endpoint.getSendLibrary(oapp, pathway.dstEid);
        if (currentSendLib != deployment.sendUln302.addr) {
            cacheTransaction(
                deployment.endpointV2.addr,
                abi.encodeWithSelector(
                    endpoint.setSendLibrary.selector,
                    oapp,
                    pathway.dstEid,
                    deployment.sendUln302.addr
                ),
                0,
                "setSendLibrary"
            );
        }
        
        // Check and cache setPeer if needed
        bytes32 expectedPeer = bytes32(uint256(uint160(pathway.dstOApp)));
        bytes32 currentPeer = IOAppCore(oapp).peers(pathway.dstEid);
        if (currentPeer != expectedPeer) {
            cacheTransaction(
                oapp,
                abi.encodeWithSelector(
                    IOAppCore.setPeer.selector,
                    pathway.dstEid,
                    expectedPeer
                ),
                0,
                "setPeer"
            );
        }
        
        // Cache setEnforcedOptions if needed
        cacheEnforcedOptions(oapp, pathway.dstEid, pathway.enforcedOptions);
        
        // Cache send configurations
        cacheSendConfigurations(endpoint, oapp, deployment.sendUln302.addr, pathway, deployment.executor.addr);
    }
    
    /// @notice Override wireDestinationChain to cache transactions instead of broadcasting
    function wireDestinationChain(
        address oapp,
        PathwayConfig memory pathway,
        Deployment memory deployment,
        string memory rpcUrl
    ) internal override {
        if (!isCaching) {
            // If not caching, use parent implementation
            super.wireDestinationChain(oapp, pathway, deployment, rpcUrl);
            return;
        }
        
        // Set current chain context
        currentChainEid = pathway.dstEid;
        
        // Track this chain
        if (!chainHasTransactions[currentChainEid]) {
            chainHasTransactions[currentChainEid] = true;
            chainsWithTransactions.push(currentChainEid);
        }
        
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(deployment.endpointV2.addr);
        
        // Check and cache setReceiveLibrary if needed
        vm.createSelectFork(rpcUrl); // We still need to fork to check current state
        (address currentReceiveLib,) = endpoint.getReceiveLibrary(oapp, pathway.srcEid);
        if (currentReceiveLib != deployment.receiveUln302.addr) {
            cacheTransaction(
                deployment.endpointV2.addr,
                abi.encodeWithSelector(
                    endpoint.setReceiveLibrary.selector,
                    oapp,
                    pathway.srcEid,
                    deployment.receiveUln302.addr,
                    0
                ),
                0,
                "setReceiveLibrary"
            );
        }
        
        // Check and cache setPeer if needed
        bytes32 expectedPeer = bytes32(uint256(uint160(pathway.srcOApp)));
        bytes32 currentPeer = IOAppCore(oapp).peers(pathway.srcEid);
        if (currentPeer != expectedPeer) {
            cacheTransaction(
                oapp,
                abi.encodeWithSelector(
                    IOAppCore.setPeer.selector,
                    pathway.srcEid,
                    expectedPeer
                ),
                0,
                "setPeer"
            );
        }
        
        // Cache receive configurations
        cacheReceiveConfigurations(endpoint, oapp, deployment.receiveUln302.addr, pathway);
    }
    
    // ============================================
    // CACHING HELPER FUNCTIONS
    // ============================================
    
    /// @notice Cache a transaction for later execution
    function cacheTransaction(
        address target,
        bytes memory data,
        uint256 value,
        string memory description
    ) internal {
        transactionsByChain[currentChainEid].push(CachedTransaction({
            target: target,
            data: data,
            value: value,
            description: description
        }));
        
        console.log(string.concat("    Cached: ", description));
    }
    
    /// @notice Cache enforced options if needed
    function cacheEnforcedOptions(address oapp, uint32 dstEid, EnforcedOptions[] memory options) internal {
        if (options.length == 0) {
            return;
        }

        // Build enforced option params for each message type
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](options.length);
        uint256 paramsNeeded = 0;

        for (uint256 i = 0; i < options.length; i++) {
            EnforcedOptions memory opt = options[i];

            // Build expected options based on what's actually set
            bytes memory expectedOptions = OptionsBuilder.newOptions();

            // Add lzReceive option if gas is specified
            if (opt.lzReceiveGas > 0) {
                expectedOptions =
                    OptionsBuilder.addExecutorLzReceiveOption(expectedOptions, opt.lzReceiveGas, opt.lzReceiveValue);
            }

            // Add lzCompose option if gas is specified
            if (opt.lzComposeGas > 0) {
                expectedOptions =
                    OptionsBuilder.addExecutorLzComposeOption(expectedOptions, opt.lzComposeIndex, opt.lzComposeGas, 0);
            }

            // Add native drop if specified
            if (opt.lzNativeDropAmount > 0 && opt.lzNativeDropRecipient != address(0)) {
                expectedOptions = OptionsBuilder.addExecutorNativeDropOption(
                    expectedOptions, opt.lzNativeDropAmount, bytes32(uint256(uint160(opt.lzNativeDropRecipient)))
                );
            }

            // Skip if no options were actually added
            if (expectedOptions.length == 1) {
                continue;
            }

            bytes memory currentOptions = IOAppWithEnforcedOptions(oapp).enforcedOptions(dstEid, opt.msgType);
            if (!areOptionsEqual(currentOptions, expectedOptions)) {
                params[paramsNeeded] =
                    EnforcedOptionParam({eid: dstEid, msgType: opt.msgType, options: expectedOptions});
                paramsNeeded++;
            }
        }

        if (paramsNeeded == 0) {
            return;
        }

        // Resize params array to actual size needed
        if (paramsNeeded < params.length) {
            EnforcedOptionParam[] memory resizedParams = new EnforcedOptionParam[](paramsNeeded);
            for (uint256 i = 0; i < paramsNeeded; i++) {
                resizedParams[i] = params[i];
            }
            params = resizedParams;
        }

        // Cache the transaction
        cacheTransaction(
            oapp,
            abi.encodeWithSelector(
                IOAppOptionsType3.setEnforcedOptions.selector,
                params
            ),
            0,
            "setEnforcedOptions"
        );
    }
    
    /// @notice Cache send configurations if needed
    function cacheSendConfigurations(
        ILayerZeroEndpointV2 endpoint,
        address oapp,
        address sendLib,
        PathwayConfig memory pathway,
        address executor
    ) internal {
        SetConfigParam[] memory params = new SetConfigParam[](2);
        uint256 paramsNeeded = 0;
        
        // Check ULN config
        UlnConfig memory ulnConfig = UlnConfig({
            confirmations: pathway.confirmations,
            requiredDVNCount: pathway.requiredDVNCount,
            optionalDVNCount: uint8(pathway.srcOptionalDVNs.length),
            optionalDVNThreshold: pathway.optionalDVNThreshold,
            requiredDVNs: pathway.srcRequiredDVNs,
            optionalDVNs: pathway.srcOptionalDVNs
        });
        
        bool needsUlnUpdate = false;
        try endpoint.getConfig(oapp, sendLib, pathway.dstEid, ULN_CONFIG_TYPE) returns (bytes memory currentUlnConfig) {
            if (currentUlnConfig.length > 0) {
                UlnConfig memory currentUln = abi.decode(currentUlnConfig, (UlnConfig));
                if (!isUlnConfigEqual(currentUln, ulnConfig)) {
                    needsUlnUpdate = true;
                }
            } else {
                needsUlnUpdate = true;
            }
        } catch {
            needsUlnUpdate = true;
        }
        
        if (needsUlnUpdate) {
            bytes memory encodedUln = abi.encode(ulnConfig);
            params[paramsNeeded] = SetConfigParam(pathway.dstEid, ULN_CONFIG_TYPE, encodedUln);
            paramsNeeded++;
        }
        
        // Check Executor config
        ExecutorConfig memory execConfig = ExecutorConfig({
            maxMessageSize: pathway.maxMessageSize,
            executor: executor
        });
        
        bool needsExecUpdate = false;
        try endpoint.getConfig(oapp, sendLib, pathway.dstEid, EXECUTOR_CONFIG_TYPE) returns (bytes memory currentExecConfig) {
            if (currentExecConfig.length > 0) {
                ExecutorConfig memory currentExec = abi.decode(currentExecConfig, (ExecutorConfig));
                if (currentExec.maxMessageSize != execConfig.maxMessageSize || currentExec.executor != execConfig.executor) {
                    needsExecUpdate = true;
                }
            } else {
                needsExecUpdate = true;
            }
        } catch {
            needsExecUpdate = true;
        }
        
        if (needsExecUpdate) {
            bytes memory encodedExec = abi.encode(execConfig);
            params[paramsNeeded] = SetConfigParam(pathway.dstEid, EXECUTOR_CONFIG_TYPE, encodedExec);
            paramsNeeded++;
        }
        
        if (paramsNeeded == 0) {
            return;
        }
        
        // Resize params array
        if (paramsNeeded < params.length) {
            SetConfigParam[] memory resizedParams = new SetConfigParam[](paramsNeeded);
            for (uint256 i = 0; i < paramsNeeded; i++) {
                resizedParams[i] = params[i];
            }
            params = resizedParams;
        }
        
        // Cache the transaction
        cacheTransaction(
            address(endpoint),
            abi.encodeWithSelector(
                endpoint.setConfig.selector,
                oapp,
                sendLib,
                params
            ),
            0,
            "setSendConfig"
        );
    }
    
    /// @notice Cache receive configurations if needed
    function cacheReceiveConfigurations(
        ILayerZeroEndpointV2 endpoint,
        address oapp,
        address receiveLib,
        PathwayConfig memory pathway
    ) internal {
        // Configure ULN
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
        try endpoint.getConfig(oapp, receiveLib, pathway.srcEid, ULN_CONFIG_TYPE) returns (
            bytes memory currentUlnConfig
        ) {
            if (currentUlnConfig.length > 0) {
                UlnConfig memory currentUln = abi.decode(currentUlnConfig, (UlnConfig));
                if (!isUlnConfigEqual(currentUln, ulnConfig)) {
                    needsUpdate = true;
                }
            } else {
                needsUpdate = true;
            }
        } catch {
            needsUpdate = true;
        }

        if (!needsUpdate) {
            return;
        }

        // Encode configuration
        bytes memory encodedUln = abi.encode(ulnConfig);

        // Create config params
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(pathway.srcEid, ULN_CONFIG_TYPE, encodedUln);

        // Cache the transaction
        cacheTransaction(
            address(endpoint),
            abi.encodeWithSelector(
                endpoint.setConfig.selector,
                oapp,
                receiveLib,
                params
            ),
            0,
            "setReceiveConfig"
        );
    }
    
    // ============================================
    // BROADCAST BY CHAIN
    // ============================================
    
    /// @notice Broadcast all cached transactions organized by chain
    function broadcastByChain() internal {
        console.log(string.concat("\n  Total chains with transactions: ", vm.toString(chainsWithTransactions.length)));
        
        for (uint256 i = 0; i < chainsWithTransactions.length; i++) {
            uint32 eid = chainsWithTransactions[i];
            CachedTransaction[] storage chainTxs = transactionsByChain[eid];
            
            if (chainTxs.length == 0) {
                continue;
            }
            
            console.log("");
            console.log(string.concat("  Broadcasting for ", chainName(eid), " (EID: ", vm.toString(eid), ")"));
            console.log(string.concat("    Transactions to broadcast: ", vm.toString(chainTxs.length)));
            
            // Switch to the chain
            vm.createSelectFork(eidToRpc[eid]);
            
            // Start broadcast
            vm.startBroadcast(deployerPrivateKey);
            
            // Execute all transactions for this chain
            for (uint256 j = 0; j < chainTxs.length; j++) {
                CachedTransaction memory cachedTx = chainTxs[j];
                console.log(string.concat("    [", vm.toString(j + 1), "/", vm.toString(chainTxs.length), "] ", cachedTx.description));
                
                // Execute the transaction
                (bool success,) = cachedTx.target.call{value: cachedTx.value}(cachedTx.data);
                require(success, string.concat("Transaction failed: ", cachedTx.description));
            }
            
            vm.stopBroadcast();
            
            printSuccess(string.concat("  Completed ", vm.toString(chainTxs.length), " transactions on ", chainName(eid)));
        }
        
        // Clear cached transactions
        for (uint256 i = 0; i < chainsWithTransactions.length; i++) {
            delete transactionsByChain[chainsWithTransactions[i]];
        }
        delete chainsWithTransactions;
    }
} 