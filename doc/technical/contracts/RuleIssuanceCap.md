# Rule Issuance Cap

<!-- toc -->

- [Which cap rule to use](#which-cap-rule-to-use)
- [Contract layout](#contract-layout)
- [How it decides](#how-it-decides)
- [Configuration](#configuration)
  - [Constructor parameters](#constructor-parameters)
  - [Binding](#binding)
  - [Deployment order: no uncounted mint](#deployment-order-no-uncounted-mint)
  - [Post-deployment configuration](#post-deployment-configuration)
- [Restriction codes](#restriction-codes)
- [Access control](#access-control)
- [Methods and events](#methods-and-events)
- [Behaviour by token operation](#behaviour-by-token-operation)
- [ERC-3643](#erc-3643)
- [Deployment guides](#deployment-guides)
- [CMTAT v3.0.0](#cmtat-v300)
- [Migration](#migration)
- [Tests](#tests)

<!-- /toc -->

This rule caps the **cumulative issuance** of a token: the total ever minted can never exceed a configured amount, and **burns do not restore room**. It fits a fixed issue volume, such as the number of shares authorised by a corporate resolution or the issue size of a bond, where redeemed tokens must not be re-issued under the same authorisation.

It answers [CMTA/Rules#16](https://github.com/CMTA/Rules/issues/16) and works with CMTAT **v3.0.0**, whose mints call the rule through the 3-argument `transferred` with no minter, as well as with CMTAT ≥ v3.3.

## Which cap rule to use

| Need | Rule | Burns |
| --- | --- | --- |
| Total ever issued ≤ N (fixed issue volume) | **`RuleIssuanceCap`** | do **not** restore room |
| Outstanding supply ≤ N (issued and redeemed on an ongoing basis) | [`RuleMaxTotalSupply`](./RuleMaxTotalSupply.md) | restore room |

The choice is made at deployment by picking the contract; there is no mode flag. For both limits at once, add both rules to the same `RuleEngine`.

## Contract layout

`RuleIssuanceCap` **extends** `RuleMaxTotalSupply`'s logic rather than copying it. Everything except the counter and the caller restriction is inherited:

| Contract | Adds |
| --- | --- |
| [`TotalSupplyCapManager`](../../../src/rules/validation/abstract/core/TotalSupplyCapManager.sol) | The cap, `set` / `increase` / `decreaseMaxTotalSupply`, `MaxTotalSupplyUpdated(previous, new)`, the revert-free `totalSupply()` read |
| [`RuleMaxTotalSupplyBase`](../../../src/rules/validation/abstract/base/RuleMaxTotalSupplyBase.sol) | The mint-only live-supply check (codes 50 / 51), the ERC-1404 surface, `remainingMintable()`, and the `_afterMintChecked` hook |
| [`RuleIssuanceCapBase`](../../../src/rules/operation/abstract/RuleIssuanceCapBase.sol) | The `totalIssued` counter (code 71), binding (`onlyBoundToken`), the `initialIssued` check, the locked token |
| [`RuleIssuanceCap`](../../../src/rules/operation/RuleIssuanceCap.sol) / [`RuleIssuanceCapOwnable2Step`](../../../src/rules/operation/RuleIssuanceCapOwnable2Step.sol) | Access control only |

## How it decides

On a mint of `value`, two checks run against the same cap (`maxTotalSupply`):

| Check | Rejects when | Code |
| --- | --- | --- |
| Counter | `totalIssued + value > cap` | **71** |
| Live supply (inherited) | `totalSupply() + value > cap` | 50 (51 if `totalSupply()` is unreadable) |

If both pass, `totalIssued += value` and `IssuanceRecorded(value, totalIssued)` is emitted. Transfers and burns are never checked and never change the counter. A zero-value mint is a no-op.

**Why keep the live-supply check.** Cumulative issuance is always at least the current supply, because burns only lower supply. So while every mint is counted, the live check never rejects a mint the counter accepts. It fires only when the counter was bypassed: mints made while the rule was detached raise the supply, and the live check then stops minting at the same cap instead of letting it continue unnoticed.

## Configuration

### Constructor parameters

| Parameter | Description |
| --- | --- |
| `admin` / `owner` | `DEFAULT_ADMIN_ROLE` holder (AccessControl), or owner (Ownable2Step) |
| `tokenContract_` | The capped token: non-zero, has code, `totalSupply()` callable. **Fixed for the life of the rule** |
| `issuanceCap_` | Maximum cumulative issuance, in token **base units** (scaled by `10 ** decimals()`; see [Unit of the cap](./RuleMaxTotalSupply.md#unit-of-the-cap)) |
| `initialIssued_` | Issuance before the rule was installed. Must be **at least the token's current supply**, else `RuleIssuanceCap_InitialIssuedBelowSupply` |

Pass `initialIssued = 0` for a new token. For an existing token, pass the issuance so far: at least `totalSupply()`, and more if tokens were already burned.

### Binding

The rule writes storage on every mint, so `transferred` only accepts its bound caller. Bind exactly one:

| Topology | Bind |
| --- | --- |
| Rule set directly on the token (`setRuleEngine(rule)`) | the **token** |
| Rule inside a `RuleEngine` | the **RuleEngine** |

WARNING: a bound RuleEngine **must serve only `tokenContract`**. A RuleEngine can bind several tokens, and the rule cannot tell which one minted: every mint of every token the engine serves is recorded in this rule's `totalIssued`, while the live-supply check still reads `tokenContract` only. A second token's mints would use up the first token's issuance budget, and the second token would be capped by a counter that is not its own. Use one RuleEngine per token with this rule, or one rule instance per token set directly on the token.

`bindToken` reverts with `RuleIssuanceCap_TokenAlreadyBound` while a caller is bound; call `unbindToken` first to migrate. An unbound caller is rejected with `TokenBinding_UnauthorizedCaller`.

WARNING: until `bindToken` is called, every operation reverts (the write path rejects the unbound caller). The views say so: every operation reports code **85** (`CODE_RULE_NOT_BOUND`), and `remainingMintable()` returns `(85, 0)`.

### Deployment order: no uncounted mint

The rule only sees the mints the token notifies it of. Any mint made before the rule is installed, or while it is detached, is neither checked nor counted, so a mint-and-burn in that window would let lifetime issuance exceed the cap. The live-supply check still keeps the **supply** under the cap; what is lost is the "burns do not restore room" guarantee for that period. Install the rule before anyone can mint.

**With a RuleEngine, set at token deployment (recommended, no window at all).** CMTAT accepts its rule engine in the constructor (`ICMTATConstructor.Engine`), and a RuleEngine rejects every call from a token it has not bound. So bind the token to the engine **last**:

1. Deploy the RuleEngine with no token: `new RuleEngine(admin, address(0))`.
2. Deploy the CMTAT token with that engine in its constructor. Every mint, the admin's included, now reverts with `TokenBinding_UnauthorizedCaller`.
3. Deploy `RuleIssuanceCap(admin, token, cap, 0)`; it needs the token's address, so it comes after the token.
4. `rule.bindToken(engine)`, then `engine.addRule(rule)`, plus any other rules.
5. `engine.bindToken(token)`. From the first mint that can succeed, the rule counts it.
6. Grant `MINTER_ROLE`.

Pinned by `testDeploymentWithEngineInConstructorLeavesNoUncountedWindow`, and by `testDeploymentWithEngineInConstructorBlocksGrantedMinter` for a minter granted `MINTER_ROLE` before the token is bound.

**With the rule set directly on the token, or an engine set after deployment.** The rule cannot be passed to the token's constructor (its own constructor reads the token's `totalSupply()`), so there is a window between token deployment and `setRuleEngine`. Keep it empty: deploy the token, deploy the rule, `bindToken`, `setRuleEngine`, and only then grant `MINTER_ROLE`. A freshly deployed CMTAT has no minter except its default admin, who must not mint before the rule is installed (CMTAT gives the default admin every role, so it can always mint).

**For a token that is already live,** pass as `initialIssued` the issuance at the moment the rule is installed, not at deployment, and do not mint between the two.

### Post-deployment configuration

- The cap: `setMaxTotalSupply`, `increaseMaxTotalSupply`, `decreaseMaxTotalSupply`.
- `setTokenContract` **always reverts** (`RuleIssuanceCap_TokenContractLocked`): the counter is one token's history. To protect another token, deploy another instance.

## Restriction codes

| Constant | Code | Meaning |
| --- | --- | --- |
| `CODE_ISSUANCE_CAP_EXCEEDED` | 71 | Cumulative issuance would exceed the cap |
| `CODE_MAX_TOTAL_SUPPLY_EXCEEDED` | 50 | Live supply would exceed the cap (shared with `RuleMaxTotalSupply`, same message) |
| `CODE_SUPPLY_ORACLE_UNAVAILABLE` | 51 | `totalSupply()` could not be read |
| `CODE_RULE_NOT_BOUND` | 85 | No caller is bound yet (`bindToken`), so every operation would revert. Shared, with the same message, by `RuleConditionalTransferLight`, `RuleMintAllowance` and `RuleIssuanceCap` |

A rejected mint reverts with `RuleMaxTotalSupply_InvalidTransfer` (3-argument path, CMTAT v3.0.0) or `RuleMaxTotalSupply_InvalidTransferFrom` (4-argument path, CMTAT ≥ v3.3), carrying one of these codes.

## Access control

| Role (AccessControl variant) | May call |
| --- | --- |
| `MAX_TOTAL_SUPPLY_ROLE` | `setMaxTotalSupply`, `increaseMaxTotalSupply`, `decreaseMaxTotalSupply` |
| `COMPLIANCE_MANAGER_ROLE` | `bindToken`, `unbindToken` |
| `DEFAULT_ADMIN_ROLE` | role management, and implicitly every role above |

On `RuleIssuanceCapOwnable2Step` the owner may call all of them.

## Methods and events

| Member | Notes |
| --- | --- |
| `totalIssued() → uint256` | Cumulative issuance; never decreases |
| `remainingMintable() → (uint8 code, uint256 headroom)` | The smaller of the counter room and the live-supply room; code 51 if the supply is unreadable, code 85 while no caller is bound |
| `maxTotalSupply() → uint256` | The cap. Here it bounds cumulative **issuance**, not outstanding supply |
| `TotalIssuedInitialized(uint256 initialIssued)` | Once, at deployment |
| `IssuanceRecorded(uint256 value, uint256 totalIssued)` | On every accepted non-zero mint |
| `MaxTotalSupplyUpdated(uint256 previous, uint256 new)` | On every cap change, and at deployment |

## Behaviour by token operation

Pinned on a real CMTAT v3.0.0 token (`test/CMTATv3.0.0/RuleIssuanceCapV300.t.sol`, Standard and Debt, direct and behind a `RuleEngine`) and on the current CMTAT (`test/RuleIssuanceCap/RuleIssuanceCapCMTATIntegration.t.sol`).

| Operation | Effect on the counter | Note |
| --- | --- | --- |
| `mint`, `batchMint` | + `value`, if both checks pass | |
| `burn`, `burnFrom`, forced burn | none | Room is **not** restored, by design |
| `burnAndMint(from, to, b, m)` | + `m` | A correction uses up authorised volume; raise the cap with `increaseMaxTotalSupply(m)` if it should not |
| `crosschainMint` / `crosschainBurn` | + on mint, none on burn | **A bridge round trip uses up the cap.** Do not use this rule for a bridged token; use `RuleMaxTotalSupply` |
| `transfer`, `transferFrom` | none | |
| Cap lowered to `totalIssued` or below | — | Minting stops (`remainingMintable() = 0`); transfers and burns continue |
| Rule detached, then re-attached | Mints while detached are not counted | The live-supply check catches them: if they pushed the supply above the cap, minting stays stopped |

WARNING: detaching the rule (`setRuleEngine(address(0))`, or `removeRule` on the engine) lifts the cap while detached: the token no longer notifies the rule, so mints are neither checked nor counted. Before detaching, revoke `MINTER_ROLE` from every minter so nobody can mint during the gap, and grant it back after re-attaching. The token's default admin keeps the ability to mint (CMTAT gives it every role), so the admin must not mint during the gap either. Pausing does not help: CMTAT's pause stops transfers, not mints.

## ERC-3643

**Not supported in v1.** The counter is enforced in `_afterMintChecked` with the real amount, so it would stay correct on an ERC-3643 token, whose write path is re-phased to `value = 0` (a unit test pins this). But the inherited live-supply check double-counts on ERC-3643's post-update notification, exactly as the stock `RuleMaxTotalSupply` does. An ERC-3643 variant needs only the one-line re-phasing override that `RuleMaxTotalSupplyERC3643` already has; it is not shipped.

## Deployment guides

Step-by-step deployment with a CMTAT token, with a sequence diagram per setup and per operation: [`DEPLOY_RULE_ISSUANCE_CAP_CMTAT_V3.0.0.md`](../guides/DEPLOY_RULE_ISSUANCE_CAP_CMTAT_V3.0.0.md) for v3.0.0, [`DEPLOY_RULE_ISSUANCE_CAP_CMTAT_V3.3.0.md`](../guides/DEPLOY_RULE_ISSUANCE_CAP_CMTAT_V3.3.0.md) for v3.3.0.

## CMTAT v3.0.0

✅ Supported. Every mint calls the rule through the 3-argument path with no minter, and the cap is per token, not per minter, so the missing spender changes nothing. This is the use case of CMTA/Rules#16, unlike `RuleMintAllowance`, which is inert on v3.0.0.

## Migration

- **From `RuleMaxTotalSupply`:** deploy `RuleIssuanceCap` with `initialIssued` = the issuance so far, bind the token or engine, then swap the rule. The swap gap is covered by the live-supply check.
- **Replacing an instance:** deploy the new one with `initialIssued = old.totalIssued()`.

## Tests

- Unit: `test/RuleIssuanceCap/`.
- CMTAT v3.0.0: `test/CMTATv3.0.0/RuleIssuanceCapV300.t.sol`.
- Invariants: `IssuanceCapInvariants` (`test/invariant/`). Seven invariants, including exact counter accounting, mutation-verified; see `INVARIANT_TESTS.md`.
