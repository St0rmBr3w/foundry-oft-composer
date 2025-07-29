# LayerZero OApp Wire Script

> **Scope:** legacy (non-batched) wiring via `WireOApp.s.sol`. Quick-start, deployment, and batched wiring live in the root [`README.md`](../README.md).

This script automates the process of wiring LayerZero OApp pathways using human-readable configuration files.

## Features

- **Human-readable configuration**: Use chain names and DVN names instead of addresses
- **Automatic DVN resolution**: DVN addresses are automatically fetched from LayerZero's official metadata
- **Per-chain OApp support**: Configure different OApp addresses for each chain
- **Automatic bidirectional pathways**: Configure once, wire both directions
- **Multi-chain support**: Wire multiple pathways in a single execution
- **Automatic contract resolution**: Fetches LayerZero deployment contracts from official API
- **Enforced options**: Configure gas limits and values for message execution
- **Peer setting**: Automatically pairs OApps across chains for trusted communication

## How It Works

For each pathway (e.g., Ethereum → Polygon), the script:

1. **On the source chain (Ethereum)**: 
   - Calls `setSendLibrary` on the source OApp to configure the send library
   - Calls `setPeer` to establish trust with the destination OApp
   - Calls `setEnforcedOptions` to set gas limits and execution parameters
   - Calls `setConfig` with send configurations (DVNs, executor, etc.)

2. **On the destination chain (Polygon)**:
   - Calls `setReceiveLibrary` on the destination OApp to configure the receive library
   - Calls `setPeer` to establish trust with the source OApp
   - Calls `setConfig` with receive configurations (DVNs)

For bidirectional communication, it automatically creates the reverse pathway (Polygon → Ethereum) with the same DVN configurations.

## Understanding Pathways

A **pathway** in LayerZero represents a unidirectional communication channel between two OApps on different chains. Each pathway consists of:

- **Source Chain**: Where messages originate (configured with `setSendLibrary` and send configs)
- **Destination Chain**: Where messages are received (configured with `setReceiveLibrary` and receive configs)
- **DVNs**: The same set of DVNs must be configured on both ends to verify messages

For example:
- Ethereum → Polygon is one pathway
- Polygon → Ethereum is a separate pathway

To enable two-way communication between OApps, you need both pathways configured. Setting `"bidirectional": true` automatically creates both directions.

## Usage

### 1. Download LayerZero Metadata

First, download the latest LayerZero deployment artifacts and DVN metadata:

```bash
chmod +x script/download-deployments.sh
./script/download-deployments.sh
```

This creates:
- `layerzero-deployments.json` - Official LayerZero contracts
- `layerzero-dvns.json` - DVN addresses for all chains

### 2. Configure Your Pathways

Create a configuration file (e.g., `layerzero.config.json`) with your OApp settings:

```json
{
  "chains": {
    "ethereum": {
      "eid": 30101,
      "rpc": "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xYOUR_ETHEREUM_SIGNER",
      "oapp": "0xYOUR_OAPP_ADDRESS_ON_ETHEREUM"
    },
    "arbitrum": {
      "eid": 30110,
      "rpc": "https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xYOUR_ARBITRUM_SIGNER",
      "oapp": "0xYOUR_OAPP_ADDRESS_ON_ARBITRUM"
    }
  },
  "pathways": [
    {
      "from": "ethereum",
      "to": "arbitrum",
      "requiredDVNs": ["LayerZero Labs", "Google Cloud"],
      "optionalDVNs": [],
      "optionalDVNThreshold": 0,
      "confirmations": [15, 10],
      "maxMessageSize": 10000
    }
  ],
  "bidirectional": true
}
```

Note: DVN addresses are automatically resolved from the metadata. No need to specify them!

### 3. Run the Wire Script

Execute the script with your configuration:

```bash
forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string,string,string)" \
  "script/layerzero.config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir \
  --broadcast
```

## Configuration Reference

### Chain Configuration

```json
"chains": {
  "<chain_name>": {
    "eid": <endpoint_id>,
    "rpc": "<rpc_url>",
    "signer": "<signer_address>",
    "oapp": "<oapp_address_on_this_chain>"
  }
}
```

Each chain must specify:
- `eid`: The LayerZero endpoint ID for the chain
- `rpc`: RPC URL for connecting to the chain
- `signer`: Address that will execute the transactions
- `oapp`: Your OApp contract address deployed on this specific chain

### DVN Configuration (Optional)

DVN addresses are automatically resolved from LayerZero's metadata. However, you can override or add custom DVNs:

```json
"dvns": {
  "<custom_dvn_name>": {
    "<chain_name>": "<dvn_address>"
  }
}
```

### Pathway Configuration

Define message pathways between chains:

