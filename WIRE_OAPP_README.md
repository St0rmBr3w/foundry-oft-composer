<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/logo-dark.svg"/>
  </a>
</p>

<p align="center">
  <a href="https://docs.layerzero.network/v2">Developer Docs</a> | <a href="https://layerzero.network">Website</a>
</p>

# Wire OApp Script

Automatically configure LayerZero pathways between deployed OApps using deployment and DVN metadata from the LayerZero API.

## Table of Contents

- [Prerequisite Knowledge](#prerequisite-knowledge)
- [Requirements](#requirements)
- [Setup](#setup)
- [Basic Usage](#basic-usage)
- [Configuration](#configuration)
- [DVN Configuration](#dvn-configuration)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## Prerequisite Knowledge

Before using this script, understand:
- **[LayerZero Pathways](https://docs.layerzero.network/v2/home/glossary#pathway)** - Directional connections between OApps
- **[DVNs](https://docs.layerzero.network/v2/home/glossary#data-validation-network-dvn)** - Security modules that verify cross-chain messages
- **[Endpoint IDs](https://docs.layerzero.network/v2/home/glossary#endpoint-id)** - Unique identifiers for each blockchain

## Requirements

- Deployed OApp contracts on source and destination chains
- LayerZero deployment metadata (`layerzero-deployments.json`)
- DVN configuration file (`layerzero-dvns.json`)
- Private key with ownership of the OApp contracts

## Setup

1. **Download LayerZero metadata**:
   ```bash
   # Mainnet deployments
   curl -o layerzero-deployments.json https://raw.githubusercontent.com/LayerZero-Labs/devtools/main/packages/ua-utils-evm-hardhat/layerzero.mainnet.json
   
   # DVN addresses
   curl -o layerzero-dvns.json https://raw.githubusercontent.com/LayerZero-Labs/layerzero-scan-api/main/deployments/mainnet/dvn.json
   ```

2. **Create wire configuration** (`utils/wire-config.json`):
   ```json
   {
     "chains": {
       "base": {
         "eid": 30184,
         "rpc": "https://base.gateway.tenderly.co",
         "signer": "WILL_USE_PRIVATE_KEY",
         "oapp": "0xYourOAppOnBase"
       },
       "arbitrum": {
         "eid": 30110,
         "rpc": "https://arbitrum.gateway.tenderly.co",
         "signer": "WILL_USE_PRIVATE_KEY",
         "oapp": "0xYourOAppOnArbitrum"
       }
     },
     "pathways": [
       {
         "from": "base",
         "to": "arbitrum",
         "requiredDVNs": ["LayerZero Labs"],
         "optionalDVNs": [],
         "optionalDVNThreshold": 0,
         "confirmations": [3, 5],
         "maxMessageSize": 10000,
         "enforcedOptions": [
           {
             "lzReceiveGas": 150000,
             "lzReceiveValue": 0,
             "lzComposeGas": 0,
             "lzComposeIndex": 0,
             "lzNativeDropAmount": 0,
             "lzNativeDropRecipient": "0x0000000000000000000000000000000000000000"
           },
           {
             "lzReceiveGas": 180000,
             "lzReceiveValue": 0,
             "lzComposeGas": 0,
             "lzComposeIndex": 0,
             "lzNativeDropAmount": 0,
             "lzNativeDropRecipient": "0x0000000000000000000000000000000000000000"
           }
         ]
       }
     ],
     "bidirectional": true
   }
   ```

## Basic Usage

Wire OApp pathways:

```bash
forge script script/WireOApp.s.sol:WireOApp \
  -s "run(string,string,string)" \
  "./utils/wire-config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --broadcast --slow --multi -vvv
```

Check existing configuration (dry run):

```bash
CHECK_ONLY=true forge script script/WireOApp.s.sol:WireOApp \
  -s "run(string,string,string)" \
  "./utils/wire-config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  -vvv
```

## Configuration

### Chain Configuration

Each chain in the config file supports:

- **`eid`**: [Endpoint ID](https://docs.layerzero.network/v2/home/glossary#endpoint-id) for the chain
- **`rpc`**: RPC URL for the chain
- **`signer`**: Set to "WILL_USE_PRIVATE_KEY" to use environment variable
- **`oapp`**: Deployed OApp contract address on this chain

### Pathway Configuration

Each pathway supports:

- **`from`/`to`**: Chain names (must match keys in `chains` section)
- **`requiredDVNs`**: Array of DVN names that must verify every message
- **`optionalDVNs`**: Array of additional DVN names for enhanced security
- **`optionalDVNThreshold`**: Number of optional DVNs that must verify
- **`confirmations`**: Array of block confirmations [A→B, B→A]
- **`maxMessageSize`**: Maximum message size in bytes
- **`enforcedOptions`**: Array of gas settings [A→B, B→A]

### Enforced Options

Configure gas limits for different message types:

```json
"enforcedOptions": [
  {
    "lzReceiveGas": 150000,        // Gas for standard messages
    "lzReceiveValue": 0,           // Value to send with message
    "lzComposeGas": 0,             // Gas for compose messages
    "lzComposeIndex": 0,           // Compose message index
    "lzNativeDropAmount": 0,       // Native token drop amount
    "lzNativeDropRecipient": "0x0000000000000000000000000000000000000000"
  }
]
```

## DVN Configuration

**Important**: DVNs are chain-specific contracts. Each chain has its own DVN addresses.

For a Base → Arbitrum pathway:
- **Base send config**: Uses Base's LayerZero Labs DVN
- **Arbitrum receive config**: Uses Arbitrum's LayerZero Labs DVN

The script automatically resolves the correct DVN addresses for each chain from the metadata.

### Available DVNs

Common DVN providers per chain:
- LayerZero Labs (available on all chains)
- Google Cloud
- Polyhedra
- Animoca

Check `layerzero-dvns.json` for complete list and addresses.

## Troubleshooting

### Nonce Issues

When wiring multiple chains, use the `--slow` flag to avoid nonce conflicts:

```bash
forge script script/WireOApp.s.sol:WireOApp ... --broadcast --slow
```

Or wire chains individually:

```bash
# Wire only source chain configurations
forge script script/WireOApp.s.sol:WireOApp \
  --sig "runSourceOnly(string,string,string)" \
  "utils/wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir --broadcast

# Then wire destination chains
forge script script/WireOApp.s.sol:WireOApp \
  --sig "runDestinationOnly(string,string,string)" \
  "utils/wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir --broadcast
```

### DVN Resolution Errors

If you get "DVN not found" errors:

1. **Check DVN name spelling**: Must match exactly from `layerzero-dvns.json`
2. **Verify DVN availability**: Some DVNs aren't available on all chains
3. **Check DVN status**: Ensure DVN isn't deprecated or read-only

### Configuration Validation

The script includes built-in validation:

- Verifies all required DVNs exist for each chain
- Checks OApp addresses are valid
- Validates RPC URLs are accessible
- Confirms endpoint addresses are correct

## Advanced Usage

### Partial Wiring

For large deployments, wire source and destination chains separately:

```bash
# Wire source chains only
forge script script/WireOApp.s.sol:WireOApp \
  -s "runSourceOnly(string,string,string)" \
  "./utils/wire-config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --broadcast --multi -vvv

# Wire destination chains only  
forge script script/WireOApp.s.sol:WireOApp \
  -s "runDestinationOnly(string,string,string)" \
  "./utils/wire-config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --broadcast --multi -vvv
```

### Check-Only Mode

Validate configuration without making changes:

```bash
CHECK_ONLY=true forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string,string,string)" \
  "utils/wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir
```

### Custom DVN Overrides

Override DVN addresses in the config file:

```json
{
  "chains": { ... },
  "pathways": [ ... ],
  "dvns": {
    "LayerZero Labs": {
      "base": "0xCustomDVNAddress",
      "arbitrum": "0xAnotherCustomAddress"
    }
  }
}
```

### Environment Variables

Set these environment variables:

```bash
export PRIVATE_KEY=your_private_key_here
export CHECK_ONLY=false  # Set to true for dry run
```

### Console Output

The script provides detailed console output:

- ✅ Success messages for completed actions
- ⚠️ Warnings for optional DVNs not found
- ❌ Errors for configuration issues
- 📊 Progress indicators for multi-chain operations

### Security Considerations

- Use multiple required DVNs for production
- Set appropriate confirmation counts per chain
- Configure gas limits based on message complexity
- Monitor transactions on [LayerZero Scan](https://layerzeroscan.com) 