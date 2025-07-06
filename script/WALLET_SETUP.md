# Wallet and RPC Setup Guide

This guide explains how to configure your wallet (private keys) and RPC endpoints for Foundry scripts.

## RPC Configuration

### Method 1: In Configuration Files
Update the RPC URLs directly in your configuration files:

```json
{
  "chains": {
    "base": {
      "rpc": "https://base-mainnet.g.alchemy.com/v2/YOUR_ACTUAL_API_KEY",
      // ... rest of config
    }
  }
}
```

### Method 2: Environment Variables
Create a `.env` file in your project root:

```bash
# .env
BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY
ETHEREUM_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY
OPTIMISM_RPC_URL=https://opt-mainnet.g.alchemy.com/v2/YOUR_API_KEY
```

Then load it before running scripts:
```bash
source .env
```

## Private Key Management

### Method 1: Environment Variable (Recommended for Scripts)

Set your private key as an environment variable:

```bash
# For a single session
export PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE

# Or in your .env file
PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE
```

Then use in your forge script command:
```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "deploy-config.json" \
  "layerzero-deployments.json" \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Method 2: Foundry Keystore (Most Secure)

Import your private key into Foundry's encrypted keystore:

```bash
# Import a private key with a name
cast wallet import deployer --interactive

# You'll be prompted to:
# 1. Enter your private key
# 2. Set a password for encryption
```

List your accounts:
```bash
cast wallet list
```

Use the keystore account in scripts:
```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "deploy-config.json" \
  "layerzero-deployments.json" \
  --account deployer \
  --password-file .password \
  --broadcast
```

### Method 3: Hardware Wallet (Ledger/Trezor)

For Ledger:
```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "deploy-config.json" \
  "layerzero-deployments.json" \
  --ledger \
  --hd-paths "m/44'/60'/0'/0/0" \
  --broadcast
```

### Method 4: Interactive Private Key Input

You can also input the private key interactively:
```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "deploy-config.json" \
  "layerzero-deployments.json" \
  --interactive \
  --broadcast
```

## Complete Example Setup

### 1. Create `.env` file:
```bash
# RPC URLs
BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY

# Private Keys (use keystore for production!)
DEPLOYER_KEY=0xYOUR_PRIVATE_KEY
```

### 2. Add to `.gitignore`:
```bash
echo ".env" >> .gitignore
echo ".password" >> .gitignore
```

### 3. Load environment:
```bash
source .env
```

### 4. Update your config files:
```json
{
  "chains": {
    "base": {
      "eid": 30184,
      "rpc": "https://base-mainnet.g.alchemy.com/v2/YOUR_ACTUAL_KEY",
      "deployer": "0xYOUR_DEPLOYER_ADDRESS"
    }
  }
}
```

Note: The "deployer" or "signer" address in the config should be the public address corresponding to your private key.

### 5. Run deployment:
```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "deploy-config.json" \
  "layerzero-deployments.json" \
  --private-key $DEPLOYER_KEY \
  --via-ir \
  --broadcast
```

## Getting Your Signer Address

To get the address from your private key:

```bash
# If you have the private key
cast wallet address --private-key 0xYOUR_PRIVATE_KEY

# If using keystore
cast wallet address --account deployer
```

## Security Best Practices

1. **Never commit private keys** to version control
2. **Use keystore or hardware wallets** for production
3. **Use different keys** for testnet and mainnet
4. **Store passwords securely** (consider using a password manager)
5. **Use read-only RPCs** when possible for querying
6. **Rotate keys regularly** for active signers

## Testnet Configuration

For testing, you can use public testnet RPCs:

```json
{
  "chains": {
    "base-sepolia": {
      "eid": 40245,
      "rpc": "https://sepolia.base.org",
      "deployer": "0xYOUR_TEST_ADDRESS"
    },
    "arbitrum-sepolia": {
      "eid": 40231,
      "rpc": "https://sepolia-rollup.arbitrum.io/rpc",
      "deployer": "0xYOUR_TEST_ADDRESS"
    }
  }
}
```

## Troubleshooting

### "Insufficient funds" error
- Check that your signer address has enough native tokens (ETH, etc.)
- Verify you're using the correct address

### "Invalid private key" error
- Ensure your private key starts with `0x`
- Check that it's 64 characters long (excluding 0x)

### "RPC error" 
- Verify your RPC URL is correct
- Check API key limits haven't been exceeded
- Try a different RPC provider 