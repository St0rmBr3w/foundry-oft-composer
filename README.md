<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/logo-dark.svg"/>
  </a>
</p>

<p align="center">
  <a href="https://docs.layerzero.network/v2">Developer Docs</a> | <a href="https://layerzero.network">Website</a>
</p>

# LayerZero OFT Example with Foundry

Deploy and use Omnichain Fungible Tokens (OFT) with LayerZero V2 using Foundry. This repo provides a simple **deploy → wire → send** workflow with automated address resolution from LayerZero APIs.

## Key Features

✅ **No hardcoded addresses** - Automatically fetches LayerZero endpoints and DVN addresses  
✅ **Simple configuration** - JSON-based config files for deployment and wiring  
✅ **Three-step process** - Deploy, wire pathways, send tokens  
✅ **Foundry-native** - Pure Solidity scripts, no external dependencies

## Table of Contents

- [Prerequisite Knowledge](#prerequisite-knowledge)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Configuration Files](#configuration-files)
- [Detailed Workflow](#detailed-workflow)
- [Next Steps](#next-steps)
- [Production Deployment Checklist](#production-deployment-checklist)
- [Appendix](#appendix)

## Prerequisite Knowledge

Before running this example, you should understand:
- **[What is an OApp?](https://docs.layerzero.network/v2/home/protocol/oapp-overview)** - Omnichain Applications enable cross-chain messaging
- **[What is an OFT?](https://docs.layerzero.network/v2/home/token-standards/oft-quickstart)** - Omnichain Fungible Tokens can move seamlessly between blockchains
- **[LayerZero Terminology](https://docs.layerzero.network/v2/home/glossary)** - Key concepts like Endpoint IDs, DVNs, and Pathways

## Requirements

- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** - Latest version
- **[Git](https://git-scm.com/downloads)** - For dependency management  
- **Private key** - Funded with native tokens on Base and Arbitrum (or your chosen chains)
- **RPC URLs** - Access to blockchain nodes

## Quick Start

```bash
# 1. Clone and setup
git clone <repository-url>
cd foundry-vanilla
forge install

# 2. Download LayerZero metadata (endpoints, DVNs, etc.)
./script/download-deployments.sh

# 3. Configure your deployment
# Edit script/deploy-config.json and script/wire-config.json

# 4. Deploy OFT to multiple chains
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "script/deploy-config.json" \
  "layerzero-deployments.json" \
  --via-ir --broadcast --multi

# 5. Wire LayerZero pathways
forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string,string,string)" \
  "script/wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir --broadcast --slow

# 6. Send tokens cross-chain
forge script script/SendOFT.s.sol:SendOFT \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  <OFT_ADDRESS> <DEST_EID> <RECIPIENT> <AMOUNT> 0 0x 0x 0x \
  --rpc-url <SOURCE_RPC> --broadcast
```

## Configuration Files

### 1. Deploy Configuration (`script/deploy-config.json`)

Defines where and how to deploy your OFT:

```json
{
  "tokenName": "My Omnichain Token",
  "tokenSymbol": "MYOFT",
  "chains": [
    {
      "name": "base",              // Chain identifier
      "eid": 30184,                // LayerZero Endpoint ID
      "rpc": "https://base.gateway.tenderly.co",
      "deployer": "0xYourAddress",  // Who will own the token
      "lzEndpoint": "auto"          // Auto-resolved from metadata
    },
    {
      "name": "arbitrum",
      "eid": 30110,
      "rpc": "https://arbitrum.gateway.tenderly.co",
      "deployer": "0xYourAddress",
      "lzEndpoint": "auto"
    }
  ]
}
```

**Parameters:**
- `tokenName/Symbol`: Your token details
- `chains`: Array of chains to deploy on
  - `name`: Chain name (must match LayerZero metadata)
  - `eid`: [Endpoint ID](https://docs.layerzero.network/v2/home/glossary#endpoint-id)
  - `rpc`: RPC URL for the chain
  - `deployer`: Token owner address
  - `lzEndpoint`: Set to "auto" or specify address

### 2. Wire Configuration (`script/wire-config.json`)

Configures cross-chain pathways:

```json
{
  "chains": {
    "base": {
      "eid": 30184,
      "rpc": "https://base.gateway.tenderly.co",
      "oapp": "0xYourDeployedOFT"  // From deployment step
    },
    "arbitrum": {
      "eid": 30110,
      "rpc": "https://arbitrum.gateway.tenderly.co",
      "oapp": "0xYourDeployedOFT"
    }
  },
  "pathways": [
    {
      "from": "base",
      "to": "arbitrum",
      "requiredDVNs": ["LayerZero Labs"],  // Auto-resolved
      "optionalDVNs": [],
      "optionalDVNThreshold": 0,
      "confirmations": [6, 6],    // [src→dst, dst→src]
      "maxMessageSize": 10000,
      "enforcedOptions": [
        {
          "lzReceiveGas": 200000,  // Gas for receiving
          "lzReceiveValue": 0,
          "lzComposeGas": 0,
          "lzComposeIndex": 0,
          "lzNativeDropAmount": 0,
          "lzNativeDropRecipient": "0x0000000000000000000000000000000000000000"
        }
      ]
    }
  ],
  "bidirectional": true  // Auto-create reverse pathway
}
```

**Parameters:**
- `chains`: OApp addresses on each chain
- `pathways`: Directional configurations
  - `requiredDVNs`: Security providers (names auto-resolved to addresses)
  - `confirmations`: Block confirmations before verification
  - `enforcedOptions`: Gas and execution settings per message type

### 3. Downloaded Metadata

The script downloads two critical files:

**`layerzero-deployments.json`** - Contains:
- LayerZero endpoint addresses for each chain
- Send/receive library addresses
- Executor addresses
- Other protocol contracts

**`layerzero-dvns.json`** - Contains:
- DVN addresses for each chain
- DVN capabilities and status
- Provider information

> 💡 **No more hardcoding!** The scripts automatically look up addresses from these files based on chain names.

## Detailed Workflow

### Step 1: Download Metadata

```bash
./script/download-deployments.sh
```

This downloads the latest LayerZero contract addresses and DVN configurations. Run this periodically to stay updated.

### Step 2: Deploy OFT

```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "script/deploy-config.json" \
  "layerzero-deployments.json" \
  --via-ir --broadcast --multi
```

This:
- Reads your token configuration
- Looks up LayerZero endpoint addresses automatically
- Deploys MyOFT to all specified chains
- Saves deployment addresses to `deployments/` directory

### Step 3: Wire Pathways

```bash
forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string,string,string)" \
  "script/wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir --broadcast --slow
```

This:
- Reads your pathway configuration
- Automatically resolves DVN names to chain-specific addresses
- Sets up peers between OApps
- Configures security settings (DVNs, confirmations)
- Sets enforced gas options

> Note: Use `--slow` to avoid nonce issues when configuring multiple chains.

### Step 4: Send Tokens

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
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

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
2. Add to `deploy-config.json` and `wire-config.json`
3. Ensure you have gas tokens on the new chain
4. Re-run deploy and wire scripts

### Available Configuration Options

**Deploy Options:**
- Custom token logic (see `src/MyOFT.sol`)
- Initial mint amounts
- Access control settings

**Wire Options:**
- Multiple DVNs for enhanced security
- Custom executors
- Per-message-type gas settings
- Compose message support

**Send Options:**
- Slippage protection (`minAmountLD`)
- Extra gas for complex receivers
- Compose messages for triggered actions
- Native token drops

### Troubleshooting

**"DVN not found"**
- Ensure DVN name matches exactly from `layerzero-dvns.json`
- Check DVN is available on your chain
- Verify DVN isn't deprecated

**"Insufficient fee"**
- Increase gas limits in enforced options
- Ensure you have enough native tokens
- Check if options are properly encoded

**Nonce issues**
- Use `--slow` flag for multi-chain operations
- Or use `runSourceOnly` / `runDestinationOnly` functions
- Wait for transactions to confirm between chains

For more help, see the [LayerZero Troubleshooting Guide](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages).