```json
"pathways": [
  {
    "from": "<source_chain_name>",
    "to": "<destination_chain_name>",
    "requiredDVNs": ["<dvn_name>", ...],
    "optionalDVNs": ["<dvn_name>", ...],
    "optionalDVNThreshold": <number>,
    "confirmations": [<AtoB_confirmations>, <BtoA_confirmations>],
    "maxMessageSize": <bytes>,
    "enforcedOptions": [
      {
        "lzReceiveGas": <AtoB_gas_for_standard_messages>,
        "lzReceiveValue": <AtoB_value_for_standard_messages>,
        "lzComposeGas": <AtoB_gas_for_composed_messages>,
        "lzComposeIndex": <AtoB_index_for_composed_messages>,
        "lzNativeDropAmount": <AtoB_native_token_drop_amount>,
        "lzNativeDropRecipient": "<AtoB_recipient_address>"
      },
      {
        "lzReceiveGas": <BtoA_gas_for_standard_messages>,
        "lzReceiveValue": <BtoA_value_for_standard_messages>,
        "lzComposeGas": <BtoA_gas_for_composed_messages>,
        "lzComposeIndex": <BtoA_index_for_composed_messages>,
        "lzNativeDropAmount": <BtoA_native_token_drop_amount>,
        "lzNativeDropRecipient": "<BtoA_recipient_address>"
      }
    ]
  }
]
```

#### Confirmations Array

The `confirmations` field is an array `[AtoB, BtoA]` where:
- **AtoB**: Number of confirmations for messages from chain A to chain B
- **BtoA**: Number of confirmations for messages from chain B to chain A (only used if `bidirectional: true`)

This allows different confirmation requirements based on each chain's finality characteristics. For example:
- Ethereum → Polygon might need 15 confirmations
- Polygon → Ethereum might only need 5 confirmations

You can also provide a single value (e.g., `"confirmations": [15]`) which will be used for both directions.

#### Enforced Options

The `enforcedOptions` field is an array `[AtoB, BtoA]` where:
- **First element**: Enforced options for messages from chain A to chain B
- **Second element**: Enforced options for messages from chain B to chain A (only used if `bidirectional: true`)

This allows different gas requirements and execution parameters based on each chain's characteristics. For example:
- Ethereum → Polygon might need 250,000 gas
- Polygon → Ethereum might only need 150,000 gas

Each enforced option object contains:
- **`lzReceiveGas`**: Minimum gas for executing `lzReceive` on destination (standard messages, msgType 1)
- **`lzReceiveValue`**: Native token value to send with `lzReceive` execution
- **`lzComposeGas`**: Minimum gas for executing `lzCompose` (composed messages, msgType 2)
- **`lzComposeIndex`**: Index parameter for composed message execution
- **`lzNativeDropAmount`**: Amount of native tokens to drop to a recipient
- **`lzNativeDropRecipient`**: Address to receive the native token drop

Set values to 0 to skip enforcing that option. These are enforced minimums - users can always provide more gas/value.

You can also provide a single enforced options object which will be used for both directions.

#### Example with Detailed Explanation

