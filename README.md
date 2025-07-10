<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/logo-dark.svg"/>
  </a>
</p>

<p align="center">
  <a href="https://docs.layerzero.network/v2">Developer Docs</a> | <a href="https://layerzero.network">Website</a>
</p>

# LayerZero OFT Example with Foundry

Deploy and use Omnichain Fungible Tokens (OFT) with LayerZero V2 using Foundry. This example demonstrates a complete **deploy → wire → send** workflow with a simplified configuration system that automatically manages deployment artifacts and RPC endpoints.

## Table of Contents

- [LayerZero OFT Example with Foundry](#layerzero-oft-example-with-foundry)
  - [Table of Contents](#table-of-contents)
  - [Prerequisite Knowledge](#prerequisite-knowledge)
  - [Requirements](#requirements)
  - [Setup](#setup)
  - [Build](#build)
  - [Deploy](#deploy)
    - [Deployment Configuration](#deployment-configuration)
  - [Enable Messaging](#enable-messaging)
    - [Wire Configuration](#wire-configuration)
    - [Configuration Options](#configuration-options)
    - [Advanced Features](#advanced-features)
  - [Sending OFT](#sending-oft)
  - [Complete Workflow Example](#complete-workflow-example)
  - [Next Steps](#next-steps)
  - [Production Deployment Checklist](#production-deployment-checklist)
  - [Appendix](#appendix)
    - [Running Tests](#running-tests)
    - [Adding Other Chains](#adding-other-chains)
    - [Using Multisigs](#using-multisigs)
    - [LayerZero Script Functions](#layerzero-script-functions)
    - [Contract Verification](#contract-verification)
    - [Troubleshooting](#troubleshooting)

## Prerequisite Knowledge

Before running this example, you should understand:
- **[What is an OApp?](https://docs.layerzero.network/v2/home/protocol/oapp-overview)** - Omnichain Applications enable cross-chain messaging
- **[What is an OFT?](https://docs.layerzero.network/v2/home/token-standards/oft-quickstart)** - Omnichain Fungible Tokens can move seamlessly between blockchains
- **[LayerZero Terminology](https://docs.layerzero.network/v2/home/glossary)** - Key concepts like [Endpoint IDs](https://docs.layerzero.network/v2/home/glossary#endpoint-id), [DVNs](https://docs.layerzero.network/v2/home/glossary#data-validation-network-dvn), and [Pathways](https://docs.layerzero.network/v2/home/glossary#pathway)

## Requirements

- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** - Latest version
- **[Git](https://git-scm.com/downloads)** - For dependency management  
- **Private key** - Funded with native tokens on Base and Arbitrum (or your chosen chains)
- **RPC URLs** - Access to blockchain nodes

## Setup

1. **Clone and setup dependencies:**
```bash
git clone <repository-url>
cd foundry-vanilla
forge install
```

2. **Configure environment variables:**
```bash
# Copy the example environment file
cp env.example .env

# Edit .env with your private key and RPC URLs
# See RPC_SETUP.md for detailed RPC configuration
```

3. **Load environment variables:**
```bash
source .env
```

4. **Update configuration files:**
   - Edit `utils/deploy.config.simple.json` with your token details
   - Create `utils/layerzero.config.json` for pathway configuration (see examples below)

**Note:** The new system uses environment variables for RPCs and automatically loads contract addresses from deployment artifacts. See [RPC_SETUP.md](RPC_SETUP.md) for detailed RPC configuration instructions.

## Build

```bash
forge build --via-ir
```

## Deploy

Deploy your OFT to multiple chains using the deployment script:

```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string)" \
  "utils/deploy.config.json" \
  --via-ir --broadcast
```

This script:
- Reads your token configuration from `deploy.config.json`
- Uses RPC URLs from environment variables (e.g., `BASE_RPC`, `ARBITRUM_RPC`)
- Deploys MyOFT to all specified chains one at a time (avoids nonce issues)
- Saves deployment addresses in two formats:
  - Legacy: `deployments/myoft-deployments.json`
  - Standardized: `deployments/{environment}/MyOFT.json`

### Deployment Configuration

Create `utils/deploy.config.json`:

```json
{
  "tokenName": "My Omnichain Token",
  "tokenSymbol": "MYOFT",
  "chains": [
    {
      "name": "base",
      "eid": 30184,
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

**Note:** RPC URLs are loaded from environment variables (e.g., `BASE_RPC`, `ARBITRUM_RPC`), not from the config file.

## Enable Messaging

Wire LayerZero pathways between your deployed OApps using the batched script (recommended for multi-chain deployments):

```bash
# Check current configuration status
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

This script:
- Reads your pathway configuration from `layerzero.config.json`
- Automatically loads contract addresses from deployment artifacts
- Uses RPC URLs from environment variables
- Fetches LayerZero deployment and DVN data from APIs
- Batches transactions by chain to avoid nonce issues
- Sets up peers between OApps on different chains
- Configures security settings (DVNs, confirmations)
- Sets enforced gas options for cross-chain messages

### LayerZero Configuration

Create `utils/layerzero.config.json` using the new simplified format:

```json
{
  "deployment": "deployments/mainnet/MyOFT.json",
  
  "overrides": {
    "ethereum": "0xNEW_ADDRESS"  // Optional: override deployment address
  },
  
  "pathways": [
    {
      "from": "ethereum",
      "to": "arbitrum",
      "requiredDVNs": ["LayerZero Labs", "Google Cloud"],
      "optionalDVNs": ["Nethermind"],
      "optionalDVNThreshold": 1,
      "confirmations": [15, 10],
      "maxMessageSize": 10000,
      "enforcedOptions": [
        [
          {
            "msgType": 1,
            "lzReceiveGas": 250000
          }
        ],
        [
          {
            "msgType": 1,
            "lzReceiveGas": 200000
          }
        ]
      ]
    }
  ],
  
  "bidirectional": true
}
```

### Configuration Options

#### Deployment Reference
- `deployment`: Path to deployment artifact (auto-generated by deploy script)
- `overrides`: Optional address overrides for specific chains

#### Pathway Settings
- `requiredDVNs`: Security validators that must verify every message
- `optionalDVNs`: Additional validators for enhanced security
- `optionalDVNThreshold`: How many optional DVNs must verify
- `confirmations`: Block confirmations [A→B, B→A] or single value for both
- `maxMessageSize`: Maximum message size in bytes
- `enforcedOptions`: Gas and execution settings per direction

#### Enforced Options
Configure different message types with specific options:

```json
"enforcedOptions": [
  [  // A→B direction
    {
      "msgType": 1,                    // Standard message
      "lzReceiveGas": 250000,          // Gas for lzReceive
      "lzReceiveValue": 0,             // Value to send
      "lzComposeGas": 500000,          // Gas for composed messages
      "lzComposeIndex": 0,             // Compose index
      "lzNativeDropAmount": 1000000,   // Native token drop
      "lzNativeDropRecipient": "0x..." // Drop recipient
    }
  ],
  [  // B→A direction (only used with bidirectional: true)
    {
      "msgType": 1,
      "lzReceiveGas": 200000
    }
  ]
]
```

### Advanced Features

#### Custom DVN Overrides
Add custom DVN addresses in your config:

```json
{
  "deployment": "deployments/mainnet/MyOFT.json",
  "pathways": [...],
  "dvns": {
    "My Custom DVN": {
      "ethereum": "0xCustomDVNAddressOnEthereum",
      "arbitrum": "0xCustomDVNAddressOnArbitrum"
    }
  }
}
```

#### Partial Wiring
For large deployments or to avoid nonce issues:

```bash
# Wire source chains only
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
  --sig "runSourceOnly(string)" \
  "utils/layerzero.config.json" \
  --broadcast --multi --via-ir --ffi -vvv

# Wire destination chains only
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
  --sig "runDestinationOnly(string)" \
  "utils/layerzero.config.json" \
  --broadcast --multi --via-ir --ffi -vvv
```

> **Note:** The `--ffi` flag is required for API fetching. The `--multi` flag enables multi-chain deployment mode.

## Sending OFT

Send tokens cross-chain using the deployed OFT with chain names:

### List Available Chains
```bash
forge script script/SendOFT.s.sol:SendOFT \
  --sig "listChains(string)" \
  "deployments/mainnet/MyOFT.json" \
  --via-ir
```

### Send Using Chain Names (Recommended)
```bash
forge script script/SendOFT.s.sol:SendOFT \
  --sig "sendWithChainNames(string,string,string,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  "deployments/mainnet/MyOFT.json" \  # Deployment artifact path
  "base" \                            # Source chain name
  "arbitrum" \                        # Destination chain name
  0x000000000000000000000000ed422098669cBB60CAAf26E01485bAFdbAF9eBEA \ # Recipient (bytes32)
  1000000000000000000 \               # Amount (1 token = 1e18 wei)
  0 \                                 # Min amount (slippage)
  0x \                                # Extra options
  0x \                                # Compose message
  0x \                                # OFT command
  --broadcast \
  -vvv --rpc-url $BASE_RPC --via-ir
```

### Send Using Manual Addresses (Legacy)
```bash
forge script script/SendOFT.s.sol:SendOFT \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  0xYourOFT \              # OFT address on source chain
  30110 \                  # Destination endpoint ID
  0x000...recipient \      # Recipient (bytes32 format)
  1000000000000000000 \    # Amount (1 token = 1e18 wei)
  0 \                      # Min amount (slippage)
  0x \                     # Extra options
  0x \                     # Compose message
  0x \                     # OFT command
  --broadcast \
  -vvv --rpc-url $RPC_URL --via-ir
```

**Note:** The new `sendWithChainNames` function automatically loads OFT addresses and endpoint IDs from your deployment artifacts, making cross-chain transfers much easier.

## Complete Workflow Example

Here's a complete end-to-end example:

### 0. Environment Setup
```bash
# Set up environment variables
export PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
export ETHEREUM_RPC="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
export ARBITRUM_RPC="https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY"
export BASE_RPC="https://base-mainnet.g.alchemy.com/v2/YOUR_KEY"
export OPTIMISM_RPC="https://opt-mainnet.g.alchemy.com/v2/YOUR_KEY"
```

### 1. Deploy Contracts
```bash
# Deploy to multiple chains
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string)" \
  "utils/deploy.config.json" \
  --via-ir --broadcast
```

### 2. Wire Pathways
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

### 3. Send Cross-Chain
```bash
# Send tokens from Base to Arbitrum
OFT_ADDRESS=$(jq -r '.chains.base.address' deployments/mainnet/MyOFT.json)

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
  -vvv --rpc-url $BASE_RPC --via-ir

## Next Steps

After completing this example:
1. Review the [Production Deployment Checklist](#production-deployment-checklist)
2. Configure [DVN Security Stack](https://docs.layerzero.network/v2/home/modular-security/security-stack-dvns) for mainnet
3. Implement [Message Options](https://docs.layerzero.network/v2/developers/evm/gas-settings/options) for advanced features
4. Monitor your messages on [LayerZero Scan](https://layerzeroscan.com)

## Production Deployment Checklist

Before mainnet deployment:

- [ ] **Gas Profiling**: Run `forge test --gas-report` to optimize gas usage
- [ ] **Multi-DVN Security**: Use 2-3 required DVNs for production
- [ ] **Confirmation Settings**: Adjust based on chain finality (ETH: 15, L2s: 10-100)
- [ ] **Enforced Options**: Set appropriate gas limits per message type
- [ ] **Rate Limiting**: Implement rate limits for large transfers
- [ ] **Monitoring**: Set up alerts on LayerZero Scan
- [ ] **Audit**: Complete security audit of custom logic

## Appendix

### Running Tests

```bash
forge test --via-ir -vvv
```

### Adding Other Chains

1. Find chain info in [LayerZero docs](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts)
2. Add to `utils/deploy.config.json` and `utils/layerzero.config.json`
3. Ensure you have gas tokens on the new chain
4. Re-run deploy and wire scripts

### Using Multisigs

For multisig deployments, modify the scripts to use your multisig address instead of the private key signer. The configuration files remain the same.

### LayerZero Script Functions

The project includes several helper functions:

**DeployMyOFT.s.sol:**
- `run(string)` - Deploy to all configured chains (one at a time to avoid nonce issues)

**BatchedWireOApp.s.sol:**
- `run(string)` - Wire all pathways with batching
- `runSourceOnly(string)` - Wire only source chain configurations
- `runDestinationOnly(string)` - Wire only destination chain configurations
- `runWithSources(string, string, string)` - Wire with custom deployment/DVN sources

**SendOFT.s.sol:**
- `send(address, uint32, bytes32, uint256, uint256, bytes, bytes, bytes)` - Send tokens cross-chain

**Built-in Foundry tasks:**
- `forge script` - Run deployment and configuration scripts
- `forge test` - Run test suite
- `forge build` - Compile contracts

### Contract Verification

Verify your deployments on block explorers:

- **Base**: Use [Basescan](https://basescan.org) verification
- **Arbitrum**: Use [Arbiscan](https://arbiscan.io) verification

### Troubleshooting

**"RPC not found for chain"**
- Ensure environment variable is set (e.g., `ETHEREUM_RPC`)
- Check variable name matches chain name (uppercase + "_RPC")
- Source your `.env` file: `source .env`

**"DVN not found"**
- Ensure DVN name matches exactly from LayerZero API
- Check DVN is available on your chain
- Verify DVN isn't deprecated
- Use custom DVN overrides if needed

**"Insufficient fee"**
- Increase gas limits in enforced options
- Ensure you have enough native tokens
- Check if options are properly encoded

**Nonce issues**
- Use `BatchedWireOApp` instead of `WireOApp`
- Use `--multi` flag for multi-chain operations
- Or use `runSourceOnly` / `runDestinationOnly` functions
- Wait for transactions to confirm between chains

**"vm.envOr not unique"**
- Use `--via-ir` flag for compilation
- This is a known issue with some Foundry versions

**"Stack too deep"**
- Use `--via-ir` flag for compilation
- This resolves stack depth issues in complex scripts

For more help, see the [LayerZero Troubleshooting Guide](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages).

---

**Feedback:** We welcome feedback from partners to improve this example. Please reach out through our [Discord](https://discord.gg/layerzero) or [GitHub issues](https://github.com/LayerZero-Labs/solidity-examples/issues).
