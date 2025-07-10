# Nonce mismatch errors when script switches between chains with --multi flag

## Problem Description

When using the `--multi` flag with Foundry scripts that switch between chains multiple times, we encounter consistent nonce mismatch errors:

```
Error: 
Simulated transaction results do not match on-chain transaction results.
```

This issue occurs even though PR #6271 made sequences execute sequentially. The problem specifically affects scripts that configure cross-chain protocols (LayerZero, Chainlink CCIP, etc.) which require interleaved transactions across multiple chains.

## Root Cause

Scripts that configure cross-chain protocols need to switch between chains within the same execution flow. For example, configuring a LayerZero pathway from Chain A to Chain B requires:

1. Transactions on Chain A (set send library, peer, configurations)
2. Transactions on Chain B (set receive library, peer, configurations)

When configuring multiple pathways, the script may need to return to Chain A for another pathway:

```
Pathway 1: A→B
- Fork to Chain A, broadcast transactions
- Fork to Chain B, broadcast transactions

Pathway 2: A→C  
- Fork to Chain A again, broadcast transactions  // ← This creates a new sequence with nonce issues
- Fork to Chain C, broadcast transactions
```

Foundry creates separate broadcast sequences each time `vm.createSelectFork` is called, resulting in multiple sequences for the same chain with incorrect nonce ordering.

## Minimal Reproduction

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

contract MultiChainScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Configure pathway 1: A→B
        vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // Transaction 1 on Chain A (nonce 0)
        console.log("Transaction on Chain A for pathway A->B");
        vm.stopBroadcast();
        
        vm.createSelectFork("https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // Transaction 1 on Chain B
        console.log("Transaction on Chain B for pathway A->B");
        vm.stopBroadcast();
        
        // Configure pathway 2: A→C
        vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"); // Back to Chain A
        vm.startBroadcast(deployerPrivateKey);
        // Transaction 2 on Chain A (should be nonce 1, but new sequence starts at 0)
        console.log("Transaction on Chain A for pathway A->C");
        vm.stopBroadcast();
        
        vm.createSelectFork("https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // Transaction 1 on Chain C
        console.log("Transaction on Chain C for pathway A->C");
        vm.stopBroadcast();
    }
}
```

Running this with `--multi` will fail with nonce mismatch errors.

## Expected Behavior

One of the following:

1. **Automatic nonce tracking**: Foundry should track nonces across fork switches to the same chain and maintain proper nonce continuity
2. **Transaction batching API**: Provide a way for scripts to batch transactions by chain before broadcasting
3. **Manual sequence management**: Allow scripts to manually manage broadcast sequences

## Actual Behavior

- Nonce mismatch errors when the script is run with `--multi`
- Each `vm.createSelectFork` creates a new broadcast sequence
- Multiple sequences for the same chain have conflicting nonces
- The script fails even though the transaction order is deterministic

## Suggested Solutions

### Option 1: Track nonces across fork switches
Foundry could maintain nonce state per chain across fork switches:
```solidity
// Foundry internally tracks: chainId => address => nonce
// When switching back to a chain, continue from the last nonce
```

### Option 2: Transaction batching API
Provide new cheatcodes for batching:
```solidity
vm.startBatching();
// ... switch between chains and queue transactions ...
vm.executeBatchByChain(); // Executes all transactions grouped by chain
```

### Option 3: Manual broadcast sequence control
Allow explicit sequence management:
```solidity
vm.createOrResumeBroadcastSequence(chainId, sequenceName);
```

## Current Workarounds

1. **Run without `--multi`**: Works but loses multi-chain deployment benefits
2. **Separate scripts per chain**: Requires significant refactoring and loses atomicity
3. **Custom batching**: Implement transaction caching manually (complex)

## Environment

- **Foundry version**: forge 0.2.0 (or current version)
- **OS**: macOS (darwin 24.5.0)
- **Affected scripts**: Cross-chain protocol configurations (LayerZero, Chainlink CCIP, etc.)

## Additional Context

- This issue is blocking for teams building cross-chain infrastructure
- PR #6271 improved sequential execution but didn't address the multiple-sequences-per-chain issue
- Many cross-chain protocols require interleaved transactions that can't be easily separated
- The issue only occurs with `--multi` flag; single-chain execution works fine

## Example Real-World Impact

When configuring LayerZero OApps across 5 chains with full mesh connectivity (20 pathways), the script needs to:
- Execute 4 transactions on each chain (80 total)
- Switch between chains 40 times
- Each chain is visited 8 times

This creates 8 separate broadcast sequences per chain, all starting at nonce 0, causing immediate failures.

## References

- Related PR: #6271 (Sequential execution of sequences)
- Related issues: [List any related issues]
- Example affected repository: [Link to example repo demonstrating the issue] 