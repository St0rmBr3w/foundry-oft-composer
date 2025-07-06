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
- **[DVNs](https://docs.layerzero.network/v2/home/glossary#decentralized-verifier-network-dvn)** - Security modules that verify cross-chain messages
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

2. **Create wire configuration** (`wire-config.json`):
   ```json
   {
     "name": "My OApp Wiring",
     "contractAddresses": {
       "base": "0xYourOAppOnBase",
       "arbitrum": "0xYourOAppOnArbitrum"
     },
     "connections": [
       {
         "from": "base",
         "to": "arbitrum",
         "config": {
           "sendLibrary": "SendUln302",
           "receiveLibraryConfig": {
             "receiveLibrary": "ReceiveUln302",
             "gracePeriod": 0
           },
           "sendConfig": {
             "maxMessageSize": 10000,
             "executorConfig": {
               "maxMessageSize": 10000,
               "executor": "LayerZero Labs"
             },
             "ulnConfig": {
               "confirmations": 6,
               "requiredDVNs": ["LayerZero Labs"],
               "optionalDVNs": [],
               "optionalDVNThreshold": 0
             }
           },
           "receiveConfig": {
             "ulnConfig": {
               "confirmations": 6,
               "requiredDVNs": ["LayerZero Labs"],
               "optionalDVNs": [],
               "optionalDVNThreshold": 0
             }
           },
           "enforcedOptions": [
             {
               "msgType": 1,
               "options": "0x00030100110100000000000000000000000000030d40"
             }
           ]
         }
       }
     ]
   }
   ```

## Basic Usage

Wire OApp pathways:

```bash
forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string,string,string)" \
  "wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir --broadcast --slow
```

Check existing configuration (dry run):

```bash
forge script script/WireOApp.s.sol:WireOApp \
  --sig "check(string,string,string)" \
  "wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir
```

## Configuration

### Connection Parameters

Each connection in the config file supports:

- **`sendLibrary`**: Message sending library (e.g., "SendUln302")
- **`receiveLibrary`**: Message receiving library (e.g., "ReceiveUln302")
- **`confirmations`**: Block confirmations before message verification
- **`requiredDVNs`**: DVNs that must verify every message
- **`optionalDVNs`**: Additional DVNs for enhanced security
- **`enforcedOptions`**: Gas and execution parameters per message type

### Enforced Options

Configure gas limits for different message types:

```json
"enforcedOptions": [
  {
    "msgType": 1,  // Standard message
    "options": "0x00030100110100000000000000000000000000030d40"  // 200k gas
  },
  {
    "msgType": 2,  // Token transfer with compose
    "options": "0x00030100110100000000000000000000000000061a80"  // 400k gas
  }
]
```

## DVN Configuration

**Important**: DVNs are chain-specific contracts. Each chain has its own DVN addresses.

For a Base → Arbitrum pathway:
- **Base send config**: Uses Base's LayerZero Labs DVN (`0x9e059a54699a285714207b43b055483e78faac25`)
- **Arbitrum receive config**: Uses Arbitrum's LayerZero Labs DVN (`0x2f55c492897526677c5b68fb199ea31e2c126416`)

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
  "wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir --broadcast

# Then wire destination chains
forge script script/WireOApp.s.sol:WireOApp \
  --sig "runDestinationOnly(string,string,string)" \
  "wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir --broadcast
```

### DVN Not Found Errors

If you see "Required DVN not found in metadata":
1. Check DVN name spelling in config matches metadata exactly
2. Ensure DVN is available on the target chain
3. Verify DVN is not deprecated (`lzReadCompatible: true` DVNs are read-only)

### Configuration Already Set

The script skips configurations that are already set. To force reconfiguration:
1. Clear existing config manually via contract calls
2. Or deploy fresh OApp contracts

## Advanced Usage

### Custom DVN Resolution

Override automatic DVN resolution by providing addresses directly:

```json
"ulnConfig": {
  "confirmations": 6,
  "requiredDVNs": ["0x9e059a54699a285714207b43b055483e78faac25"],
  "optionalDVNs": [],
  "optionalDVNThreshold": 0
}
```

### Multi-DVN Security

For production deployments, use multiple required DVNs:

```json
"requiredDVNs": ["LayerZero Labs", "Google Cloud", "Polyhedra"],
"optionalDVNs": ["Animoca", "Nethermind"],
"optionalDVNThreshold": 1  // Require 1 of 2 optional DVNs
```

### Custom Executors

Specify custom executor addresses:

```json
"executorConfig": {
  "maxMessageSize": 10000,
  "executor": "0xYourCustomExecutor"
}
```

For more details, see the [LayerZero Configuration Guide](https://docs.layerzero.network/v2/developers/evm/configuration/default-config). 