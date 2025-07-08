<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/logo-dark.svg"/>
  </a>
</p>

<p align="center">
  <a href="https://docs.layerzero.network/v2">Developer Docs</a> | <a href="https://layerzero.network">Website</a>
</p>

# LayerZero OFT Example with Foundry

Deploy and use Omnichain Fungible Tokens (OFT) with LayerZero V2 using Foundry. This example demonstrates a complete **deploy → wire → send** workflow with automated address resolution from LayerZero metadata.

## Table of Contents

- [Prerequisite Knowledge](#prerequisite-knowledge)
- [Requirements](#requirements)
- [Setup](#setup)
- [Build](#build)
- [Deploy](#deploy)
- [Enable Messaging](#enable-messaging)
- [Sending OFT](#sending-oft)
- [Next Steps](#next-steps)
- [Production Deployment Checklist](#production-deployment-checklist)
- [Appendix](#appendix)

## Prerequisite Knowledge

Before running this example, you should understand:
- **[What is an OApp?](https://docs.layerzero.network/v2/home/protocol/oapp-overview)** - Omnichain Applications enable cross-chain messaging
- **[What is an OFT?](https://docs.layerzero.network/v2/home/token-standards/oft-quickstart)** - Omnichain Fungible Tokens can move seamlessly between blockchains
- **[LayerZero Terminology](https://docs.layerzero.network/v2/home/glossary)** - Key concepts like [Endpoint IDs](https://docs.layerzero.network/v2/home/glossary#endpoint-id), [DVNs](https://docs.layerzero.network/v2/home/glossary#data-validation-network-dvn), and [Pathways](https://docs.layerzero.network/v2/home/glossary#pathway)

## Requirements

- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** - Latest version
- **[Git](https://git-scm.com/downloads)** - For dependency management  
- **Private key** - Funded with native tokens on Base and Arbitrum (or your chosen chains)
- **RPC URLs** - Access to blockchain nodes

## Setup

1. **Clone and setup dependencies:**
```bash
git clone <repository-url>
cd foundry-vanilla
forge install
```

2. **Download LayerZero metadata:**
```bash
./utils/download-deployments.sh
```

This downloads the latest LayerZero contract addresses and DVN configurations to `layerzero-deployments.json` and `layerzero-dvns.json`.

3. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your private key and RPC URLs
```

4. **Update configuration files:**
   - Edit `utils/deploy.config.json` with your token details and chain info
   - Edit `utils/layerzero.config.json` with your deployed OApp addresses and pathway settings

## Build

```bash
forge build --via-ir
```

## Deploy

Deploy your OFT to multiple chains:

```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string)" \
  "utils/deploy.config.json" \
  --via-ir --broadcast
```

This script:
- Reads your token configuration from `deploy.config.json`
- Automatically looks up LayerZero endpoint addresses from downloaded metadata
- Deploys MyOFT to all specified chains
- Saves deployment addresses to `deployments/` directory

**Helper Tasks:** See [LayerZero Hardhat Helper Tasks](#layerzero-hardhat-helper-tasks-detailed) for additional deployment options.

## Enable Messaging

Wire LayerZero pathways between your deployed OApps:

```bash
forge script script/WireOApp.s.sol:WireOApp \
  -s "run(string,string,string)" \
  "./utils/layerzero.config.json" \
  "./layerzero-deployments.json" \
  "./layerzero-dvns.json" \
  --broadcast --slow --multi -vvv
```

This script:
- Reads your pathway configuration from `layerzero.config.json`
- Automatically resolves DVN names to chain-specific addresses from `layerzero-dvns.json`
- Sets up peers between OApps on different chains
- Configures security settings (DVNs, confirmations)
- Sets enforced gas options for cross-chain messages

> **Note:** Use `--slow` flag to avoid nonce issues when configuring multiple chains.

**Helper Tasks:** See [LayerZero Hardhat Helper Tasks](#layerzero-hardhat-helper-tasks-detailed) for partial wiring options.

## Sending OFT

Send tokens cross-chain using the deployed OFT:

```bash
forge script script/SendOFT.s.sol:SendOFT \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  0xYourOFT \              # OFT address on source chain
  30110 \                  # Destination endpoint ID
  0x000...recipient \      # Recipient (bytes32 format)
  1000000000000000000 \    # Amount (1 token = 1e18 wei)
  0 \                      # Min amount (slippage)
  0x \                     # Extra options
  0x \                     # Compose message
  0x \                     # OFT command
  --broadcast \
  -vvv --rpc-url $RPC_URL --via-ir
```

**Example sending from Base to Arbitrum:**
```bash
forge script script/SendOFT.s.sol:SendOFT \
  --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
  0x520e5A32984b1e378f0A1C478C4cE083275643DC \
  30110 \
  0x000000000000000000000000ed422098669cBB60CAAf26E01485bAFdbAF9eBEA \
  15000000000000 \
  0 \
  0x \
  0x \
  0x \
  --broadcast \
  -vvv --rpc-url $RPC_URL --via-ir
```

## Next Steps

After completing this example:
1. Review the [Production Deployment Checklist](#production-deployment-checklist)
2. Configure [DVN Security Stack](https://docs.layerzero.network/v2/home/modular-security/security-stack-dvns) for mainnet
3. Implement [Message Options](https://docs.layerzero.network/v2/developers/evm/gas-settings/options) for advanced features
4. Monitor your messages on [LayerZero Scan](https://layerzeroscan.com)

## Production Deployment Checklist

Before mainnet deployment:

- [ ] **Gas Profiling**: Run `forge test --gas-report` to optimize gas usage
- [ ] **Multi-DVN Security**: Use 2-3 required DVNs for production
- [ ] **Confirmation Settings**: Adjust based on chain finality (ETH: 15, L2s: 10-100)
- [ ] **Enforced Options**: Set appropriate gas limits per message type
- [ ] **Rate Limiting**: Implement rate limits for large transfers
- [ ] **Monitoring**: Set up alerts on LayerZero Scan
- [ ] **Audit**: Complete security audit of custom logic

## Appendix

### Running Tests

```bash
forge test --via-ir -vvv
```

### Adding Other Chains

1. Find chain info in [LayerZero docs](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts)
2. Add to `utils/deploy.config.json` and `utils/layerzero.config.json`
3. Ensure you have gas tokens on the new chain
4. Re-run deploy and wire scripts

### Using Multisigs

For multisig deployments, modify the scripts to use your multisig address instead of the private key signer. The configuration files remain the same.

### LayerZero Hardhat Helper Tasks (detailed)

The project includes several helper functions in `WireOApp.s.sol`:

- `runSourceOnly()` - Wire only source chain configurations
- `runDestinationOnly()` - Wire only destination chain configurations
- `preflightCheck()` - Check current configuration status

**Built-in Foundry tasks:**
- `forge script` - Run deployment and configuration scripts
- `forge test` - Run test suite
- `forge build` - Compile contracts

### Contract Verification

Verify your deployments on block explorers:

- **Base**: Use [Basescan](https://basescan.org) verification
- **Arbitrum**: Use [Arbiscan](https://arbiscan.io) verification

### Troubleshooting

**"DVN not found"**
- Ensure DVN name matches exactly from `layerzero-dvns.json`
- Check DVN is available on your chain
- Verify DVN isn't deprecated

**"Insufficient fee"**
- Increase gas limits in enforced options
- Ensure you have enough native tokens
- Check if options are properly encoded

**Nonce issues**
- Use `--slow` flag for multi-chain operations
- Or use `runSourceOnly` / `runDestinationOnly` functions
- Wait for transactions to confirm between chains

For more help, see the [LayerZero Troubleshooting Guide](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages).

---

**Feedback:** We welcome feedback from partners to improve this example. Please reach out through our [Discord](https://discord.gg/layerzero) or [GitHub issues](https://github.com/LayerZero-Labs/solidity-examples/issues).
