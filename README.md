# RuleEngine - Rules

> This repository includes the rules contract for the CMTAT [RuleEngine](https://github.com/CMTA/RuleEngine)
>
> This repository is currently under development 

- The RuleEngine is an external contract used to apply transfer restrictions to another contract such as a CMTAT or ERC-3643 tokens. Acting as a controller, it can call different contract rules and apply these rules on each transfer.
- Rules: 
  - There are two types of rules in our RuleEngine implementation: validation and operation rules.
  - Validation rules are read-only rules. These rules cannot update the state of the blockchain during a transfer call; they can only read information from the blockchain.
  - The second type of rules, known as operation rules, can also modify the state of the blockchain (write) during a transfer call. 

## Rules details



### Validation rule

Currently, there are four validation rules: whitelist, whitelistWrapper, blacklist, and sanctionlist.

#### Whitelist

With a whitelist rule, only whitelisted addresses can hold the token. Thus, a transfer will fail if either the origin (current token holder) or the destination is not in the list.

During a transfer, this rule, called by the RuleEngine, will check if the address concerned is in the list, applying a read operation on the blockchain.

#### Whitelist wrapper

This rule can be used to restrict transfers only from/to addresses inside a group of whitelist rules managed by different operators. Thus, each operator can manage independently their own whitelist. Here is an explanation schema:

#### Blacklist

The blacklist rule works similarly to the whitelist rule but in the opposite way. With this rule, the addresses must not be on the list to allow the transfer to succeed.

#### Sanction list with Chainalysis

The purpose of this contract is to use the oracle contract from [Chainalysis](https://www.chainalysis.com/) to forbid transfers from/to an address included in a sanctions designation (US, EU, or UN). Documentation and the contracts addresses are available here: [Chainalysis oracle for sanctions screening](https://go.chainalysis.com/chainalysis-oracle-docs.html).

During a transfer, if either address (from or to) is in the sanction list of the Oracle, the rule will return false, and the transfer will be rejected by the CMTAT.

### Operation rule

For the moment, there is only one operation rule available: ConditionalTransfer.

Currently, we only have one operation rule: *ConditionalTransfer*. This rule requires that transfers must be approved before being executed by the token holders. During the transfer call, the rule will check if the transfer has been approved. If it has, the approval will be removed since the transfer has been processed, applying a write operation on the blockchain.

#### Conditional transfer

This rule requires that transfers be approved by the token holders before being executed.

Initially, this rule was designed to implement a specific requirement in Swiss law (Vinkulierung), but it has since been generalized to be more flexible.

According to Swiss law, if a transfer is not approved or denied within three months, the request is considered approved. This option can be activated by setting the option AUTOMATIC_APPROVAL in the rule.

We have added another option, not required by Swiss law, to automatically perform a transfer if the transfer request is approved. This option can be activated by setting the option AUTOMATIC_TRANSFER in the rule.

Reference: [Taurus - Token Transfer Management: How to Apply Restrictions with CMTAT and ERC-1404](https://www.taurushq.com/blog/token-transfer-management-how-to-apply-restrictions-with-cmtat-and-erc-1404/)

## Dependencies

The toolchain includes the following components, where the versions are the latest ones that we tested:

- Foundry [v1.9.4](https://github.com/foundry-rs/forge-std/releases/tag/v1.9.4)
- Solidity 0.8.30 (via solc-js)
- OpenZeppelin Contracts (submodule) [v5.3.0](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v5.3.0)
- CMTAT [v3.0.0](https://github.com/CMTA/CMTAT)
  - This repository includes the RuleEngine contract for the [CMTAT](https://github.com/CMTA/CMTAT) token. 


The RuleEngine is an external contract used to apply transfer restrictions to another contract, initially the CMTAT. Acting as a controller, it can call different contract rules and apply these rules on each transfer.

## Dependencies

The toolchain includes the following components, where the versions are the latest ones that we tested:

- Foundry [v1.9.4](https://github.com/foundry-rs/forge-std/releases/tag/v1.9.4)
- Solidity 0.8.30 (via solc-js)
- OpenZeppelin Contracts (submodule) [v5.3.0](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v5.3.0)
- CMTAT [v3.0.0](https://github.com/CMTA/CMTAT)



## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

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

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
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
