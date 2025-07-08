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

- [What is Pathway Wiring?](#what-is-pathway-wiring)
- [How the Script Works](#how-the-script-works)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## What is Pathway Wiring?

In LayerZero V2, before two OApps can communicate across chains, you must establish a "pathway" between them. This involves configuring multiple components on both the source and destination chains:

### On the Source Chain:
1. **Send Library**: Tells the OApp which library to use for sending messages
2. **Peer**: Establishes trust by setting the destination OApp address
3. **DVN Configuration**: Sets up security validators for outgoing messages
4. **Executor Configuration**: Configures who will execute messages on the destination
5. **Enforced Options**: Sets minimum gas requirements for message execution

### On the Destination Chain:
1. **Receive Library**: Tells the OApp which library to use for receiving messages
2. **Peer**: Establishes trust by setting the source OApp address
3. **DVN Configuration**: Sets up security validators for incoming messages

## How the Script Works

The script follows this flow:

```
1. Read Configuration
   ├── Parse your layerzero.config.json
   ├── Load LayerZero deployment contracts
   └── Load DVN metadata

2. Validation Phase
   ├── Check current configuration status
   ├── Identify what needs to be configured
   └── Display summary

3. Configuration Phase (if not in check-only mode)
   ├── For each pathway that needs configuration:
   │   ├── Configure Source Chain
   │   │   ├── setSendLibrary()
   │   │   ├── setPeer()
   │   │   ├── setEnforcedOptions()
   │   │   └── setConfig() for DVNs and Executor
   │   └── Configure Destination Chain
   │       ├── setReceiveLibrary()
   │       ├── setPeer()
   │       └── setConfig() for DVNs
   └── Report success
```

## Quick Start

### 1. Prerequisites

- Deployed OApp contracts on source and destination chains
- Private key with ownership of the OApp contracts
- RPC URLs for each chain

### 2. Download LayerZero Metadata

```bash
# Mainnet deployments
curl -o layerzero-deployments.json https://raw.githubusercontent.com/LayerZero-Labs/devtools/main/packages/ua-utils-evm-hardhat/layerzero.mainnet.json

# DVN addresses
curl -o layerzero-dvns.json https://raw.githubusercontent.com/LayerZero-Labs/layerzero-scan-api/main/deployments/mainnet/dvn.json
```

### 3. Create Configuration

Create `utils/layerzero.config.json`:

```json
{
  "chains": {
    "base": {
      "eid": 30184,
      "rpc": "https://base.gateway.tenderly.co",
      "oapp": "0xYourOAppOnBase"
    },
    "arbitrum": {
      "eid": 30110,
      "rpc": "https://arbitrum.gateway.tenderly.co",
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
          "msgType": 1,
          "lzReceiveGas": 150000,
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

### 4. Check Configuration Status

```bash
export PRIVATE_KEY=your_private_key_here
CHECK_ONLY=true forge script script/WireOApp.s.sol:WireOApp \
  -s "run(string,string,string)" \
  "./utils/layerzero.config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --via-ir -vvv
```

### 5. Wire the Pathways

```bash
forge script script/WireOApp.s.sol:WireOApp \
  -s "run(string,string,string)" \
  "./utils/layerzero.config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --via-ir --broadcast --multi -vvv
```

## Configuration

### Chain Configuration

Each chain requires:
- **`eid`**: LayerZero endpoint ID ([see full list](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts))
- **`rpc`**: RPC URL for the chain
- **`oapp`**: Your deployed OApp contract address

### Pathway Configuration

Each pathway defines a unidirectional communication channel:

```json
{
  "from": "source_chain",
  "to": "destination_chain",
  "requiredDVNs": ["LayerZero Labs"],      // Must verify every message
  "optionalDVNs": ["Google Cloud"],        // Additional security
  "optionalDVNThreshold": 1,               // How many optional DVNs must verify
  "confirmations": [15, 10],               // [A→B blocks, B→A blocks]
  "maxMessageSize": 10000,                 // Maximum message size in bytes
  "enforcedOptions": [                     // Minimum execution requirements
    {
      "msgType": 1,
      "lzReceiveGas": 200000,             // Gas for standard messages
      "lzReceiveValue": 0,                // ETH value to send
      "lzComposeGas": 0,                  // Gas for composed messages
      "lzComposeIndex": 0,                // Compose configuration index
      "lzNativeDropAmount": 0,            // Native tokens to drop
      "lzNativeDropRecipient": "0x..."    // Drop recipient
    }
  ]
}
```

### Understanding Key Concepts

#### Bidirectional Communication
- Set `"bidirectional": true` to automatically create reverse pathways
- Each direction can have different configurations (confirmations, gas, etc.)

#### DVNs (Decentralized Verifier Networks)
- **Required DVNs**: Must verify every message (security critical)
- **Optional DVNs**: Additional validators for enhanced security
- DVN addresses are automatically resolved from metadata

#### Confirmations
- Array format: `[A→B, B→A]`
- Different chains need different confirmations based on finality
- Example: Ethereum→Polygon might need 15, Polygon→Ethereum might need 5

#### Enforced Options
- Set minimum gas to prevent out-of-gas failures
- Users can always provide more gas, but not less
- Configure separately for standard and composed messages

## Advanced Usage

### Partial Wiring

For large deployments or to avoid nonce issues:

```bash
# Wire source chains only
forge script script/WireOApp.s.sol:WireOApp \
  -s "runSourceOnly(string,string,string)" \
  "./utils/layerzero.config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --via-ir --broadcast --multi -vvv

# Wire destination chains only  
forge script script/WireOApp.s.sol:WireOApp \
  -s "runDestinationOnly(string,string,string)" \
  "./utils/layerzero.config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --via-ir --broadcast --multi -vvv
```

### Custom DVN Overrides

Add custom DVN addresses in your config:

```json
{
  "chains": { ... },
  "pathways": [ ... ],
  "dvns": {
    "My Custom DVN": {
      "base": "0xCustomDVNAddressOnBase",
      "arbitrum": "0xCustomDVNAddressOnArbitrum"
    }
  }
}
```

### Multi-Chain Example

Wire multiple chains with different configurations:

```json
{
  "chains": {
    "ethereum": { "eid": 30101, "rpc": "...", "oapp": "0x..." },
    "arbitrum": { "eid": 30110, "rpc": "...", "oapp": "0x..." },
    "base": { "eid": 30184, "rpc": "...", "oapp": "0x..." }
  },
  "pathways": [
    {
      "from": "ethereum",
      "to": "arbitrum",
      "requiredDVNs": ["LayerZero Labs", "Google Cloud"],
      "confirmations": [15, 10],
      "maxMessageSize": 10000,
      "enforcedOptions": [{
        "msgType": 1,
        "lzReceiveGas": 250000,
        "lzReceiveValue": 0,
        "lzComposeGas": 0,
        "lzComposeIndex": 0,
        "lzNativeDropAmount": 0,
        "lzNativeDropRecipient": "0x0000000000000000000000000000000000000000"
      }]
    },
    {
      "from": "ethereum",
      "to": "base",
      "requiredDVNs": ["LayerZero Labs"],
      "confirmations": [15, 3],
      "maxMessageSize": 10000,
      "enforcedOptions": [{
        "msgType": 1,
        "lzReceiveGas": 150000,
        "lzReceiveValue": 0,
        "lzComposeGas": 0,
        "lzComposeIndex": 0,
        "lzNativeDropAmount": 0,
        "lzNativeDropRecipient": "0x0000000000000000000000000000000000000000"
      }]
    }
  ],
  "bidirectional": true
}
```

## Troubleshooting

### Common Issues

1. **"DVN not found" errors**
   - Verify DVN name spelling matches exactly
   - Check DVN is available on both chains
   - Some DVNs may be deprecated

2. **"Source deployment not found"**
   - Check chain name matches deployment JSON
   - Verify endpoint ID is correct
   - Ensure using LayerZero V2 deployments

3. **Transaction failures**
   - Verify signer owns the OApp contracts
   - Ensure sufficient native tokens for gas
   - Check RPC URL rate limits

4. **Nonce issues**
   - Use `--slow` flag or wire chains separately
   - Wait between transactions on same chain

### Verification

After wiring, verify your configuration:

1. Run script in check-only mode
2. Check on [LayerZero Scan](https://layerzeroscan.com)
3. Send a test message between OApps

### Security Best Practices

- Use multiple required DVNs for production (2-3 recommended)
- Set appropriate confirmations based on chain finality
- Test on testnet before mainnet deployment
- Monitor for failed messages on LayerZero Scan

## Available DVNs

Common DVN providers:
- LayerZero Labs
- Google Cloud
- Polyhedra
- Animoca
- Nethermind
- P2P.org
- Stargate

Check `layerzero-dvns.json` for complete list per chain.

## Resources

- [LayerZero V2 Docs](https://docs.layerzero.network/v2)
- [Endpoint IDs](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts)
- [DVN Addresses](https://docs.layerzero.network/v2/developers/evm/technical-reference/dvn-addresses)
- [LayerZero Scan](https://layerzeroscan.com) 