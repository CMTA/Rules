# Foundry Toolchain Guide

Full development-toolchain reference for the **Rules** project. For a quick command summary, see the [Toolchains and Usage](../README.md#toolchains-and-usage) section of the README.

## Configuration

Here are the settings for [Hardhat](https://hardhat.org) and [Foundry](https://getfoundry.sh).

- `hardhat.config.js`

  - Solidity [v0.8.36](https://docs.soliditylang.org/en/v0.8.36/)
  - EVM version: Prague (Pectra upgrade)
  - Optimizer: true, 200 runs

- `foundry.toml`

  - Solidity [v0.8.36](https://docs.soliditylang.org/en/v0.8.36/)
  - EVM version: Prague (Pectra upgrade)
  - Optimizer: true, 200 runs

- Library

  - Foundry [v1.5.0](https://github.com/foundry-rs/foundry)

  - Forge std [v1.12.0](https://github.com/foundry-rs/forge-std/releases/tag/v1.12.0)

  - OpenZeppelin Contracts (submodule) [v5.7.0](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v5.7.0)

  - OpenZeppelin Contracts Upgradeable (submodule) [v5.7.0](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/releases/tag/v5.7.0)

  - CMTAT [v3.3.0-rc3](https://github.com/CMTA/CMTAT/releases/tag/v3.3.0-rc3)

  - RuleEngine [v3.0.0-rc6](https://github.com/CMTA/RuleEngine/releases/tag/v3.0.0-rc6)

## Toolchain installation

This repository is primarily developed and tested with [Foundry](https://book.getfoundry.sh), a smart contract development toolchain.

Hardhat configuration is also present to support contract compilation and a small smoke test with Hardhat.

To install the Foundry suite, please refer to the official instructions in the [Foundry book](https://book.getfoundry.sh/getting-started/installation).

## Initialization

You must first initialize the submodules, with

```
forge install
```

See also the command's [documentation](https://book.getfoundry.sh/reference/forge/forge-install).

Later you can update all the submodules with:

```
forge update
```

See also the command's [documentation](https://book.getfoundry.sh/reference/forge/forge-update).

## Compilation

The official documentation is available in the Foundry [website](https://book.getfoundry.sh/reference/forge/build-commands)

```
 forge build
```

Hardhat compilation (optional):

```bash
npm run hardhat:compile
```

## Contract size

```bash
 forge compile --sizes
```

## Testing

You can run the tests with

```bash
forge test
```

Hardhat smoke test (optional):

```bash
npm run hardhat:test:smoke
```

To run a specific test, use

```bash
forge test --match-contract <contract name> --match-test <function name>
```

- For `RuleConditionalTransferLight` fuzz/integration tests, note that mint and burn paths (`from == address(0)` or `to == address(0)`) are intentionally exempt from approval consumption.
- `RuleMintAllowance` integration tests cover single mints, cumulative `batchMint` allowance consumption, rollback on over-allowance batch mint, and advertised ERC-165 interface IDs.
- Ownable2Step variants also include dedicated tests for ownership transfer and manager-only functions (IdentityRegistry, MaxTotalSupply, SanctionsList).
- Coverage-focused tests also target deployment wrappers and operation-rule overloads (`created`, `destroyed`, spender-aware `transferred`) to improve line/function coverage in `src/rules/operation` and `src/rules/validation/deployment`.

Generate gas report

```bash
forge test --gas-report
```

See also the test framework's [official documentation](https://book.getfoundry.sh/forge/tests), and that of the [test commands](https://book.getfoundry.sh/reference/forge/test-commands).

## Gas Benchmarks

Gas usage is tracked in two complementary files:

- **`.gas-snapshot`** — machine-generated file produced by `forge snapshot`. It records the gas cost of every test function and is checked into the repository so that gas regressions are visible in diffs. Regenerate it with:

  ```bash
  forge snapshot
  ```

  To check for regressions against the committed snapshot without overwriting it:

  ```bash
  forge snapshot --check
  ```

- **`doc/GAS.md`** — human-readable summary of key operation costs (e.g. `addAddress`, `detectTransferRestriction`) with the date of the last measurement. Update it manually after running `forge snapshot` when behaviour or gas costs change.

## Coverage

![coverage](./coverage/coverage.png)

A code coverage is available in [index.html](./coverage/coverage/index.html).

* Perform a code coverage

```
forge coverage
```

* Generate LCOV report

```
forge coverage --report lcov
```

- Generate `index.html`

```bash
forge coverage --no-match-coverage "(script|mocks|test)" --report lcov && genhtml lcov.info --branch-coverage --prefix "$PWD/" --output-dir coverage
```

See [Solidity Coverage in VS Code with Foundry](https://mirror.xyz/devanon.eth/RrDvKPnlD-pmpuW7hQeR5wWdVjklrpOgPCOA-PJkWFU) & [Foundry forge coverage](https://www.rareskills.io/post/foundry-forge-coverage)

## Other

Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

### Documentation

https://book.getfoundry.sh/

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

> **Warning — private key security**
> Passing `--private-key` directly on the command line is **not recommended** in production: the key is visible in your shell history and to any process that can read `/proc`. Prefer hardware wallets (`--ledger`, `--trezor`), encrypted keystores (`--account <keystore>`), or environment-variable signers. See [Foundry best practices](https://www.getfoundry.sh/best-practices) for details.

```shell
$ forge script script/DeployCMTATWithWhitelist.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
$ forge script script/DeployCMTATWithBlacklist.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
$ forge script script/DeployCMTATWithBlacklistAndSanctionsList.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
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
