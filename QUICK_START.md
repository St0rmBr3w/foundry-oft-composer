# LayerZero OFT Quick Start Guide

This guide shows you how to deploy and configure an Omnichain Fungible Token (OFT) using the new simplified configuration system.

## Prerequisites

- Foundry installed
- Private key with funds on target chains
- RPC URLs for target chains

## Quick Setup

### 1. Environment Setup

```bash
# Copy and edit environment file
cp env.example .env
# Edit .env with your private key and RPC URLs

# Load environment
source .env
```

### 2. Deploy Contracts

```bash
# Deploy to multiple chains
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string)" \
  "utils/deploy.config.simple.json" \
  --via-ir --broadcast
```

### 3. Wire Pathways

```bash
# Check current configuration
CHECK_ONLY=true forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
  --sig "run(string)" \
  "utils/layerzero.config.json" \
  --via-ir --ffi -vvv

# Configure pathways
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
  --sig "run(string)" \
  "utils/layerzero.config.json" \
  --broadcast --multi --via-ir --ffi -vvv
```

### 4. Send Tokens

```bash
# Get OFT address from deployment
OFT_ADDRESS=$(jq -r '.chains.ethereum.address' deployments/mainnet/MyOFT.json)

# Send tokens cross-chain
forge script script/SendOFT.s.sol:SendOFT \
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

## Configuration Files

### Deployment Config (`utils/deploy.config.simple.json`)

```json
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

### LayerZero Config (`utils/layerzero.config.json`)

```json
{
  "deployment": "deployments/mainnet/MyOFT.json",
  "pathways": [
    {
      "from": "ethereum",
      "to": "arbitrum",
      "requiredDVNs": ["LayerZero Labs"],
      "confirmations": [15, 10],
      "maxMessageSize": 10000,
      "enforcedOptions": [
        [
          {
            "msgType": 1,
            "lzReceiveGas": 250000
          }
        ]
      ]
    }
  ],
  "bidirectional": true
}
```

### Environment Variables (`.env`)

```bash
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
ETHEREUM_RPC=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
ARBITRUM_RPC=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
BASE_RPC=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
OPTIMISM_RPC=https://opt-mainnet.g.alchemy.com/v2/YOUR_KEY
```

## Key Features

- **Automatic Address Loading**: Contract addresses are loaded from deployment artifacts
- **Environment-based RPCs**: RPC URLs managed via environment variables
- **Batched Execution**: Transactions grouped by chain to avoid nonce issues
- **API Integration**: Automatic fetching of LayerZero metadata
- **Backward Compatibility**: Old format still supported

## Common Issues

- **"RPC not found"**: Check environment variables are set and sourced
- **"Stack too deep"**: Use `--via-ir` flag
- **"vm.envOr not unique"**: Use `--via-ir` flag
- **Nonce issues**: Use `BatchedWireOApp` with `--multi` flag

## Next Steps

- See [README.md](README.md) for detailed documentation
- See [RPC_SETUP.md](RPC_SETUP.md) for RPC configuration
- See [script/docs/WIRE_OAPP_README.md](script/docs/WIRE_OAPP_README.md) for advanced features 