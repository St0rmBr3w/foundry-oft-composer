# MyOFT Deployment Guide

This guide explains how to deploy MyOFT contracts across multiple chains using the deployment scripts.

## Overview

The deployment script is fully data-driven through JSON configuration files. All deployment parameters including chain details, RPC endpoints, LayerZero endpoints, and deployer addresses are specified in the configuration file.

## Configuration Format

Create a deployment configuration JSON file with the following structure:

```json
{
  "tokenName": "My Omnichain Token",
  "tokenSymbol": "MYOFT",
  "chains": [
    {
      "name": "base",
      "eid": 30184,
      "rpc": "https://base.gateway.tenderly.co",
      "deployer": "0xYourDeployerAddress",
      "lzEndpoint": "0x1a44076050125825900e736c501f859c50fE728c"
    },
    {
      "name": "arbitrum",
      "eid": 30110,
      "rpc": "https://arbitrum.gateway.tenderly.co",
      "deployer": "0xYourDeployerAddress",
      "lzEndpoint": "0x1a44076050125825900e736c501f859c50fE728c"
    }
  ]
}
```

### Configuration Fields

- `tokenName`: The name of your OFT token
- `tokenSymbol`: The symbol of your OFT token
- `chains`: Array of chain configurations
  - `name`: Human-readable chain name
  - `eid`: LayerZero endpoint ID for the chain
  - `rpc`: RPC URL for the chain
  - `deployer`: Address that will deploy and own the OFT
  - `lzEndpoint`: LayerZero V2 endpoint address on this chain

## Finding LayerZero Endpoints

You can find the correct LayerZero endpoint addresses:
1. From the [LayerZero documentation](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts)
2. From the downloaded `layerzero-deployments.json` file (see Wire OApp documentation)

### Common Mainnet Endpoints
- Most EVM chains: `0x1a44076050125825900e736c501f859c50fE728c`

### Common Testnet Endpoints
- Most testnets: `0x6EDCE65403992e310A62460808c4b910D972f10f`

## Deployment Steps

### 1. Prepare Configuration

Create your deployment configuration file (e.g., `deploy.config.json`) with your specific parameters.

Example configurations are provided:
- `deploy-config-base-arbitrum.json` - Mainnet deployment example
- `deploy-config-testnet.json` - Testnet deployment example

### 2. Set Up Environment

Ensure you have:
- Private keys or hardware wallet configured (see WALLET_SETUP.md)
- Sufficient native tokens on each chain for deployment
- RPC endpoints configured

### 3. Run Deployment

Deploy to all chains in your configuration:

```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string)" \
  "deploy.config.json" \
  --via-ir \
  --broadcast
```

For testnet deployment:

```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string)" \
  "deploy-config-testnet.json" \
  --via-ir \
  --broadcast
```

### 4. Verify Deployment

The script will:
1. Deploy MyOFT to each chain specified in the configuration
2. Display deployment addresses in the console
3. Save deployment addresses to `deployments/myoft-deployments.json`

## Output Format

The deployment script saves addresses in the following format:

```json
{
  "base": {
    "oft": "0xDeployedOFTAddress",
    "eid": 30184,
    "lzEndpoint": "0x1a44076050125825900e736c501f859c50fE728c"
  },
  "arbitrum": {
    "oft": "0xDeployedOFTAddress",
    "eid": 30110,
    "lzEndpoint": "0x1a44076050125825900e736c501f859c50fE728c"
  }
}
```

## Next Steps

After deployment:
1. Wire the OApp pathways using the WireOApp script (see WIRE_OAPP_README.md)
2. Verify contracts on block explorers if needed
3. Test cross-chain transfers

## Adding More Chains

To deploy to additional chains, simply add more entries to the `chains` array in your configuration file. The script automatically handles any number of chains.

## Security Considerations

- Never commit files containing private keys or sensitive RPC URLs
- Use environment variables or secure key management for production deployments
- Always test on testnets first
- Verify all addresses and parameters before mainnet deployment 