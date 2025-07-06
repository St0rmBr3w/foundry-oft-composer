# WireOApp Script Usage Guide

This script automatically configures LayerZero V2 pathways between OApps on different chains.

## Prerequisites

1. Deploy your OApp contracts on all chains
2. Have access to RPC endpoints for all chains
3. Have a funded deployer wallet with gas on all chains

## Configuration

Create a wire configuration JSON file (e.g., `wire-config-base-arbitrum.json`):

```json
{
  "bidirectional": true,
  "chains": {
    "base": {
      "eid": 30184,
      "rpc": "https://base-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "oapp": "0x5fA90f40Ca1de9DBBceA4a0EA989A3C3C50556AE"
    },
    "arbitrum": {
      "eid": 30110,
      "rpc": "https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "oapp": "0x54FA38Cd89e7Ed1db4ecb7f38fA4c528A79b79B8"
    }
  },
  "pathways": [
    {
      "from": "base",
      "to": "arbitrum",
      "requiredDVNs": ["LayerZero Labs"],
      "optionalDVNs": [],
      "optionalDVNThreshold": 0,
      "confirmations": [3, 3],
      "maxMessageSize": 10000,
      "enforcedOptions": [
        {
          "lzReceiveGas": 200000,
          "lzReceiveValue": 0,
          "lzComposeGas": 0,
          "lzComposeIndex": 0,
          "lzNativeDropAmount": 0,
          "lzNativeDropRecipient": "0x0000000000000000000000000000000000000000"
        }
      ]
    }
  ]
}
```

## Usage

### 1. Check Current Configuration Status

First, check what's already configured without making any changes:

```bash
CHECK_ONLY=true PRIVATE_KEY=$YOUR_PRIVATE_KEY forge script script/WireOApp.s.sol:WireOApp \
  -s "run(string,string,string)" \
  "./script/wire-config-base-arbitrum.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  -vvv
```

### 2. Wire Pathways with Slow Mode (Recommended)

To avoid nonce issues, use the `--slow` flag:

```bash
PRIVATE_KEY=$YOUR_PRIVATE_KEY forge script script/WireOApp.s.sol:WireOApp \
  -s "run(string,string,string)" \
  "./script/wire-config-base-arbitrum.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --broadcast --slow -vvv
```

### 3. Resume Failed Broadcasts

If the script fails partway through, resume with:

```bash
PRIVATE_KEY=$YOUR_PRIVATE_KEY forge script script/WireOApp.s.sol:WireOApp \
  -s "run(string,string,string)" \
  "./script/wire-config-base-arbitrum.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --resume --slow -vvv
```

## Handling Nonce Issues

If you encounter "EOA nonce changed unexpectedly" errors:

### Recommended Solution: Use Separate Runs

The script provides separate functions to wire source and destination chains independently:

```bash
# Step 1: Wire all source chains
PRIVATE_KEY=$YOUR_PRIVATE_KEY forge script script/WireOApp.s.sol:WireOApp \
    -s "runSourceOnly(string,string,string)" \
    "./script/wire-config-base-arbitrum.json" \
    "./layerzero-deployments.json" \
    "./layerzero-dvns.json" \
    --broadcast --slow

# Step 2: Wire all destination chains 
PRIVATE_KEY=$YOUR_PRIVATE_KEY forge script script/WireOApp.s.sol:WireOApp \
    -s "runDestinationOnly(string,string,string)" \
    "./script/wire-config-base-arbitrum.json" \
    "./layerzero-deployments.json" \
    "./layerzero-dvns.json" \
    --broadcast --slow
```

This approach completely avoids nonce issues by keeping all transactions on the same chain within each run.

### Alternative Solutions

1. **Use `--slow` flag**: This ensures each transaction is mined before sending the next
2. **Use `--resume`**: If broadcast fails, use this to continue from where it left off
3. **Check gas prices**: Ensure you have sufficient gas and gas prices are reasonable

### Smart Configuration Updates

The script now includes intelligent configuration checking:

- **Automatic Skip**: Already-configured settings are automatically skipped
- **Configuration Comparison**: The script compares current vs desired configurations
- **Minimal Transactions**: Only sends transactions for configurations that need updates
- **Detailed Logging**: Shows which configurations are already set vs need updates

This significantly reduces the number of transactions and helps avoid nonce issues when re-running the script or recovering from partial failures.

## Configuration Fields

### Chain Configuration
- `eid`: LayerZero endpoint ID for the chain
- `rpc`: RPC URL for the chain
- `oapp`: Deployed OApp contract address on this chain

### Pathway Configuration
- `from`/`to`: Source and destination chain names
- `requiredDVNs`: Array of required DVN names (e.g., "LayerZero Labs")
- `optionalDVNs`: Array of optional DVN names
- `optionalDVNThreshold`: Number of optional DVNs that must verify
- `confirmations`: [srcToDestConfirmations, destToSrcConfirmations]
- `maxMessageSize`: Maximum message size in bytes
- `enforcedOptions`: Gas and value settings for message execution

### Enforced Options
- `lzReceiveGas`: Gas for standard message execution
- `lzReceiveValue`: ETH value for standard message
- `lzComposeGas`: Gas for composed message execution
- `lzComposeIndex`: Index for composed message
- `lzNativeDropAmount`: Amount of native token to drop
- `lzNativeDropRecipient`: Recipient for native drop

## DVN Selection

Common DVNs include:
- LayerZero Labs
- Google Cloud
- Polyhedra
- Nethermind
- Horizen
- BCW
- And many more...

Check `layerzero-dvns.json` for available DVNs on each chain.

## Troubleshooting

1. **"Required DVN not found"**: Check that the DVN name exactly matches what's in `layerzero-dvns.json`
2. **"Source/Destination deployment not found"**: Ensure the chain is in `layerzero-deployments.json`
3. **Transaction failures**: Check that your OApp contracts have the correct permissions and interfaces
4. **Gas estimation errors**: Ensure enforced options gas values are reasonable for your message handlers

## Security Considerations

1. Always verify configuration in check-only mode first
2. Use a secure method to provide your private key (environment variable, not hardcoded)
3. Double-check all addresses before broadcasting
4. Consider using a hardware wallet or multisig for production deployments

## DVN Configuration (Important!)

DVNs (Decentralized Verifier Networks) are chain-specific contracts that verify cross-chain messages. **Each chain has its own set of DVN addresses**, and they must be configured correctly:

- **Send Configuration**: Uses DVN addresses from the **source chain**
- **Receive Configuration**: Uses DVN addresses from the **destination chain**

For example, for a Base → Arbitrum pathway:
- Base send config uses Base's LayerZero Labs DVN address (e.g., `0x9e059a54699a285714207b43b055483e78faac25`)
- Arbitrum receive config uses Arbitrum's LayerZero Labs DVN address (e.g., `0x2f55c492897526677c5b68fb199ea31e2c126416`)

The script automatically resolves the correct chain-specific DVN addresses from the metadata.

## Configuration JSON Format 