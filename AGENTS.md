# AGENTS.md - Foundry Vanilla OFT Example

This file provides specific guidance for AI agents working on the **foundry-vanilla** LayerZero OFT example project.

## Project Overview

This is a **Foundry-based** example demonstrating LayerZero V2 Omnichain Fungible Tokens (OFT) with:
- Automated address resolution from LayerZero metadata
- JSON-based configuration files
- Three-step workflow: deploy → wire → send
- Pure Solidity scripts (no external dependencies)

## Key Implementation Details

### Configuration Files
- **`utils/deploy.config.json`**: Token deployment configuration using chain names
- **`utils/layerzero.config.json`**: Pathway wiring configuration using chain names
- **`layerzero-deployments.json`**: Downloaded LayerZero contract addresses
- **`layerzero-dvns.json`**: Downloaded DVN metadata

### Scripts
- **`script/DeployMyOFT.s.sol`**: Deploys OFT to multiple chains
- **`script/WireOApp.s.sol`**: Configures LayerZero pathways between OApps
- **`script/SendOFT.s.sol`**: Sends tokens cross-chain

### Key Features
- Uses **chain names** (not chain IDs) in configuration files
- Automatically resolves LayerZero addresses from metadata
- Supports bidirectional pathway configuration
- Includes partial wiring functions for large deployments
- Provides check-only mode for validation

## Agent Guidelines

### When Making Changes

1. **Configuration Files**: Always use chain names (e.g., "base", "arbitrum") not chain IDs
2. **Script Parameters**: Maintain the current parameter structure and order
3. **Console Output**: Use the existing ConsoleUtils library for consistent formatting
4. **Error Handling**: Follow the existing pattern of detailed error messages

### Documentation Updates

When updating README files:
1. Follow the LayerZero example best practices structure
2. Use the exact section headings from the template
3. Link to LayerZero documentation for concepts
4. Include practical examples with real addresses
5. Maintain consistency across all README files

### Code Style

- Use Foundry's `vm.parseJson*` functions for JSON parsing
- Follow Solidity best practices for gas optimization
- Include comprehensive error messages
- Use the ConsoleUtils library for formatted output

### Testing

- Ensure all scripts compile without warnings
- Test configuration parsing with sample JSON files
- Verify address resolution works correctly
- Check that console output is properly formatted

## Common Patterns

### JSON Configuration Structure
```json
{
  "chains": {
    "chainName": {
      "eid": 30184,
      "rpc": "https://rpc.url",
      "signer": "WILL_USE_PRIVATE_KEY",
      "oapp": "0x..."
    }
  },
  "pathways": [
    {
      "from": "chainName",
      "to": "chainName",
      "requiredDVNs": ["LayerZero Labs"],
      "confirmations": [3, 5],
      "enforcedOptions": [...]
    }
  ]
}
```

### Script Function Signatures
```solidity
function run(string memory configPath, string memory deploymentJsonPath, string memory dvnJsonPath) external
function runSourceOnly(string memory configPath, string memory deploymentJsonPath, string memory dvnJsonPath) external
function runDestinationOnly(string memory configPath, string memory deploymentJsonPath, string memory dvnJsonPath) external
```

### Console Output Format
```solidity
printHeader("LAYERZERO WIRE SCRIPT");
printSubHeader("Configuring Pathways");
printSuccess("Pathway configured successfully");
printWarning("Optional DVN not found");
printError("Required DVN not found");
```

## Troubleshooting Guide

### Common Issues
1. **DVN Resolution**: Ensure DVN names match exactly from metadata
2. **Nonce Issues**: Use `--slow` flag or partial wiring functions
3. **Configuration**: Validate JSON structure before running scripts
4. **Address Format**: Use bytes32 format for recipients in SendOFT

### Validation Commands
```bash
# Check configuration without making changes
CHECK_ONLY=true forge script script/WireOApp.s.sol:WireOApp ...

# Validate JSON structure
jq . utils/layerzero.config.json

# Check script compilation
forge build --via-ir
```

## References

- [LayerZero V2 Documentation](https://docs.layerzero.network/v2)
- [Foundry Book](https://book.getfoundry.sh/)
- [LayerZero Glossary](https://docs.layerzero.network/v2/home/glossary)
- [OFT Quickstart](https://docs.layerzero.network/v2/home/token-standards/oft-quickstart) 