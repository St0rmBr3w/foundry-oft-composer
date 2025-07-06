<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/logo-dark.svg"/>
  </a>
</p>

<p align="center">
  <a href="https://docs.layerzero.network/v2">Developer Docs</a> | <a href="https://layerzero.network">Website</a>
</p>

# Send OFT Script

Simplify cross-chain OFT token transfers with automatic fee calculation and transaction execution.

## Table of Contents

- [Prerequisite Knowledge](#prerequisite-knowledge)
- [Requirements](#requirements)
- [Basic Usage](#basic-usage)
- [Parameters](#parameters)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## Prerequisite Knowledge

Before using this script, understand:
- **[What is an OFT?](https://docs.layerzero.network/v2/home/token-standards/oft-quickstart)** - Omnichain Fungible Tokens
- **[Endpoint IDs](https://docs.layerzero.network/v2/home/glossary#endpoint-id)** - Chain identifiers in LayerZero
- **[Message Options](https://docs.layerzero.network/v2/developers/evm/gas-settings/options)** - Gas and execution settings

## Requirements

- Deployed and wired OFT contracts on source and destination chains
- Private key with token balance on source chain
- Native tokens for gas fees
- RPC access to source chain

## Basic Usage

Send OFT tokens across chains:

```bash
forge script script/SendOFT.s.sol:SendOFT \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  <OFT_ADDRESS> \
  <DESTINATION_EID> \
  <RECIPIENT_BYTES32> \
  <AMOUNT_WEI> \
  <MIN_AMOUNT_WEI> \
  0x \
  0x \
  0x \
  --rpc-url <SOURCE_RPC_URL> \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Parameters

1. **`oftAddress`** - OFT contract address on source chain
2. **`dstEid`** - Destination chain [Endpoint ID](https://docs.layerzero.network/v2/home/glossary#endpoint-id)
3. **`to`** - Recipient address in bytes32 format (pad with zeros)
4. **`amountLD`** - Amount to send in smallest unit (wei)
5. **`minAmountLD`** - Minimum amount to receive (slippage protection)
6. **`extraOptions`** - Additional [message options](https://docs.layerzero.network/v2/developers/evm/gas-settings/options) (use `0x` for defaults)
7. **`composeMsg`** - Compose message for receiver contracts (use `0x` if not needed)
8. **`oftCmd`** - OFT command for advanced features (use `0x` for standard transfer)

## Examples

### Send 1.5 tokens from Base to Arbitrum

```bash
forge script script/SendOFT.s.sol:SendOFT \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  0x88661aCB7BBa48A2987A8637c8CbA8973d52DE9e \
  30110 \
  0x000000000000000000000000ed422098669cBB60CAAf26E01485bAFdbAF9eBEA \
  1500000000000000000 \
  1500000000000000000 \
  0x \
  0x \
  0x \
  --rpc-url https://base.gateway.tenderly.co \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Send with custom gas limit

```bash
# Create extra options for 300k gas
EXTRA_OPTIONS=$(cast abi-encode "f(uint16,uint256)" 3 300000)

forge script script/SendOFT.s.sol:SendOFT \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  0x88661aCB7BBa48A2987A8637c8CbA8973d52DE9e \
  30110 \
  0x000000000000000000000000ed422098669cBB60CAAf26E01485bAFdbAF9eBEA \
  1000000000000000000 \
  1000000000000000000 \
  $EXTRA_OPTIONS \
  0x \
  0x \
  --rpc-url https://base.gateway.tenderly.co \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Common Endpoint IDs

| Chain | Mainnet | Testnet |
|-------|---------|---------|
| Ethereum | 30101 | 40161 |
| Base | 30184 | 40245 |
| Arbitrum | 30110 | 40231 |
| Optimism | 30111 | 40232 |

See full list in the [LayerZero documentation](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts).

## Troubleshooting

### "Insufficient token balance"

The script uses your signer address (from private key). Ensure this address holds tokens:
```bash
cast call <OFT_ADDRESS> "balanceOf(address)" <YOUR_ADDRESS> --rpc-url <RPC_URL>
```

### "Quote failed" or DVN errors

This indicates misconfigured pathways. Check:
1. OFT is properly wired (peers, DVNs, enforced options)
2. DVN addresses are correct for each chain
3. Endpoint addresses are valid

### "Insufficient fee"

The script automatically calculates fees. If this fails:
1. Ensure you have enough native tokens for gas
2. Try increasing gas limits in extra options
3. Check if enforced options are set correctly

### Address format

Recipient must be bytes32 format. Convert addresses:
```solidity
// Solidity
bytes32 recipient = bytes32(uint256(uint160(address)));

// Bash
RECIPIENT=0x000000000000000000000000<ADDRESS_WITHOUT_0x>
```

## Notes

- Always verify token arrived on destination chain
- Monitor transactions on [LayerZero Scan](https://layerzeroscan.com)
- For production, implement proper error handling and monitoring
- Consider using time-based slippage protection for large transfers 