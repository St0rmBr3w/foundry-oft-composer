# Fixing Gas Pricing and RPC Timeout Issues

## Common Issues and Solutions

### 1. Transaction Underpricing Errors

This typically happens when gas prices spike between simulation and execution, or when using outdated gas price estimates.

#### Solution A: Use Forge's Gas Pricing Flags

```bash
# Add gas pricing flags to your command
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
    -s "run(string)" \
    "./utils/layerzero.config.json" \
    --broadcast --multi --via-ir --ffi \
    --with-gas-price 50gwei \
    --priority-gas-price 2gwei
```

#### Solution B: Use Dynamic Gas Pricing

```bash
# Let Forge handle gas pricing with a multiplier
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
    -s "run(string)" \
    "./utils/layerzero.config.json" \
    --broadcast --multi --via-ir --ffi \
    --gas-price-multiplier 120  # 20% buffer
```

#### Solution C: Chain-Specific Gas Settings

For chains with different gas models:

```bash
# For Polygon/BSC (legacy gas pricing)
--legacy

# For L2s with custom gas logic
--skip-simulation  # Skip simulation if it's causing issues
```

### 2. RPC Timeout Errors

RPC timeouts occur when:
- The RPC endpoint is overloaded
- Rate limits are exceeded
- Network requests take too long

#### Solution A: Use Premium RPC Endpoints

Update your configuration with better RPC endpoints:

```json
{
  "chains": {
    "ethereum": {
      "rpc": "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY",
      // Alternative premium providers:
      // "rpc": "https://mainnet.infura.io/v3/YOUR_KEY",
      // "rpc": "https://ethereum.publicnode.com",
      // "rpc": "https://rpc.ankr.com/eth/YOUR_KEY"
    },
    "arbitrum": {
      "rpc": "https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY",
      // Alternatives:
      // "rpc": "https://arbitrum-mainnet.infura.io/v3/YOUR_KEY",
      // "rpc": "https://arb1.arbitrum.io/rpc"
    },
    "base": {
      "rpc": "https://base-mainnet.g.alchemy.com/v2/YOUR_KEY",
      // Alternatives:
      // "rpc": "https://mainnet.base.org",
      // "rpc": "https://base.publicnode.com"
    }
  }
}
```

#### Solution B: Add Retry Logic and Delays

```bash
# Add delays between transactions
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
    -s "run(string)" \
    "./utils/layerzero.config.json" \
    --broadcast --multi --via-ir --ffi \
    --slow  # Adds delays between transactions
```

#### Solution C: Use Etherscan API for Gas Prices

```bash
# Set etherscan API keys for better gas estimation
export ETHERSCAN_API_KEY=your_key
export ARBISCAN_API_KEY=your_key
export BASESCAN_API_KEY=your_key

# Forge will use these for gas price estimation
```

### 3. Complete Command with All Fixes

Here's a robust command that handles most issues:

```bash
# For mainnet deployment with gas and RPC optimizations
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
    -s "run(string)" \
    "./utils/layerzero.config.json" \
    --broadcast \
    --multi \
    --via-ir \
    --ffi \
    --slow \
    --gas-price-multiplier 120 \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvv  # Verbose output for debugging
```

### 4. Environment Variables Setup

Create a `.env` file with all necessary configurations:

```bash
# Private key
PRIVATE_KEY=0xYOUR_PRIVATE_KEY

# RPC URLs with premium endpoints
ETHEREUM_RPC=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
ARBITRUM_RPC=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
BASE_RPC=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
OPTIMISM_RPC=https://opt-mainnet.g.alchemy.com/v2/YOUR_KEY
POLYGON_RPC=https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY

# Etherscan API keys for gas estimation
ETHERSCAN_API_KEY=YOUR_KEY
ARBISCAN_API_KEY=YOUR_KEY
BASESCAN_API_KEY=YOUR_KEY
OPTIMISTIC_ETHERSCAN_API_KEY=YOUR_KEY
POLYGONSCAN_API_KEY=YOUR_KEY

# Optional: Custom gas settings per chain
ETHEREUM_GAS_PRICE=50gwei
ARBITRUM_GAS_PRICE=0.1gwei
BASE_GAS_PRICE=0.01gwei
```

### 5. Manual Gas Price Override

If automatic gas pricing fails, manually set gas prices:

```bash
# Check current gas prices
cast gas-price --rpc-url $ETHEREUM_RPC

# Use specific gas price
forge script ... --with-gas-price 30gwei
```

### 6. Handling Specific Chain Issues

#### Arbitrum
```bash
# Arbitrum has unique gas estimation
forge script ... --skip-simulation
```

#### Polygon
```bash
# Polygon often needs higher gas prices
forge script ... --with-gas-price 100gwei --legacy
```

#### Base/Optimism
```bash
# L2s might need different handling
forge script ... --priority-gas-price 0.001gwei
```

### 7. Debugging Tips

1. **Check RPC Status**:
   ```bash
   curl -X POST $ETHEREUM_RPC \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
   ```

2. **Test Gas Estimation**:
   ```bash
   cast estimate --rpc-url $ETHEREUM_RPC \
     --from 0xYOUR_ADDRESS \
     0xTARGET_ADDRESS \
     "functionName(uint256)" \
     123
   ```

3. **Monitor Gas Prices**:
   ```bash
   # Watch gas prices in real-time
   watch -n 5 'cast gas-price --rpc-url $ETHEREUM_RPC'
   ```

### 8. Fallback Strategy

If issues persist, use the non-batched approach:

```bash
# Run source chains only (no multi-chain switching)
forge script script/WireOApp.s.sol:WireOApp \
    -s "runSourceOnly(string)" \
    "./utils/layerzero.config.json" \
    --broadcast --via-ir --ffi --slow

# Then run destination chains
forge script script/WireOApp.s.sol:WireOApp \
    -s "runDestinationOnly(string)" \
    "./utils/layerzero.config.json" \
    --broadcast --via-ir --ffi --slow
```

### 9. RPC Provider Recommendations

**Free Tier (Limited)**:
- Alchemy: 300M compute units/month
- Infura: 100k requests/day
- QuickNode: 10M requests/month

**Paid/Premium** (Recommended for production):
- Alchemy Growth: $49/month
- Infura Team: $50/month
- QuickNode Pro: $49/month

**Public RPCs** (Use with caution):
- https://ethereum.publicnode.com
- https://rpc.ankr.com/eth
- https://eth.llamarpc.com

### 10. Script Modifications for Better Reliability

You can also modify the BatchedWireOApp script to add retries:

```solidity
// In broadcastByChain() function, wrap the transaction execution:
uint256 maxRetries = 3;
for (uint256 retry = 0; retry < maxRetries; retry++) {
    (bool success,) = cachedTx.target.call{value: cachedTx.value}(cachedTx.data);
    if (success) break;
    
    if (retry < maxRetries - 1) {
        console.log("Transaction failed, retrying...");
        vm.sleep(5000); // Wait 5 seconds
    }
}
```

Remember: Always test on testnet first with smaller batches before running on mainnet! 