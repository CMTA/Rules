# Invariant Tests

<!-- toc -->

- [1. Running the suite](#1-running-the-suite)
- [2. Architecture — the handler pattern](#2-architecture--the-handler-pattern)
- [3. The invariants](#3-the-invariants)
  - [3.1 RuleConditionalTransferLight — approval conservation](#31-ruleconditionaltransferlight--approval-conservation)
  - [3.2 RuleMintAllowance — exact quota accounting](#32-rulemintallowance--exact-quota-accounting)
  - [3.3 RuleMaxTotalSupply — the cap holds across any sequence](#33-rulemaxtotalsupply--the-cap-holds-across-any-sequence)
  - [3.4 RuleIssuanceCap — the counter is exact and never restored](#34-ruleissuancecap--the-counter-is-exact-and-never-restored)
- [4. Negative controls — proving the suite can fail](#4-negative-controls--proving-the-suite-can-fail)
- [5. Coverage map](#5-coverage-map)
- [6. Adding a new invariant](#6-adding-a-new-invariant)

<!-- /toc -->

This document describes the **stateful invariant suite** in [`test/invariant/`](../../../test/invariant/): what each invariant asserts, why it matters, how the handlers are built, and how the suite was verified to catch bugs.

Invariant tests differ from the unit and fuzz tests elsewhere in `test/`: instead of exercising a fixed call sequence, Foundry drives a **handler** contract with long, randomly-ordered sequences of calls and re-checks every `invariant_*` function after each step. They are the right tool for the two **stateful (operation) rules**, whose storage evolves across calls.

Validation rules are read-only and hold no per-transfer state, so most have nothing to conserve across a call sequence, and unit and fuzz tests cover them instead. **`RuleMaxTotalSupply` is the exception.** It holds no state, but the supply it guards does, and that supply is changed by operations the rule never sees (forced burns). Its suite therefore drives a **real CMTAT token** rather than calling the rule directly (§3.3).

---

## 1. Running the suite

```bash
forge test --match-path "test/invariant/*"          # the invariant suite only
forge test --match-contract ConditionalTransferInvariants
forge test --match-contract MintAllowanceInvariants
forge test --match-contract MaxTotalSupplyInvariants
forge test --match-contract IssuanceCapInvariants
forge test                                          # everything, invariants included
```

Configuration lives in `foundry.toml`:

```toml
[invariant]
runs = 64             # independent random sequences
depth = 128           # calls per sequence
fail_on_revert = true # a reverting handler call fails the run
```

`runs × depth` ⇒ **8 192 handler calls per invariant**. `fail_on_revert = true` is deliberate: the handlers are written to only ever make calls the rule will accept, so **any** revert means the handler (or the rule) is wrong, and we want to know. The suite currently reports **0 reverts**.

---

## 2. Architecture — the handler pattern

Foundry cannot usefully fuzz a rule directly: `approveTransfer` needs `OPERATOR_ROLE`, `transferred` may only be called by the bound entity, and random inputs would mostly revert. So each rule gets a **handler** that:

1. **Holds the required roles and is itself the bound entity.** The handler is passed to `bindToken(address(handler))` and granted the operator role, so `msg.sender` inside the rule is the handler and every call is authorized.
2. **Bounds the inputs.** A small actor set (3 addresses) and a small value range make the fuzzer *collide* on the same keys repeatedly, which is what exercises the accounting.
3. **Skips calls that would revert** (e.g. cancelling a non-existent approval), so `fail_on_revert = true` stays meaningful.
4. **Maintains ghost variables**: an independent, off-chain-style mirror of what the rule's state *should* be. The invariant then compares the rule against the ghost.

```
        ┌──────────────────────┐   randomly-ordered calls    ┌──────────────────┐
        │  Foundry invariant   │ ──────────────────────────▶ │     Handler      │
        │       fuzzer         │                             │  (bound entity,  │
        └──────────────────────┘                             │   role holder)   │
                   │                                         └────────┬─────────┘
                   │ after every call                      real call  │  ghost update
                   ▼                                                  ▼
        ┌──────────────────────┐                          ┌────────┐  ┌────────────┐
        │   invariant_*()      │  compares  ─────────────▶│  Rule  │  │   ghosts   │
        └──────────────────────┘                          └────────┘  └────────────┘
```

`targetSelector` restricts the fuzzer to the handler's own action functions. Without it, Foundry would also call the public functions the handler inherits from forge-std's `Test`, wasting the call budget.

| File | Role |
|---|---|
| [`test/invariant/ConditionalTransferHandler.sol`](../../../test/invariant/ConditionalTransferHandler.sol) | Drives `RuleConditionalTransferLight`'s approval state machine |
| [`test/invariant/MintAllowanceHandler.sol`](../../../test/invariant/MintAllowanceHandler.sol) | Drives `RuleMintAllowance`'s quota accounting |
| [`test/invariant/MaxTotalSupplyHandler.sol`](../../../test/invariant/MaxTotalSupplyHandler.sol) | Drives a real CMTAT token guarded by a supply-cap rule; `_fits` says when a mint should pass |
| [`test/invariant/IssuanceCapHandler.sol`](../../../test/invariant/IssuanceCapHandler.sol) | Extends it for `RuleIssuanceCap`: redefines `_fits` and mirrors the counter in `ghostIssued` |
| [`test/invariant/RuleInvariants.t.sol`](../../../test/invariant/RuleInvariants.t.sol) | The invariant test contracts and their `setUp`. The supply-cap invariants live once in the abstract `SupplyCapInvariantsBase`, shared by `MaxTotalSupplyInvariants` and `IssuanceCapInvariants` |

---

## 3. The invariants

### 3.1 `RuleConditionalTransferLight` — approval conservation

Handler actions: `approve` · `cancel` · `execute` · `executeMintOrBurn`. Ghosts: `totalApproved`, `totalCancelled`, `totalExecuted`, `mintBurnCalls`.

#### `invariant_approvalConservation`

```
totalApproved − totalCancelled − totalExecuted  ==  Σ approvalCounts
```

Every approval ever recorded is, at any moment, in exactly one of three states: **still outstanding**, **cancelled**, or **consumed by a transfer**. The equality says approvals are neither **double-spent** (one `approveTransfer` consumed twice) nor **lost** (an approval that vanishes without being cancelled or used).

The invariant additionally asserts `totalApproved >= totalCancelled + totalExecuted`, which fails if the rule ever lets more approvals be consumed than were recorded — i.e. an underflow of `approvalCounts` (`INV-5`).

#### `invariant_noApprovalExceedsTotalRecorded`

```
Σ approvalCounts  ≤  totalApproved
```

A weaker but independent bound: no tuple can ever hold more outstanding approvals than were granted in total. It catches a class of bug (spurious increments) that conservation alone could mask if a matching spurious decrement existed.

#### Emergent property — mint/burn never consume an approval

The handler calls `executeMintOrBurn`, firing `transferred(address(0), to, v)` and `transferred(from, address(0), v)`, but **deliberately does not** count these in `totalExecuted`. If a mint or burn ever consumed an approval, `Σ approvalCounts` would drop while `totalExecuted` stayed put, and `invariant_approvalConservation` would break.

So the mint/burn exemption is proved by the conservation invariant itself, so no separate test is needed.

### 3.2 `RuleMintAllowance` — exact quota accounting

Handler actions: `setAllowance` · `increase` · `decrease` · `mint` · `regularTransfer`. Ghosts: `ghostAllowance[minter]` (a full mirror), `totalCredited`, `totalMinted`.

#### `invariant_allowanceMatchesGhost`

```
for every minter m:   rule.mintAllowance(m)  ==  ghostAllowance[m]
```

The strongest of the four. The handler recomputes the expected allowance independently after every accepted operation, so this asserts the rule's arithmetic is **exactly** right after *any* interleaving of set / increase / decrease / mint. It subsumes "never underflows" and "monotonically non-increasing across mints" (`INV-7`).

#### `invariant_mintedNeverExceedsCredited`

```
Σ minted  ≤  Σ credited
```

A cumulative safety bound independent of the mirror: across the whole run, minters can never mint more in total than was ever granted to them, regardless of how quotas were reset or adjusted along the way.

#### Emergent property — non-mint transfers never touch a quota

The handler calls `regularTransfer` (a `transferred(spender, from ≠ 0, to, v)` call) and **deliberately leaves the ghost unchanged**. If the rule ever deducted quota on a non-mint path, the mirror would diverge and `invariant_allowanceMatchesGhost` would fail.

### 3.3 `RuleMaxTotalSupply` — the cap holds across any sequence

The handler differs from the other two in two ways:
- It drives a **real CMTAT token** (`CMTATStandardStandalone`, with the rule set directly via `setRuleEngine(rule)`) and pranks the token admin for privileged calls. It is not bound to the rule.
- Mints are **attempted with `try`**, because rejection is an expected outcome. Every other action is bounded so it cannot revert.

Handler actions: `mint` · `mintAtBoundary` · `burnAndMint` · `burn` · `forcedBurn` · `transfer` · `setCap` · `increaseCap` · `decreaseCap`.
- `setCap` ranges from `0` to `4 000`, including caps below the current supply.
- `increaseCap` / `decreaseCap` change the cap in relative steps; the decrease is bounded by the current cap, so it never reverts.
- `forcedBurn` (`forcedTransfer(from, address(0), v)`) bypasses the engine.
- `mintAtBoundary` mints exactly the remaining room −1, +0 or +1. Random amounts almost never land on `headroom + 1`, the only value an off-by-one would let through. Without this action the safety invariant missed such a mutation (§4).

Ghosts: for every attempted mint, whether the rule's decision was right, judged against the supply before the mint (after the burn leg for `burnAndMint`) and the cap in force.

#### `invariant_noMintBreachedTheCap` (safety)

```
every accepted mint:   supplyBefore + value  ≤  cap
```

#### `invariant_noFittingMintWasRejected` (liveness)

```
every rejected mint:   supplyBefore + value  >  cap
```

Without this, a rule that rejected every mint would satisfy the safety invariant trivially.

#### `invariant_mintsFailOnlyWithTheRuleError`

A rejected mint reverts with `RuleMaxTotalSupply_InvalidTransfer` or `…_InvalidTransferFrom` (CMTAT ≥ v3.3 sends mints on the 4-argument path), never with an unrelated error.

#### `invariant_remainingMintableMatchesLiveSupply`

```
remainingMintable()  ==  max(cap − totalSupply(), 0),   code 0
```

Forced burns change the supply without calling the rule, so this also proves the rule never holds a stale view of the supply.

#### `invariant_preflightAgreesWithHeadroom`

A pre-flight check of exactly `headroom` returns `TRANSFER_OK`, both on the rule and through the token's own `detectTransferRestriction`; `headroom + 1` returns code `50`. When the supply is above the cap there is no room at all, and only the second half applies.

### 3.4 `RuleIssuanceCap` — the counter is exact and never restored

`IssuanceCapInvariants` reuses the five invariants of §3.3 unchanged (they are declared once, in `SupplyCapInvariantsBase`), with two differences:
- `IssuanceCapHandler` redefines when a mint should fit: **both** the live supply and the cumulative issuance stay within the cap.
- The expected headroom is the smaller of the two rooms.

The rule is set directly on the token and bound to it. It adds two invariants:

#### `invariant_totalIssuedMatchesGhost`

```
rule.totalIssued()  ==  ghostIssued   (Σ accepted mints, never lowered)
```

Burns, forced burns, transfers and cap changes are all in the action set and never touch the ghost, so this proves none of them move the counter: the rule is non-replenishing.

#### `invariant_issuedCoversSupply`

```
totalIssued  ≥  totalSupply
```

Cumulative issuance can never be below the outstanding supply while every mint is counted. This is the property that makes the inherited live-supply check a pure backstop.

---

## 4. Negative controls — proving the suite can fail

An invariant suite that cannot fail is worthless. Both invariants were **mutation-tested**: a real bug was injected into the rule, the suite was run, and the failure was confirmed. The mutations were then reverted.

| Mutation | Injected bug | Result |
|---|---|---|
| `RuleConditionalTransferLightApprovalBase._transferred` — remove `approvalCounts[hash] = count - 1` | Approval **double-spend**: one approval can be consumed forever | ❌ `invariant_approvalConservation` fails: `approval accounting drifted: 0 != 1` |
| `RuleMintAllowanceBase._transferredFrom` — `current - value` → `current - value + 1` | **Off-by-one** quota deduction: minters slowly gain free quota | ❌ `invariant_allowanceMatchesGhost` fails: `mint allowance drifted from expected: 1938542 != 1938541` |
| `CapAccounting._capExceededBy` — `value > cap - observed` → `value > cap - observed + 1` | **Off-by-one** cap: one unit above the cap gets through | ❌ `invariant_noMintBreachedTheCap` fails: `a mint went through above the cap: 1 != 0` (and `invariant_preflightAgreesWithHeadroom`). Before `mintAtBoundary` was added, only the pre-flight invariant caught it |
| `CapAccounting._capExceededBy` — `>` → `>=` | **Over-strict** cap: a mint landing exactly on the cap is rejected | ❌ `invariant_noFittingMintWasRejected` fails: `a mint that fitted was rejected: 1 != 0` (and `invariant_preflightAgreesWithHeadroom`) |
| `RuleIssuanceCapBase._afterMintChecked` — drop `totalIssued = issued` | **Counter never recorded**: the rule silently becomes replenishing | ❌ `invariant_totalIssuedMatchesGhost` (`counter drifted: 0 != 296`), `invariant_noMintBreachedTheCap`, `invariant_issuedCoversSupply` and `invariant_remainingMintableMatchesLiveSupply` all fail |
| `RuleIssuanceCapBase._issuanceExceededBy` — cap → `cap + 1` | **Off-by-one** issuance cap | ❌ `invariant_noMintBreachedTheCap` fails (`a mint went through above the cap: 1 != 0`), and `invariant_preflightAgreesWithHeadroom` |
| `TotalSupplyCapManager._remainingMintable` — `currentSupply` → `currentSupply + 1` | **Wrong headroom view** while enforcement stays correct | ❌ `invariant_remainingMintableMatchesLiveSupply` fails: `headroom drifted from the live supply: 999 != 1000` |

Re-run these yourself before trusting a change to any of these rules: if you mutate the accounting and the suite still passes, the suite has regressed.

---

## 5. Coverage map

Invariant IDs and their verification status are recorded in [`CLAUDE_AUDIT.md`](../../security/audits/tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md).

| Invariant (threat model) | Property | Covered by |
|---|---|---|
| `INV-5` | `approvalCounts` never underflows; one approval ⇒ one transfer | `invariant_approvalConservation`, `invariant_noApprovalExceedsTotalRecorded` |
| `INV-7` | `mintAllowance` non-increasing across mints, never underflows, `Σ minted ≤ Σ granted` | `invariant_allowanceMatchesGhost`, `invariant_mintedNeverExceedsCredited` |
| `INV-12` (partial) | Mint/burn handled explicitly, never falling into the transfer path | Emergent from both suites (see §3.1, §3.2) |
| — (`RuleIssuanceCap`) | The counter equals Σ accepted mints and is never restored; issuance covers supply; plus every `RuleMaxTotalSupply` property against the combined cap | `invariant_totalIssuedMatchesGhost`, `invariant_issuedCoversSupply`, and the five shared invariants |
| — (`RuleMaxTotalSupply`) | Accepted mints never exceed the cap; fitting mints are never rejected; `remainingMintable()` tracks the live supply, forced burns included | `invariant_noMintBreachedTheCap`, `invariant_noFittingMintWasRejected`, `invariant_mintsFailOnlyWithTheRuleError`, `invariant_remainingMintableMatchesLiveSupply`, `invariant_preflightAgreesWithHeadroom` |

**Not covered by invariants (by design):**

- `INV-1`, `INV-2`, `INV-3`, `INV-9`: properties of *stateless* view functions; unit and fuzz tests are the right tool (`test/ThreatModel/ThreatModelTests.t.sol`).
- `INV-6` (`_transferHash` injectivity): a pure function; covered by `testFuzz_HASH1_ApprovalBucketsAreDistinct`.
- `INV-4`, `INV-11` (access control): covered by the per-rule access-control suites.
- `INV-10` (ERC-2771 binding identity): currently holds by static reasoning; a live regression test remains an open item.

---

## 6. Adding a new invariant

1. Add the action to the relevant handler. **Guard it** so it can only make calls the rule accepts (`fail_on_revert = true` will otherwise fail the run).
2. Update the ghost state *after* the rule call, in the same function. If the rule call reverts, the whole handler call reverts and the ghost rolls back with it, which is what keeps the mirror consistent.
3. Register the new selector in the `targetSelector(...)` array in `RuleInvariants.t.sol`, otherwise it will never be fuzzed.
4. Add the `invariant_*` function, with a message argument on each assertion so a failure is legible.
5. **Mutation-test it.** Inject the bug it is supposed to catch and confirm it fails.

If you add a new stateful rule, it needs its own handler; validation rules do not.
