# Batched Wire OApp Script

> **Scope:** detailed usage & internals of `BatchedWireOApp.s.sol` only. For installation, deployment, and sending tokens see the root [`README.md`](../README.md).

This script solves nonce mismatch issues when using Foundry's `--multi` flag with cross-chain configurations.

## How It Works

The BatchedWireOApp script implements a two-phase approach:

1. **Phase 1: Transaction Collection** - Collects all required transactions without broadcasting, organizing them by chain
2. **Phase 2: Batched Broadcasting** - Executes all transactions for each chain in a single broadcast session

This ensures proper nonce ordering and eliminates the conflicts that occur when switching between chains multiple times.

## Usage

### Basic Command (Using API endpoints)

```bash
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
    -s "run(string)" \
    "./utils/layerzero.config.json" \
    --broadcast --multi --via-ir --ffi
```

### With Local Files

```bash
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
    -s "run(string,string,string)" \
    "./utils/layerzero.config.json" \
    "./layerzero-deployments.json" \
    "./layerzero-dvns.json" \
    --broadcast --multi --via-ir
```

### Source Chains Only

```bash
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
    -s "runSourceOnly(string)" \
    "./utils/layerzero.config.json" \
    --broadcast --multi --via-ir --ffi
```

### Destination Chains Only

```bash
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
    -s "runDestinationOnly(string)" \
    "./utils/layerzero.config.json" \
    --broadcast --multi --via-ir --ffi
```

## Key Features

1. **Nonce Management**: All transactions for a chain are executed in a single broadcast sequence
2. **Same Configuration**: Uses the exact same configuration files as WireOApp
3. **Full Compatibility**: Supports all the same function signatures as WireOApp
4. **Efficient Execution**: Works seamlessly with `--multi` flag for parallel chain execution

## Example Output

```
================================================================================
                        LAYERZERO BATCHED WIRE SCRIPT
================================================================================
  Signer: 0x1234...5678
  Mode:   CONFIGURE (BATCHED)

  Loading deployments...
  Loading DVN metadata...

  Analyzing configuration status...

  Configuration Summary:
    Total pathways:      4
    Already configured:  0
    To be configured:    4

--------------------------------------------------------------------------------
                        Phase 1: Collecting Transactions
--------------------------------------------------------------------------------

[1/4] Collecting transactions for pathway
  ethereum (30101) --> arbitrum (30110)
  Source OApp: 0xaaaa...bbbb
  Dest OApp:   0xcccc...dddd
    Cached: setSendLibrary
    Cached: setPeer
    Cached: setEnforcedOptions
    Cached: setSendConfig
    Cached: setReceiveLibrary
    Cached: setPeer
    Cached: setReceiveConfig

[2/4] Collecting transactions for pathway
  ethereum (30101) --> base (30184)
  ...

--------------------------------------------------------------------------------
                        Phase 2: Broadcasting by Chain
--------------------------------------------------------------------------------

  Total chains with transactions: 3

  Broadcasting for ethereum (EID: 30101)
    Transactions to broadcast: 8
    [1/8] setSendLibrary
    [2/8] setPeer
    [3/8] setEnforcedOptions
    [4/8] setSendConfig
    [5/8] setSendLibrary
    [6/8] setPeer
    [7/8] setEnforcedOptions
    [8/8] setSendConfig
  ✓ Completed 8 transactions on ethereum

  Broadcasting for arbitrum (EID: 30110)
    Transactions to broadcast: 4
    [1/4] setReceiveLibrary
    [2/4] setPeer
    [3/4] setReceiveConfig
    [4/4] setReceiveLibrary
  ✓ Completed 4 transactions on arbitrum

  Broadcasting for base (EID: 30184)
    Transactions to broadcast: 4
    [1/4] setReceiveLibrary
    [2/4] setPeer
    [3/4] setReceiveConfig
    [4/4] setReceiveLibrary
  ✓ Completed 4 transactions on base

================================================================================
                        CONFIGURATION COMPLETE
================================================================================
✓ Successfully configured 4 pathways
```

## Environment Variables

```bash
# Required
export PRIVATE_KEY=your_private_key_here

# Optional
export CHECK_ONLY=true  # Run in check-only mode
export VERBOSE=true     # Show detailed configuration differences
```

## Important Flags

- `--broadcast`: Execute transactions on-chain
- `--multi`: Enable multi-chain execution (this is where the batching helps)
- `--via-ir`: **REQUIRED** - Enable Solidity IR optimizer to handle complex contract compilation
- `--ffi`: Enable FFI for API calls (required when using default API endpoints)
- `--slow`: (Optional) Add delays between transactions

## When to Use BatchedWireOApp

Use this script when:
- You need to configure multiple pathways across multiple chains
- You want to use the `--multi` flag for efficiency
- You're experiencing nonce mismatch errors with the regular WireOApp script

The script is fully compatible with WireOApp configurations, so you can switch between them without changing your config files.

## Alternative Solutions

If you prefer not to use the batched approach, you can:

1. **Use Partial Wiring** with regular WireOApp:
   ```bash
   # First wire source chains, then destination chains
   forge script script/WireOApp.s.sol:WireOApp -s "runSourceOnly(string)" ...
   forge script script/WireOApp.s.sol:WireOApp -s "runDestinationOnly(string)" ...
   ```

2. **Run without --multi flag** (slower but simpler)

3. **Use chain-specific configurations** (more manual work)

## Technical Details

The script works by:
- Overriding the `wireSourceChain` and `wireDestinationChain` functions
- Caching transactions instead of broadcasting them immediately
- Grouping all cached transactions by chain EID
- Broadcasting all transactions for each chain in a single session

This approach ensures that each chain maintains proper nonce ordering, even when the configuration logic needs to switch between chains multiple times. 