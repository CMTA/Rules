# Rule Blacklist

[TOC]

This rule blocks transfers involving any blacklisted address. Both the sender (`from`) and recipient (`to`) are checked. The spender in a `transferFrom` call is always checked as well.

A significant portion of the address-list management code is shared with the whitelist rule via `RuleAddressSet`.

## Schema

### Graph

![surya_graph_RuleBlacklist](../../surya/surya_graph/surya_graph_RuleBlacklist.sol.png)

### Inheritance

![surya_inheritance_RuleBlacklist](../../surya/surya_inheritance/surya_inheritance_RuleBlacklist.sol.png)

### Flow with a CMTAT token

The sequence below shows how the rule participates when a CMTAT token (with this rule configured in its RuleEngine) processes a transfer.

![RuleBlacklist flow with a CMTAT token](../../img/rule-blacklist-flow.png)

_Diagram source: doc/img/rule-blacklist-flow.puml._

## Restriction codes

| Constant | Code | Meaning |
| --- | --- | --- |
| `CODE_ADDRESS_FROM_IS_BLACKLISTED` | 36 | Sender is blacklisted |
| `CODE_ADDRESS_TO_IS_BLACKLISTED` | 37 | Recipient is blacklisted |
| `CODE_ADDRESS_SPENDER_IS_BLACKLISTED` | 38 | Spender is blacklisted |

## Access Control

The default admin is the address passed as `admin` in the constructor. It is granted `DEFAULT_ADMIN_ROLE`, which implicitly holds all roles.

| Role | Description |
| --- | --- |
| `DEFAULT_ADMIN_ROLE` | Manages all roles; can call all privileged functions |
| `ADDRESS_LIST_ADD_ROLE` | May add addresses to the blacklist (`addAddress`, `addAddresses`) |
| `ADDRESS_LIST_REMOVE_ROLE` | May remove addresses from the blacklist (`removeAddress`, `removeAddresses`) |


## Methods

### `addAddress(address targetAddress)`

Adds a single address to the blacklist. Reverts if the address is already listed.

### `addAddresses(address[] calldata targetAddresses)`

Batch-adds addresses to the blacklist. Silently skips duplicates (no revert).

### `removeAddress(address targetAddress)`

Removes a single address from the blacklist. Reverts if the address is not listed.

### `removeAddresses(address[] calldata targetAddresses)`

Batch-removes addresses from the blacklist. Silently skips addresses not listed (no revert).

### `isAddressListed(address targetAddress) → bool`

Returns `true` if the address is in the blacklist.

### `areAddressesListed(address[] memory targetAddresses) → bool[]`

Returns a boolean array indicating blacklist membership for each address.

## Notes

### Batch vs single operations

Single-item operations (`addAddress`, `removeAddress`) revert on duplicate/missing input. Batch operations (`addAddresses`, `removeAddresses`) skip invalid entries silently.

### Usage scenario

The operator deploys `RuleBlacklist`, grants `ADDRESS_LIST_ADD_ROLE` to a compliance manager, and registers the rule in the `RuleEngine`. The compliance manager calls `addAddresses([badActor])`. Any transfer from, to, or by the blacklisted address is rejected with codes 36, 37, or 38.

## CMTAT v3.0.0

✅ Supported, with one difference.

- `from`, `to` and the `transferFrom` spender are screened.
- WARNING: on v3.0.0 a blacklisted **minter or burner is not screened**. v3.0.0 sends mint and burn on the 3-argument `transferred`, with no spender, so there is nothing to check. On CMTAT >= v3.3 the operator arrives as `spender` and is blocked. Control who holds `MINTER_ROLE` / `BURNER_ROLE` on the token instead.

Tested against a real CMTAT **v3.0.0** token (the last audited release), Standard and Debt variants, both set directly on the token and behind a `RuleEngine`: `test/CMTATv3.0.0/RuleBlacklistV300.t.sol`.