```json
{
  "chains": {
    "ethereum": {
      "eid": 30101,
      "rpc": "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xSIGNER",
      "oapp": "0xOAPP_ON_ETHEREUM"
    },
    "polygon": {
      "eid": 30109,
      "rpc": "https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xSIGNER",
      "oapp": "0xOAPP_ON_POLYGON"
    }
  },
  "pathways": [
    {
      "from": "ethereum",
      "to": "polygon",
      "requiredDVNs": ["LayerZero Labs"],
      "optionalDVNs": [],
      "optionalDVNThreshold": 0,
      "confirmations": [15, 5],  // [Eth→Poly needs 15, Poly→Eth needs 5]
      "maxMessageSize": 10000,
      "enforcedOptions": [
        {  // Eth→Poly enforced options
          "lzReceiveGas": 250000,
          "lzReceiveValue": 0,
          "lzComposeGas": 0,
          "lzComposeIndex": 0,
          "lzNativeDropAmount": 0,
          "lzNativeDropRecipient": "0x0000000000000000000000000000000000000000"
        },
        {  // Poly→Eth enforced options
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

With `"bidirectional": true`, this creates two pathways:
1. **Ethereum → Polygon**: 
   - Waits for 15 confirmations on Ethereum
   - Uses 250,000 gas for lzReceive (first element of enforcedOptions)
2. **Polygon → Ethereum**: 
   - Waits for 5 confirmations on Polygon
   - Uses 150,000 gas for lzReceive (second element of enforcedOptions)

### Bidirectional Flag

Set `"bidirectional": true` to automatically create reverse pathways. For example, if you define ethereum → arbitrum, it will also create arbitrum → ethereum with the same settings.

## Common DVN Names

These DVN names are automatically available from LayerZero's metadata:

- `LayerZero Labs` - Official LayerZero DVN
- `Google Cloud` - Google Cloud Oracle DVN  
- `Polyhedra` - Polyhedra zkBridge DVN
- `Horizen` - Horizen Labs DVN
- `Nethermind` - Nethermind DVN
- `BCW` - BCW Technologies DVN
- `Canary` - Canary DVN
- `TSS` - TSS DVN
- `Frax` - Frax Finance DVN
- `P2P` - P2P.org DVN
- `BWare` - BWare Labs DVN
- `Axelar` - Axelar DVN
- `Stargate` - Stargate DVN

And many more! Check `layerzero-dvns.json` for the complete list of available DVNs on each chain.

## Chain Names and EIDs

Common chain names and their endpoint IDs:

- `ethereum`: 30101
- `bsc`: 30102
- `avalanche`: 30106
- `polygon`: 30109
- `arbitrum`: 30110
- `optimism`: 30111
- `base`: 30184

## Example: Multi-Chain Setup

Here's an example wiring Ethereum, Arbitrum, and Base:

```json
{
  "chains": {
    "ethereum": {
      "eid": 30101,
      "rpc": "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xSIGNER1",
      "oapp": "0xOAPP_ON_ETHEREUM"
    },
    "arbitrum": {
      "eid": 30110,
      "rpc": "https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xSIGNER2",
      "oapp": "0xOAPP_ON_ARBITRUM"
    },
    "base": {
      "eid": 30184,
      "rpc": "https://base-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xSIGNER3",
      "oapp": "0xOAPP_ON_BASE"
    }
  },
  "pathways": [
    {
      "from": "ethereum",
      "to": "arbitrum",
      "requiredDVNs": ["LayerZero Labs"],
      "optionalDVNs": [],
      "optionalDVNThreshold": 0,
      "confirmations": [15, 10],
      "maxMessageSize": 10000
    },
    {
      "from": "ethereum",
      "to": "base",
      "requiredDVNs": ["LayerZero Labs"],
      "optionalDVNs": [],
      "optionalDVNThreshold": 0,
      "confirmations": [15, 3],
      "maxMessageSize": 10000
    },
    {
      "from": "arbitrum",
      "to": "base",
      "requiredDVNs": ["LayerZero Labs"],
      "optionalDVNs": [],
      "optionalDVNThreshold": 0,
      "confirmations": [10, 3],
      "maxMessageSize": 10000
    }
  ],
  "bidirectional": true
}
```

This configuration will create 6 pathways total (3 defined × 2 for bidirectional).

Note the confirmation values:
- `[15, 10]` for Ethereum ↔ Arbitrum means:
  - Ethereum → Arbitrum messages wait for 15 confirmations on Ethereum
  - Arbitrum → Ethereum messages wait for 10 confirmations on Arbitrum
- `[15, 3]` for Ethereum ↔ Base means:
  - Ethereum → Base messages wait for 15 confirmations on Ethereum
  - Base → Ethereum messages wait for 3 confirmations on Base
- `[10, 3]` for Arbitrum ↔ Base means:
  - Arbitrum → Base messages wait for 10 confirmations on Arbitrum
  - Base → Arbitrum messages wait for 3 confirmations on Base

## Example: Using Custom DVNs

If you need to use custom DVN addresses or override the defaults:

```json
{
  "chains": {
    "ethereum": {
      "eid": 30101,
      "rpc": "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xSIGNER",
      "oapp": "0xOAPP_ON_ETHEREUM"
    },
    "polygon": {
      "eid": 30109,
      "rpc": "https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "signer": "0xSIGNER",
      "oapp": "0xOAPP_ON_POLYGON"
    }
  },
  "dvns": {
    "My Custom DVN": {
      "ethereum": "0xCUSTOM_DVN_ADDRESS_ETHEREUM",
      "polygon": "0xCUSTOM_DVN_ADDRESS_POLYGON"
    }
  },
  "pathways": [
    {
      "from": "ethereum",
      "to": "polygon",
      "requiredDVNs": ["LayerZero Labs", "My Custom DVN"],
      "optionalDVNs": [],
      "optionalDVNThreshold": 0,
      "confirmations": [15, 5],
      "maxMessageSize": 10000
    }
  ],
  "bidirectional": true
}
```

## Example Configurations

### Simple Configuration

See `wire-config-simple.example.json` for a basic Ethereum ↔ Polygon pathway.

### Multiple Pathways

See `wire-config.example.json` for configuring multiple pathways between different chains.

### Custom DVNs

See `wire-config-with-overrides.example.json` for using custom DVN addresses not in LayerZero's metadata.

### Advanced Configuration

See `wire-config-advanced.example.json` for examples with:
- Compose message support (`lzComposeGas`, `lzComposeIndex`)
- Native token drops (`lzNativeDropAmount`, `lzNativeDropRecipient`)
- Message execution values (`lzReceiveValue`)
- Multiple pathway configurations

## Troubleshooting

1. **"Source deployment not found"**: Ensure the chain name in your config matches the deployment JSON
2. **"DVN address not found"**: Check that the DVN name and chain combination exists in your config
3. **Gas estimation errors**: Make sure your signers have sufficient native tokens on each chain
4. **RPC errors**: Verify your RPC URLs are correct and have sufficient rate limits

## Security Considerations

- Always verify DVN addresses before using in production
- Use hardware wallets or secure key management for production signers
- Test on testnets first before mainnet deployment
- Review all pathway configurations before broadcasting transactions 