## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Dependencies

This project requires several external dependencies to be installed for the remappings to work correctly:

### LayerZero Dependencies
- **LayerZero DevTools**: Development tools and utilities
  ```shell
  forge install https://github.com/LayerZero-Labs/devtools
  ```
- **LayerZero V2 Protocol**: Core LayerZero V2 contracts
  ```shell
  forge install https://github.com/LayerZero-Labs/layerzero-v2
  ```
- **LayerZero V1 Contracts**: Legacy LayerZero V1 contracts
  ```shell
  forge install https://github.com/LayerZero-Labs/LayerZero-v1
  ```

### Utility Libraries
- **Solidity Bytes Utils**: For byte manipulation utilities
  ```shell
  forge install https://github.com/GNSPS/solidity-bytes-utils
  ```

### Uniswap V3 Dependencies
- **Uniswap V3 Core**: Core pool contracts
  ```shell
  forge install https://github.com/Uniswap/v3-core
  ```
- **Uniswap V3 Periphery**: Router and helper contracts
  ```shell
  forge install https://github.com/Uniswap/v3-periphery
  ```

### Other Dependencies
- **OpenZeppelin Contracts**: Smart contract library with security patterns
  ```shell
  forge install OpenZeppelin/openzeppelin-contracts@v5.1.0
  ```
- **Forge Standard Library**: Already included in `lib/forge-std/`

## Usage

### Build

```shell
$ forge build --via-ir
```

Note: The `--via-ir` flag is required due to stack too deep errors when compiling with the complex LayerZero and Uniswap dependencies.

### Test

```shell
$ forge test --via-ir
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot --via-ir
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key> --via-ir
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
