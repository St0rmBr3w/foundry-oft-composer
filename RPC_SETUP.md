# RPC Setup Guide

This guide explains the standardized approach for managing RPC endpoints in LayerZero scripts using environment variables.

## Overview

Instead of hardcoding RPC URLs in configuration files, we use environment variables following Foundry best practices. This approach:
- Keeps sensitive API keys out of version control
- Allows easy switching between different RPC providers
- Follows standard Foundry conventions
- Simplifies configuration files

## Environment Variable Naming Convention

RPC URLs should be set as environment variables using the pattern:
```
{CHAIN_NAME}_RPC
```

### Standard Chain Names

| Chain | Environment Variable | Example Value |
|-------|---------------------|---------------|
| Ethereum | `ETHEREUM_RPC` | `https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY` |
| Arbitrum | `ARBITRUM_RPC` | `https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY` |
| Base | `BASE_RPC` | `https://base-mainnet.g.alchemy.com/v2/YOUR_KEY` |
| Optimism | `OPTIMISM_RPC` | `https://opt-mainnet.g.alchemy.com/v2/YOUR_KEY` |
| Polygon | `POLYGON_RPC` | `https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY` |
| Avalanche | `AVALANCHE_RPC` | `https://api.avax.network/ext/bc/C/rpc` |
| BSC | `BSC_RPC` | `https://bsc-dataseed.binance.org/` |

## Setup Instructions

### 1. Create a `.env` file

Create a `.env` file in your project root:

```bash
# .env
# Mainnet RPCs
ETHEREUM_RPC=https://eth-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
ARBITRUM_RPC=https://arb-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
BASE_RPC=https://base-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
OPTIMISM_RPC=https://opt-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
POLYGON_RPC=https://polygon-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY

# Testnet RPCs (optional)
SEPOLIA_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
ARBITRUM_SEPOLIA_RPC=https://arb-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
BASE_SEPOLIA_RPC=https://base-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY

# Private key for deployments
PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE
```

### 2. Add to `.gitignore`

Ensure your `.env` file is not committed:

```bash
echo ".env" >> .gitignore
```

### 3. Load environment variables

Before running scripts, load your environment variables:

```bash
source .env
```

Or use direnv for automatic loading:

```bash
# Install direnv
brew install direnv  # macOS
# or
sudo apt-get install direnv  # Ubuntu

# Add to your shell
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc  # or ~/.zshrc

# Allow the .envrc file
echo "source .env" > .envrc
direnv allow
```

## Using RPCs in Scripts

### Deployment Scripts

Deployment scripts now only need chain names, not RPC URLs:

```json
// deploy.config.json
{
  "tokenName": "My Omnichain Token",
  "tokenSymbol": "MYOFT",
  "chains": [
    {
      "name": "ethereum",
      "eid": 30101,
      "lzEndpoint": "0x1a44076050125825900e736c501f859c50fE728c"
    },
    {
      "name": "arbitrum",
      "eid": 30110,
      "lzEndpoint": "0x1a44076050125825900e736c501f859c50fE728c"
    }
  ]
}
```

The script automatically loads the RPC from the environment:

```solidity
function getRpcUrl(string memory chainName) internal returns (string memory) {
    // Convert chain name to uppercase for env var
    string memory envVar = string.concat(toUpper(chainName), "_RPC");
    
    // Get RPC from environment
    string memory rpc = vm.envString(envVar);
    require(bytes(rpc).length > 0, string.concat("RPC not found for chain: ", chainName));
    
    return rpc;
}
```

### Wire Scripts

Wire configurations no longer include RPC URLs:

```json
// layerzero.config.json
{
  "deployment": "deployments/mainnet/MyOFT.json",
  "pathways": [
    {
      "from": "ethereum",
      "to": "arbitrum",
      "requiredDVNs": ["LayerZero Labs"],
      "confirmations": 15
    }
  ],
  "bidirectional": true
}
```

## RPC Provider Recommendations

### Free Tiers

1. **Alchemy**
   - 300M compute units/month
   - Good for: All major chains
   - Sign up: https://alchemy.com

2. **Infura**
   - 100k requests/day
   - Good for: Ethereum, Arbitrum, Optimism
   - Sign up: https://infura.io

3. **QuickNode**
   - 10M requests/month
   - Good for: Wide chain support
   - Sign up: https://quicknode.com

### Public RPCs (Use with caution)

```bash
# Ethereum
ETHEREUM_RPC=https://ethereum.publicnode.com

# Arbitrum
ARBITRUM_RPC=https://arb1.arbitrum.io/rpc

# Base
BASE_RPC=https://mainnet.base.org

# Optimism
OPTIMISM_RPC=https://mainnet.optimism.io
```

⚠️ **Warning**: Public RPCs may have rate limits and less reliability. Use premium providers for production.

## Multiple Environments

For different environments, use prefixes:

```bash
# Production
PROD_ETHEREUM_RPC=https://eth-mainnet.g.alchemy.com/v2/PROD_KEY
PROD_ARBITRUM_RPC=https://arb-mainnet.g.alchemy.com/v2/PROD_KEY

# Staging
STAGING_ETHEREUM_RPC=https://eth-mainnet.g.alchemy.com/v2/STAGING_KEY
STAGING_ARBITRUM_RPC=https://arb-mainnet.g.alchemy.com/v2/STAGING_KEY

# Development
DEV_ETHEREUM_RPC=http://localhost:8545
DEV_ARBITRUM_RPC=http://localhost:8546
```

Then set the environment:

```bash
export DEPLOYMENT_ENV=prod  # or staging, dev
```

## Troubleshooting

### "RPC not found for chain" error

1. Check that the environment variable is set:
   ```bash
   echo $ETHEREUM_RPC
   ```

2. Ensure the variable name matches the expected format:
   ```bash
   # Correct
   ETHEREUM_RPC=https://...
   
   # Incorrect
   ETH_RPC=https://...
   ethereum_rpc=https://...
   ```

3. Source your `.env` file:
   ```bash
   source .env
   ```

### Connection timeouts

1. Check RPC endpoint is accessible:
   ```bash
   curl -X POST $ETHEREUM_RPC \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
   ```

2. Try alternative RPC providers

3. Check API key limits

## Security Best Practices

1. **Never commit `.env` files** to version control
2. **Use different API keys** for development and production
3. **Rotate API keys** regularly
4. **Monitor usage** to detect unauthorized access
5. **Use read-only nodes** when possible

## Example Workflow

```bash
# 1. Set up environment
cp env.example .env
# Edit .env with your RPC URLs

# 2. Load environment
source .env

# 3. Deploy contracts
forge script script/DeployMyOFT.s.sol \
  --sig "run(string)" \
  "utils/deploy.config.simple.json" \
  --via-ir --broadcast

# 4. Wire pathways
forge script script/BatchedWireOApp.s.sol \
  --sig "run(string)" \
  "utils/layerzero.config.json" \
  --via-ir --broadcast --multi --ffi

# 5. Send tokens cross-chain
OFT_ADDRESS=$(jq -r '.chains.ethereum.address' deployments/mainnet/MyOFT.json)
forge script script/SendOFT.s.sol \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  $OFT_ADDRESS \
  30110 \
  0x000000000000000000000000YOUR_RECIPIENT_ADDRESS \
  1000000000000000000 \
  0 \
  0x \
  0x \
  0x \
  --broadcast \
  -vvv --rpc-url $ETHEREUM_RPC --via-ir
```

The scripts automatically use the RPC URLs from your environment variables! 