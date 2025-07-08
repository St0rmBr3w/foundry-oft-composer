# Foundry Vanilla Project - Agent Instructions

This directory contains a Foundry-based LayerZero OApp project with scripts for deployment and configuration.

## Key Scripts

### 1. DeployMyOFT.s.sol
- Deploys the MyOFT contract across multiple chains
- Uses the deploy configuration from `utils/deploy.config.json`
- Automatically wires pathways after deployment if specified

### 2. WireOApp.s.sol
- Configures LayerZero pathways between deployed OApps
- Supports both API and local file sources for LayerZero metadata
- Features:
  - **Automatic API Integration**: Fetches deployment and DVN data from LayerZero's official APIs by default
  - **Flexible Data Sources**: Can use API endpoints or local JSON files
  - **Check-Only Mode**: Verify configuration without making changes
  - **Verbose Mode**: Detailed configuration comparison output
  - **Partial Wiring**: Configure source or destination chains separately

#### API Integration
The script now automatically fetches data from:
- Deployments: `https://metadata.layerzero-api.com/v1/metadata/deployments`
- DVNs: `https://metadata.layerzero-api.com/v1/metadata/dvns`

You can override these in your config or via command line parameters.

#### Usage Examples
```bash
# Simple usage (uses default APIs)
forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string)" \
  "layerzero.config.json" \
  --via-ir --broadcast --multi -vvv --ffi

# With custom sources
forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string,string,string)" \
  "layerzero.config.json" \
  "https://my-api.com/deployments" \
  "./local-dvns.json" \
  --via-ir --broadcast --multi -vvv --ffi

# Check-only mode with verbose output
VERBOSE=true CHECK_ONLY=true forge script script/WireOApp.s.sol:WireOApp \
  --sig "run(string)" \
  "layerzero.config.json" \
  --via-ir -vvv --ffi
```

**Note**: The `--ffi` flag is required for API calls via curl.

### 3. SendOFT.s.sol
- Sends OFT tokens across chains
- Useful for testing deployed and wired OApps

### 4. lib/ChainConfig.sol
- Contains chain configurations and helper functions
- Maps chain IDs to names and RPC URLs

## Configuration Files

### utils/deploy.config.json
- Specifies which chains to deploy to
- Can include automatic wiring configuration

### utils/layerzero.config.json
- Defines OApp addresses and pathway configurations
- Supports bidirectional pathways
- Can specify custom API endpoints or local file paths
- Supports flexible enforced options for different message types

Example with API sources:
```json
{
  "deploymentsSource": "https://metadata.layerzero-api.com/v1/metadata/deployments",
  "dvnsSource": "./custom-dvns.json",
  "chains": { ... },
  "pathways": [ ... ]
}
```

## Important Notes

1. **Environment Variables**:
   - `PRIVATE_KEY`: Required for all deployment and configuration operations
   - `CHECK_ONLY`: Set to true for dry-run mode
   - `VERBOSE`: Set to true for detailed output
   - `MAINNET`: Set to true for mainnet operations (some scripts)

2. **FFI Requirement**: When using API features, you must include the `--ffi` flag in your forge commands

3. **Via-IR Compilation**: The WireOApp script requires `--via-ir` flag due to contract size

4. **Multi-Chain Broadcasting**: Use `--multi` flag when configuring multiple chains

5. **Error Handling**: The script provides detailed error messages for common issues like missing DVNs or deployment data

## Development Workflow

1. Deploy OApps using `DeployMyOFT.s.sol`
2. Configure pathways using `WireOApp.s.sol` (automatic API integration)
3. Test with `SendOFT.s.sol`
4. Monitor on LayerZero Scan

## Troubleshooting

- **API Connection Issues**: The script will automatically fall back to local files if specified
- **DVN Not Found**: Check the exact spelling of DVN names in your config
- **Compilation Issues**: Ensure you're using `--via-ir` flag for large contracts
- **FFI Errors**: Make sure to include `--ffi` flag when using API features 