# LayerZero V2 OFT Example (Foundry)

**Deploy an Omnichain Fungible Token (OFT), wire LayerZero pathways, and send tokens – all with Foundry.**

---

## 1. Why this repo exists
LayerZero V2 introduces simplified, gas-efficient omnichain messaging. This template shows how to:
1. Deploy an ERC-20 compliant OFT (`MyOFT.sol`) to multiple chains.
2. Configure LayerZero V2 pathways with batched, nonce-safe transactions.
3. Send the token cross-chain – complete CI-friendly commands & config schemas.

If you want the fastest route to a production-ready OFT, start here.

---

## 2. Prerequisites
| Tool | Version / Status |
|------|------------------|
| [Foundry](https://book.getfoundry.sh/) | latest (≥ 0.2.0) |
| Git  | latest |
| Funded **PRIVATE_KEY** | on every target chain |
| RPC URLs | `BASE_RPC`, `ARBITRUM_RPC`, `OPTIMISM_RPC`, … |

> You can also embed RPCs directly inside the JSON config (see below).

---

## 3. Quick Start
```bash
# 1. Clone & install
 git clone <repo-url>
 cd foundry-vanilla
 forge install

# 2. Environment (copy template & fill values)
 cp env.example .env
 source .env  # loads PRIVATE_KEY + *_RPC vars

# 3. Deploy MyOFT to all chains in deploy.config.json
 forge script script/DeployMyOFT.s.sol:DeployMyOFT \
   --sig "run(string)" utils/deploy.config.json \
   --broadcast --via-ir -vvv

# 4. Wire LayerZero pathways (batched, nonce-safe)
 forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
   --sig "run(string)" utils/layerzero.config.json \
   --broadcast --multi --via-ir --ffi -vvv

# 5. Send tokens cross-chain (Base → Arbitrum example)
 OFT=$(jq -r '.chains.base.address' deployments/mainnet/MyOFT.json)
 forge script script/SendOFT.s.sol:SendOFT \
   --sig "send(address,uint32,bytes32,uint256,uint256,bytes,bytes,bytes)" \
   $OFT 30110 \
   0x000000000000000000000000<recipient> \
   1000000000000000000 \
   0 0x 0x 0x \
   --broadcast -vvv --rpc-url $BASE_RPC --via-ir
```

---

## 4. Detailed Workflow
### 4.1 Deploy
```bash
forge script script/DeployMyOFT.s.sol:DeployMyOFT \
  --sig "run(string)" utils/deploy.config.json \
  --broadcast --via-ir -vvv
```
• Reads `tokenName`, `tokenSymbol`, and `chains[]` from `deploy.config.json`.
• For each `{ name, eid }` entry it:
  – Picks RPC from `NAME_RPC` env-var (or `"rpc"` field).  
  – Fetches the LayerZero V2 endpoint for the `eid`.  
  – Deploys `MyOFT` and writes `deployments/mainnet/MyOFT.json`.

### 4.2 Wire (Batched, recommended)
```bash
forge script script/BatchedWireOApp.s.sol:BatchedWireOApp \
  --sig "run(string)" utils/layerzero.config.json \
  --broadcast --multi --via-ir --ffi -vvv
```
• Operates in two phases: **collect** & **broadcast per chain** (solves nonce issues).  
• Supports `CHECK_ONLY=true` env var for dry-run.

### 4.3 Send
```bash
forge script script/SendOFT.s.sol:SendOFT --help   # see full ABI
```
Typical call (see Quick Start) transfers `amount` from source to destination `eid`.

---

## 5. Configuration Files
| File | Purpose |
|------|---------|
| `utils/deploy.config.json` | Deploy inputs (token & chains). |
| `utils/layerzero.config.json` | Wiring inputs (pathways & DVNs). |

### 5.1 deploy.config.json schema
```jsonc
{
  "tokenName": "My Omnichain Token",
  "tokenSymbol": "MYOFT",
  "chains": [
    { "name": "base",     "eid": 30184 },
    { "name": "arbitrum", "eid": 30110 },
    { "name": "optimism", "eid": 30111 }
  ]
}
```
*Optional keys*: `rpc`, `deployer`, `lzEndpoint` (ignored/overwritten).

### 5.2 layerzero.config.json schema
See examples in [`script/WIRE_OAPP_README.md`](script/WIRE_OAPP_README.md).

---

## 6. Troubleshooting
| Issue | Quick fix |
|-------|-----------|
| "RPC not found for chain" | Ensure `NAME_RPC` env var or `"rpc"` in JSON. |
| "LayerZero endpoint not found for EID" | Update `layerzero-deployments.json` via `script/download-deployments.sh`. |
| Gas / underpriced tx | Add `--with-gas-price` or see gas appendix. |
| Nonce mismatch | Always use **BatchedWireOApp** with `--multi`. |
| Stack too deep / vm.envOr not unique | Add `--via-ir`. |

More fixes → [`script/GAS_AND_RPC_FIXES.md`](script/GAS_AND_RPC_FIXES.md).

---

## 7. Advanced
• **Multisig signer** – pass `--multisig <address>` flags in scripts.  
• **Legacy wiring** – use [`script/WireOApp.s.sol`](script/WIRE_OAPP_README.md) (non-batched).  
• **Custom DVNs & gas options** – see layered config examples in script docs.

---

## 8. References
* LayerZero Docs: https://docs.layerzero.network/v2  
* Foundry Book: https://book.getfoundry.sh  
* Batched wiring guide – [`script/BATCHED_WIRE_README.md`](script/BATCHED_WIRE_README.md)  
* Legacy wiring guide – [`script/WIRE_OAPP_README.md`](script/WIRE_OAPP_README.md)  
* Gas & RPC appendix – [`script/GAS_AND_RPC_FIXES.md`](script/GAS_AND_RPC_FIXES.md)

---
_© LayerZero Labs – Example code.  Not audited, use at your own risk._
