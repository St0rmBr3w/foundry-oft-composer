<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/logo-dark.svg"/>
  </a>
</p>

<p align="center">
  <a href="https://docs.layerzero.network/v2">Developer Docs</a> | <a href="https://layerzero.network">Website</a>
</p>

# LayerZero OFT Example with Foundry

This example demonstrates how to deploy and use an Omnichain Fungible Token (OFT) using LayerZero V2 with Foundry. Learn how to deploy tokens that can seamlessly move across multiple blockchains while maintaining a unified supply.

## Table of Contents

- [Prerequisite Knowledge](#prerequisite-knowledge)
- [Requirements](#requirements)
- [Setup](#setup)
- [Build](#build)
- [Deploy](#deploy)
- [Enable Messaging](#enable-messaging)
- [Sending Tokens](#sending-tokens)
- [Next Steps](#next-steps)
- [Production Deployment Checklist](#production-deployment-checklist)
- [Appendix](#appendix)
  - [Running Tests](#running-tests)
  - [Adding Other Chains](#adding-other-chains)
  - [Using Multisigs](#using-multisigs)
  - [Helper Scripts](#helper-scripts)
  - [Contract Verification](#contract-verification)
  - [Troubleshooting](#troubleshooting)

## Prerequisite Knowledge

Before running this example, you should understand:
- **[What is an OApp?](https://docs.layerzero.network/v2/home/protocol/oapp-overview)** - Omnichain Applications enable cross-chain messaging
- **[What is an OFT?](https://docs.layerzero.network/v2/home/token-standards/oft-quickstart)** - Omnichain Fungible Tokens can move seamlessly between blockchains
- **[LayerZero Terminology](https://docs.layerzero.network/v2/home/glossary)** - Key concepts like Endpoint IDs, DVNs, and Pathways

## Requirements

- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** - Latest version
- **[Git](https://git-scm.com/downloads)** - For dependency management  
- **[Node.js & pnpm](https://pnpm.io/installation)** (optional) - For helper scripts
- **Testnet Tokens** - Native tokens on Base Sepolia and Arbitrum Sepolia for gas fees

## Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd foundry-vanilla
   ```

2. **Install dependencies**
   ```bash
   forge install
   ```

3. **Configure environment**
   
   Create a `.env` file:
   ```bash
   cp .env.example .env
   ```
   
   Add your private key and RPC URLs:
   ```env
   PRIVATE_KEY=your_private_key_here
   BASE_RPC_URL=https://base-sepolia.gateway.tenderly.co
   ARBITRUM_RPC_URL=https://arbitrum-sepolia.gateway.tenderly.co
   ```

4. **Download LayerZero metadata**
   ```bash
   # Download deployment addresses and DVN configurations
   curl -o layerzero-deployments.json https://raw.githubusercontent.com/LayerZero-Labs/devtools/main/packages/ua-utils-evm-hardhat/layerzero.mainnet.json
   curl -o layerzero-dvns.json https://raw.githubusercontent.com/LayerZero-Labs/layerzero-scan-api/main/deployments/mainnet/dvn.json
   ```

   > 💡 **Helper Scripts Available**: See [Helper Scripts](#helper-scripts) section for automated deployment and wiring tools.

## Build

Compile the contracts with the Solidity optimizer:

```bash
forge build --via-ir
```

> Note: The `--via-ir` flag is required due to contract complexity with LayerZero and Uniswap dependencies.

## Deploy

Deploy MyOFT to Base and Arbitrum testnets:

```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "script/deploy-config.json" \
  "layerzero-deployments.json" \
  --via-ir --broadcast --multi
```

This will:
1. Deploy MyOFT on both chains configured in `deploy-config.json`
2. Save deployment addresses to `deployments/` directory
3. Mint initial supply to the deployer (if configured)

## Enable Messaging

After deployment, wire the LayerZero pathways to enable cross-chain transfers:

```bash
forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string,string,string)" \
  "script/wire-config.json" \
  "layerzero-deployments.json" \
  "layerzero-dvns.json" \
  --via-ir --broadcast --slow
```

This configures:
- [Endpoint IDs](https://docs.layerzero.network/v2/home/glossary#endpoint-id) for source and destination chains
- [DVNs](https://docs.layerzero.network/v2/home/glossary#decentralized-verifier-network-dvn) (Decentralized Verifier Networks) for message verification
- [Enforced Options](https://docs.layerzero.network/v2/home/glossary#enforced-options) for gas limits and security

> Note: Use `--slow` flag to avoid nonce issues when broadcasting to multiple chains.

## Sending Tokens

Send OFT tokens from Base to Arbitrum:

```bash
forge script script/SendOFT.s.sol:SendOFT \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  <OFT_ADDRESS_ON_BASE> \
  30110 \
  0x000000000000000000000000<RECIPIENT_ADDRESS> \
  1000000000000000000 \
  0 \
  0x \
  0x \
  0x \
  --rpc-url $BASE_RPC_URL \
  --broadcast
```

Parameters:
- `OFT_ADDRESS_ON_BASE`: Your deployed OFT contract on Base
- `30110`: Arbitrum's [Endpoint ID](https://docs.layerzero.network/v2/home/glossary#endpoint-id)
- `RECIPIENT_ADDRESS`: Destination address (padded to bytes32)
- `1000000000000000000`: Amount in wei (1 token with 18 decimals)
- `0`: Minimum amount to receive (no slippage protection)

## Next Steps

After completing this example:
1. Review the [Production Deployment Checklist](#production-deployment-checklist)
2. Configure [DVN Security Stack](https://docs.layerzero.network/v2/home/modular-security/security-stack-dvns) for mainnet
3. Implement [Message Options](https://docs.layerzero.network/v2/developers/evm/gas-settings/options) for advanced features

## Production Deployment Checklist

Before mainnet deployment:

- [ ] **Gas Profiling**: Run `forge test --gas-report` to optimize gas usage
- [ ] **DVN Configuration**: Use multiple DVNs for enhanced security (see `wire-config.json`)
- [ ] **Confirmation Settings**: Adjust block confirmations based on chain finality
- [ ] **Enforced Options**: Set appropriate gas limits for destination chains
- [ ] **Audit**: Complete security audit of custom logic
- [ ] **Monitoring**: Set up [LayerZero Scan](https://layerzeroscan.com) alerts

## Appendix

### Running Tests

Run the test suite:

```bash
forge test --via-ir -vvv
```

For gas profiling:
```bash
forge test --gas-report --via-ir
```

### Adding Other Chains

To expand beyond Base and Arbitrum:

1. Add chain configuration to `deploy-config.json`:
   ```json
   {
     "chains": {
       "optimism": {
         "eid": 30111,
         "rpc": "https://optimism-sepolia.gateway.tenderly.co",
         "oapp": "0x0000000000000000000000000000000000000000"
       }
     }
   }
   ```

2. Update `wire-config.json` with new pathways
3. Redeploy and rewire contracts

### Using Multisigs

Deploy with a multisig wallet:

```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string,string)" \
  "script/deploy-config.json" \
  "layerzero-deployments.json" \
  --via-ir \
  --sender <MULTISIG_ADDRESS> \
  --broadcast
```

Note: Transaction execution varies by multisig provider (Safe, Gnosis, etc.)

### Helper Scripts

This example includes several helper scripts:

**Wire Script** (`script/WireOApp.s.sol`):
- Automatically configures LayerZero pathways
- Sets up DVNs and security parameters
- See [WIRE_OAPP_README.md](WIRE_OAPP_README.md) for details

**Send Script** (`script/SendOFT.s.sol`):
- Simplifies cross-chain token transfers
- Handles fee calculation automatically
- See [SEND_OFT_README.md](SEND_OFT_README.md) for details

**Deploy Script** (`script/DeployMyOFT.s.sol`):
- Multi-chain deployment in one transaction
- Saves deployment artifacts
- Supports various configuration options

### Contract Verification

Verify contracts on Etherscan:

```bash
forge verify-contract \
  --chain-id 84532 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(string,string,address,address)" "MyOFT" "MOFT" <ENDPOINT> <OWNER>) \
  --compiler-version v0.8.22 \
  <CONTRACT_ADDRESS> \
  src/MyOFT.sol:MyOFT
```

For detailed verification steps, see [Foundry verification docs](https://book.getfoundry.sh/reference/forge/forge-verify-contract).

### Troubleshooting

Common issues and solutions:

**Stack too deep errors**
- Always use `--via-ir` flag when building or deploying

**Nonce issues during multi-chain deployment**
- Use `--slow` flag or deploy chains separately with `runSourceOnly`/`runDestinationOnly`

**DVN configuration errors**
- Ensure DVN addresses match the deployment chain (Base DVNs for Base, Arbitrum DVNs for Arbitrum)
- Check that DVNs are not deprecated in `layerzero-dvns.json`

**Insufficient gas errors**
- Increase `lzReceiveGas` in enforced options (default: 200,000)
- Add buffer for complex operations

For more help, see the [LayerZero Troubleshooting Guide](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages).
