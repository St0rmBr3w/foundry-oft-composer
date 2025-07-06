# SendOFT Script

This script allows you to send OFT tokens across chains using LayerZero V2.

## Prerequisites

1. Ensure your OFT is deployed on both source and destination chains
2. Ensure you have sufficient native tokens for gas fees on the source chain
3. Have your private key ready

## Usage

### Basic Send

Send tokens in smallest unit (wei):

```bash
forge script script/SendOFT.s.sol:SendOFT \
    --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
    OFTADDRESS DSTEID TO AMOUNT MINAMOUNT 0x 0x 0x \
    --broadcast \
    --rpc-url YOUR_RPC_URL \
    --private-key YOUR_PRIVATE_KEY
```

### Parameters

- `OFTADDRESS`: Address of the OFT contract on source chain
- `DSTEID`: Destination endpoint ID (e.g., 30106 for Avalanche)
- `TO`: Recipient address in bytes32 format (use `0x000000000000000000000000` + address without 0x)
- `AMOUNT`: Amount to send in smallest unit (wei)
- `MINAMOUNT`: Minimum amount to receive (use 0 for no slippage protection)
- `extraOptions`: Additional options (use `0x` for default)
- `composeMsg`: Compose message (use `0x` for none)
- `oftCmd`: OFT command (use `0x` for none)

### Examples

1. **Send 1 token (assuming 18 decimals) from Arbitrum to Base:**
```bash
forge script script/SendOFT.s.sol:SendOFT \
    --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
    0x1234567890123456789012345678901234567890 \
    30184 \
    0x000000000000000000000000YourRecipientAddressWithout0x \
    1000000000000000000 \
    0 \
    0x \
    0x \
    0x \
    --broadcast \
    --rpc-url https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY \
    --private-key $PRIVATE_KEY
```

2. **Send with custom gas limit:**
```bash
# First create the options bytes
# This example sets 500,000 gas for lzReceive
OPTIONS=0x00030100110100000000000000000000000000000000000000000000000000000007a120

forge script script/SendOFT.s.sol:SendOFT \
    --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
    0x1234567890123456789012345678901234567890 \
    30184 \
    0x000000000000000000000000YourRecipientAddressWithout0x \
    1000000000000000000 \
    0 \
    $OPTIONS \
    0x \
    0x \
    --broadcast \
    --rpc-url https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY \
    --private-key $PRIVATE_KEY
```

## Helper Function

The script includes a helper function to convert addresses to bytes32 format:
```solidity
function addressToBytes32(address addr) internal pure returns (bytes32)
```

You can use this in your own scripts or call it separately to prepare addresses.

## Common Endpoint IDs

- Ethereum: 30101
- BSC: 30102
- Avalanche: 30106
- Polygon: 30109
- Arbitrum: 30110
- Optimism: 30111
- Base: 30184

## Troubleshooting

1. **Insufficient gas**: Increase the gas limit in extraOptions
2. **Invalid recipient**: Ensure the recipient address is properly formatted as bytes32
3. **Amount too high**: Check your token balance
4. **Min amount error**: Set minAmount to 0 or calculate appropriate slippage 