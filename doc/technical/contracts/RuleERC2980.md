# Rule ERC-2980

<!-- toc -->

- [Schema](#schema)
  - [Graph](#graph)
  - [Inheritance](#inheritance)
  - [Flow with a CMTAT token](#flow-with-a-cmtat-token)
- [Restriction codes](#restriction-codes)
- [Access Control](#access-control)
- [Constructor burn configuration](#constructor-burn-configuration)
- [Whitelist methods](#whitelist-methods)
  - [addWhitelistAddress(address targetAddress)](#addwhitelistaddressaddress-targetaddress)
  - [addWhitelistAddresses(address[] calldata targetAddresses)](#addwhitelistaddressesaddress-calldata-targetaddresses)
  - [removeWhitelistAddress(address targetAddress)](#removewhitelistaddressaddress-targetaddress)
  - [removeWhitelistAddresses(address[] calldata targetAddresses)](#removewhitelistaddressesaddress-calldata-targetaddresses)
  - [isWhitelisted(address targetAddress) → bool](#iswhitelistedaddress-targetaddress--bool)
  - [areWhitelisted(address[] memory targetAddresses) → bool[]](#arewhitelistedaddress-memory-targetaddresses--bool)
  - [whitelistAddressCount() → uint256](#whitelistaddresscount--uint256)
  - [whitelist(address _operator) → bool](#whitelistaddress-_operator--bool)
- [Frozenlist methods](#frozenlist-methods)
  - [addFrozenlistAddress(address targetAddress)](#addfrozenlistaddressaddress-targetaddress)
  - [addFrozenlistAddresses(address[] calldata targetAddresses)](#addfrozenlistaddressesaddress-calldata-targetaddresses)
  - [removeFrozenlistAddress(address targetAddress)](#removefrozenlistaddressaddress-targetaddress)
  - [removeFrozenlistAddresses(address[] calldata targetAddresses)](#removefrozenlistaddressesaddress-calldata-targetaddresses)
  - [isFrozen(address targetAddress) → bool](#isfrozenaddress-targetaddress--bool)
  - [areFrozen(address[] memory targetAddresses) → bool[]](#arefrozenaddress-memory-targetaddresses--bool)
  - [frozenlistAddressCount() → uint256](#frozenlistaddresscount--uint256)
  - [frozenlist(address _operator) → bool](#frozenlistaddress-_operator--bool)
- [Notes](#notes)
  - [Sender whitelist exemption](#sender-whitelist-exemption)
  - [Deviation from ERC-2980 example interface](#deviation-from-erc-2980-example-interface)
  - [isVerified semantics](#isverified-semantics)
- [Usage scenario](#usage-scenario)
- [Deployment guides](#deployment-guides)
- [CMTAT v3.0.0](#cmtat-v300)

<!-- /toc -->

This rule implements the [ERC-2980](https://eips.ethereum.org/EIPS/eip-2980) Swiss Compliant Asset Token transfer restriction. It combines two independent address lists managed within a single contract:

- **Whitelist**: only whitelisted addresses may **receive** tokens. Senders do not need to be whitelisted and may freely transfer tokens they already hold.
- **Frozenlist**: frozen addresses are completely blocked — they can neither send nor receive tokens.
- **Priority**: the frozenlist is checked first. If `from`, `to`, or `spender` is frozen, the transfer is rejected regardless of whitelist membership.

## Schema

The **Graph** and **Inheritance** diagrams are generated from the source code with [Surya](https://github.com/Consensys/surya), by the scripts in `doc/script/`, and must be regenerated after a code change:

- **Graph** (`surya graph`): the call graph of the contract's source file. Each node is a function, grouped by contract, and each arrow is a call from one function to another, including calls to other contracts. Only that file is parsed, so logic inherited from a base contract appears in that base contract's own graph.
- **Inheritance** (`surya inheritance`): the contracts and interfaces this contract inherits from, which tells you where each inherited function and modifier is defined.
- **Flow with a CMTAT token**: a sequence diagram, written by hand in PlantUML (source in `doc/img/`), of how the rule takes part in a token transfer.

### Graph

![surya_graph_RuleERC2980](../../surya/surya_graph/surya_graph_RuleERC2980.sol.png)

### Inheritance

![surya_inheritance_RuleERC2980](../../surya/surya_inheritance/surya_inheritance_RuleERC2980.sol.png)

### Flow with a CMTAT token

The sequence below shows how the rule participates when a CMTAT token (with this rule configured in its RuleEngine) processes a transfer. The frozenlist is evaluated before the recipient whitelist.

![RuleERC2980 flow with a CMTAT token](../../img/rule-erc2980-flow.png)

_Diagram source: doc/img/rule-erc2980-flow.puml._

## Restriction codes

| Constant | Code | Meaning |
| --- | --- | --- |
| `CODE_ADDRESS_FROM_IS_FROZEN` | 60 | Sender is frozen |
| `CODE_ADDRESS_TO_IS_FROZEN` | 61 | Recipient is frozen |
| `CODE_ADDRESS_SPENDER_IS_FROZEN` | 62 | Spender is frozen |
| `CODE_ADDRESS_TO_NOT_WHITELISTED` | 63 | Recipient is not whitelisted |
| `CODE_MINT_NOT_ALLOWED` | 64 | Minting is disabled (`allowMint == false`) |
| `CODE_BURN_NOT_ALLOWED` | 65 | Burning is disabled (`allowBurn == false`) |

## Access Control

| Role | Description |
| --- | --- |
| `DEFAULT_ADMIN_ROLE` | Manages all roles; implicitly holds all roles below |
| `WHITELIST_ADD_ROLE` | May add addresses to the whitelist |
| `WHITELIST_REMOVE_ROLE` | May remove addresses from the whitelist |
| `FROZENLIST_ADD_ROLE` | May add addresses to the frozenlist |
| `FROZENLIST_REMOVE_ROLE` | May remove addresses from the frozenlist |

## Constructor burn configuration

- `RuleERC2980(address admin, address forwarderIrrevocable, bool allowMintBurn)`
- `RuleERC2980Ownable2Step(address owner, address forwarderIrrevocable, bool allowMintBurn)`

`allowMintBurn` sets **both** `allowMint` and `allowBurn`; they are independently settable afterwards via `setAllowMint(bool)` / `setAllowBurn(bool)`.

Mint/burn permission is an **explicit flag** — the constructor does **not** whitelist `address(0)`, and the zero address can never enter either list (`addWhitelistAddress(address(0))` / `addFrozenlistAddress(address(0))` revert). That keeps the **mandatory ERC-2980 getters** truthful: `whitelist(address(0))` and `frozenlist(address(0))` always return `false`.

- `allowMintBurn = false` (default-safe): mint is refused with `CODE_MINT_NOT_ALLOWED` (`64`), burn with `CODE_BURN_NOT_ALLOWED` (`65`) — dedicated codes, not the misleading "recipient not whitelisted" (`63`).
- `allowMintBurn = true`: both permitted. A permitted mint still requires the recipient to be whitelisted and not frozen; a permitted burn still requires the sender not to be frozen.


## Whitelist methods

### `addWhitelistAddress(address targetAddress)`

Adds a single address to the whitelist. Reverts with `RuleERC2980_AddressAlreadyWhitelisted` if already listed.

### `addWhitelistAddresses(address[] calldata targetAddresses)`

Batch-adds addresses to the whitelist. Silently skips duplicates, but **reverts** on `address(0)`: the mint/burn sentinel is never a list member, and skipping it would make the emitted event report it as one.

### `removeWhitelistAddress(address targetAddress)`

Removes a single address from the whitelist. Reverts with `RuleERC2980_AddressNotWhitelisted` if not listed.

### `removeWhitelistAddresses(address[] calldata targetAddresses)`

Batch-removes addresses from the whitelist. Silently skips addresses not listed.

### `isWhitelisted(address targetAddress) → bool`

Returns `true` if the address is whitelisted.

### `areWhitelisted(address[] memory targetAddresses) → bool[]`

Returns a boolean array for batch whitelist membership check.

### `whitelistAddressCount() → uint256`

Returns the total number of whitelisted addresses.

### `whitelist(address _operator) → bool`

ERC-2980 interface getter. Equivalent to `isWhitelisted`.

## Frozenlist methods

### `addFrozenlistAddress(address targetAddress)`

Adds a single address to the frozenlist. Reverts with `RuleERC2980_AddressAlreadyFrozen` if already listed.

### `addFrozenlistAddresses(address[] calldata targetAddresses)`

Batch-adds addresses to the frozenlist. Silently skips duplicates, but **reverts** on `address(0)` (see above).

### `removeFrozenlistAddress(address targetAddress)`

Removes a single address from the frozenlist. Reverts with `RuleERC2980_AddressNotFrozen` if not listed.

### `removeFrozenlistAddresses(address[] calldata targetAddresses)`

Batch-removes addresses from the frozenlist. Silently skips addresses not listed.

### `isFrozen(address targetAddress) → bool`

Returns `true` if the address is frozen.

### `areFrozen(address[] memory targetAddresses) → bool[]`

Returns a boolean array for batch frozenlist membership check.

### `frozenlistAddressCount() → uint256`

Returns the total number of frozen addresses.

### `frozenlist(address _operator) → bool`

ERC-2980 interface getter. Equivalent to `isFrozen`.

## Notes

### Sender whitelist exemption

Under ERC-2980, the sender is explicitly exempt from the whitelist check. An address that already holds tokens may always send them, even if it is not whitelisted. However, frozen senders are still blocked.

### Deviation from ERC-2980 example interface

The ERC-2980 example `Whitelistable` and `Freezable` interfaces return `false` on duplicate/missing operations. This implementation follows the codebase convention of reverting for single-item operations, while batch operations silently skip *duplicates*. The zero address is the one input a batch does **not** skip — it reverts, so the emitted event can never report a member that is not in the set.

### `isVerified` semantics

`isVerified(address)` reflects whitelist membership only. A frozen address that is also whitelisted returns `true` for `isVerified`, because freezing is a temporary enforcement action and does not revoke identity verification.

## Usage scenario

The compliance manager deploys `RuleERC2980` and grants separate roles for whitelist and frozenlist management. Investor Alice is added to the whitelist. Bob, a sanctioned actor, is added to the frozenlist. When Bob tries to send tokens, the frozenlist check fires first and rejects with code 60. When an unlisted address tries to receive tokens, the whitelist check rejects with code 63.

## Deployment guides

Step-by-step deployment with a CMTAT token, with a sequence diagram per setup and per operation: [`DEPLOY_RULE_ERC2980_CMTAT_V3.0.0.md`](../guides/DEPLOY_RULE_ERC2980_CMTAT_V3.0.0.md) for v3.0.0, [`DEPLOY_RULE_ERC2980_CMTAT_V3.3.0.md`](../guides/DEPLOY_RULE_ERC2980_CMTAT_V3.3.0.md) for v3.3.0.

## CMTAT v3.0.0

✅ Supported, with one difference.

- Recipient whitelist, frozen `from` / `to` and frozen `transferFrom` spender all apply.
- WARNING: a **frozen minter or burner is not screened** on v3.0.0, which forwards no spender on mint and burn.

Tested against a real CMTAT **v3.0.0** token (the last audited release), Standard and Debt variants, both set directly on the token and behind a `RuleEngine`: `test/CMTATv3.0.0/RuleERC2980V300.t.sol`.
