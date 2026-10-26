# Plan — per-token issuance cap (CMTA/Rules#16)

> Status: **implemented in v0.7.0**, with the design of `ISSUE_16_ISSUANCE_CAP_DESIGN_OPTIONS.md` (Option B′), not the standalone design below. Kept as the record of the original proposal.
> **Superseded in part by [`ISSUE_16_ISSUANCE_CAP_DESIGN_OPTIONS.md`](./ISSUE_16_ISSUANCE_CAP_DESIGN_OPTIONS.md):** build `RuleIssuanceCap` as a thin subclass of `RuleMaxTotalSupply` through one new hook, inheriting its cap setters, role, events, live-supply check and deployables, so no code is duplicated. The replenishing option is met by deploying `RuleMaxTotalSupply`, not by a flag. The standalone design below would duplicate most of `RuleMaxTotalSupply`.
>
> Issue: [CMTA/Rules#16](https://github.com/CMTA/Rules/issues/16). Background: [CMTA/CMTAT#405](https://github.com/CMTA/CMTAT/issues/405).

## 1. What the issue asks for

A rule that caps how much a token may issue, **independent of the minter**, and that works with **CMTAT v3.0.0**, where every mint reaches the rule as the 3-argument `transferred(address(0), to, value)`.

| # | Requested behaviour |
| --- | --- |
| R1 | One cap per token, independent of the minter |
| R2 | Each mint decrements the remaining cap; revert if `value` exceeds it |
| R3 | **Non-replenishing by default**: burns do not restore the cap |
| R4 | Optional **replenishing mode** (burn restores the cap), fixed at deployment |
| R5 | Cap changes only through operator functions (set / increase / decrease), with events |
| R6 | `transferred` callable only by the bound token (`msg.sender`) |
| R7 | `canTransfer` and the other views reflect the remaining cap |
| R8 | The 4-argument overload applies the same logic, so it also works on CMTAT ≥ v3.3 |

## 2. Verdict

| Part | Verdict |
| --- | --- |
| Non-replenishing cap (R1–R3, R5–R8) | **Good idea.** It is a real gap: `RuleMintAllowance` is per minter and does nothing on v3.0.0 (it only debits on the 4-argument path). No existing rule tracks *cumulative* issuance. |
| Replenishing mode (R4) | **Bad idea: do not implement it.** It duplicates `RuleMaxTotalSupply` and fails in worse ways (§3). Point the requester to `RuleMaxTotalSupply`, which already works on v3.0.0. |

So the proposal is **one new rule, `RuleIssuanceCap` (+ `RuleIssuanceCapOwnable2Step`), non-replenishing only.**

## 3. Why the replenishing mode should not be built

"Burn restores the cap" means: *outstanding issuance ≤ cap*. That is a cap on **total supply**, and the repository already has it.

`RuleMaxTotalSupply` already fits the requester's setup:
- it acts only when `from == address(0)` and ignores the spender, so it works on the 3-argument path of CMTAT v3.0.0;
- it reads `totalSupply()` before the mint, which is correct because CMTAT notifies the engine *before* `_mint`;
- `setMaxTotalSupply` changes the cap, with an event.

A counter-based replenishing mode would be strictly worse:

1. **It misses forced burns.** `forcedTransfer(from, address(0), value)` does not call the engine, on v3.0.0 or on v3.3. The counter never sees those burns, so it drifts away from the real supply. `RuleMaxTotalSupply` reads `totalSupply()` and sees every burn.
2. **It can trap redemptions.** If holders burn tokens that were minted before the rule was installed, "restore on burn" pushes the counter below zero. The rule must then either saturate, which silently over-restores, or revert, which blocks redemptions. Blocking redemptions is the worst failure a compliance rule can have.
3. **It needs state and a trusted caller where none is needed.** `RuleMaxTotalSupply` is a stateless view: anyone may call `transferred`, it can only revert. A counter must be bound and trust its caller.
4. **A deployment-time mode flag puts two rules in one contract.** That doubles the semantics to audit, test and document, and the flag silently changes what the cap means.

There is one difference, and it favours the existing rule. `RuleMaxTotalSupply` caps the **absolute** supply, including tokens issued before installation. That is what "issue volume outstanding" means for a debt instrument issued and redeemed on an ongoing basis.

For instruments that need both kinds of limit, put the two rules in one `RuleEngine`:
- `RuleMaxTotalSupply` gives outstanding ≤ X;
- `RuleIssuanceCap` gives cumulative issuance ≤ Y.

## 4. Design of `RuleIssuanceCap`

### 4.1 Classification

An **operation rule** (stateful, `src/rules/operation/`), structured like `RuleMintAllowance`:
- `RuleIssuanceCapBase`;
- `RuleIssuanceCapInvariantStorage`;
- two deployables, `RuleIssuanceCap` (AccessControl) and `RuleIssuanceCapOwnable2Step`.

### 4.2 State

```solidity
uint256 public issuanceCap;   // authorised cumulative issuance (e.g. the corporate resolution amount)
uint256 public totalIssued;   // cumulative amount minted while this rule was enforced
function remainingIssuance() public view returns (uint256); // issuanceCap > totalIssued ? issuanceCap - totalIssued : 0
```

The rule stores **cap + issued** instead of a single "remaining" value:
- `issuanceCap` can then be set to the figure in the legal document (the resolution amount), and `totalIssued` is an audit trail;
- a single "remaining" number loses both;
- lowering the cap below `totalIssued` is allowed. It leaves `remainingIssuance() == 0`, which freezes minting. This is the emergency lever the requester described in CMTAT#405. Their reading, not verified here, is that on v3.0.0 `pause` does not stop `mint`.

### 4.3 Constructor and operator functions

| Function | Effect | Event |
| --- | --- | --- |
| `constructor(admin, cap, initialIssued)` | `initialIssued` accounts for issuance before the rule was installed (an existing token, or a replaced rule instance) | `IssuanceCapSet`, `IssuanceInitialized` |
| `setIssuanceCap(newCap)` | absolute | `IssuanceCapSet(old, new)` |
| `increaseIssuanceCap(delta)` | `cap += delta` | `IssuanceCapSet` |
| `decreaseIssuanceCap(delta)` | `cap -= delta`; reverts if `delta > cap` (mirrors `decreaseMintAllowance`) | `IssuanceCapSet` |

- Operator role: `ISSUANCE_CAP_OPERATOR_ROLE`, enforced through `_authorizeSetIssuanceCap()`, which is `internal view virtual` per the convention.
- **No setter for `totalIssued`.** Resetting the counter would turn the cap into an ordinary allowance. Changing the cap already covers every legitimate adjustment, and each change emits an event.

### 4.4 Enforcement (write path)

Both overloads route to one internal function, so R8 holds by construction:

```solidity
function transferred(address from, address to, uint256 value) public override onlyBoundToken { _consume(from, value); }
function transferred(address, address from, address to, uint256 value) public override(IRule, IRuleEngine) onlyBoundToken { _consume(from, value); }

function _consume(address from, uint256 value) internal virtual {
    if (from != address(0) || value == 0) return;          // only mints; zero value is a no-op (CMTAT IRuleEngine requirement)
    uint256 remaining = remainingIssuance();
    require(value <= remaining, RuleIssuanceCap_CapExceeded(address(this), remaining, value));
    totalIssued += value;
    emit IssuanceConsumed(value, totalIssued, issuanceCap);
}
```

- **Reuse `CapAccounting`** for the comparison: `_capExceededBy(totalIssued, issuanceCap, value)` and `_capHeadroom(totalIssued, issuanceCap)`. It is stateless and phase-agnostic, so the cap arithmetic stays shared with the three existing cap rules. Do **not** subclass `RuleMaxTotalSupplyBase`: its `transferred` overloads are `view` and cannot be overridden by a state-changing function. See `ISSUE_16_RULE_MAX_TOTAL_SUPPLY_COVERAGE.md` §4.
- **Burns and transfers are no-ops** (R3). In particular a burn can never revert because of this rule, so redemptions are never blocked.
- `created` / `destroyed` are `onlyBoundToken` no-ops, as in `RuleMintAllowance`. Through a `RuleEngine`, an ERC-3643 `created` already reaches the rule as `transferred(0, to, value)`. Debiting in `created` as well would count each mint twice.

### 4.5 Read path

`_detectTransferRestriction(from, to, value)` returns `CODE_ISSUANCE_CAP_EXCEEDED` when `from == address(0) && value > remainingIssuance()`, and `TRANSFER_OK` otherwise. `…From` ignores the spender.

- It works on the **3-argument** view (R7). `RuleMintAllowance` cannot do this, because its `canTransfer` always returns `true`.
- It does not depend on `msg.sender`, so the answer is the same from any caller, and it cannot revert.
- **Restriction code: `71`** (free; next to `RuleMintAllowance`'s `70`).

### 4.6 Caller restriction (R6)

- Inherit `ERC3643ComplianceModule` (`TokenBindingModule`) as `RuleMintAllowance` does.
- Allow a **single binding**: `bindToken` reverts while a token is bound; `unbindToken` first.
- Since RuleEngine v3.0.0-rc7, `onlyBoundToken` compares the raw `msg.sender`, so a trusted forwarder cannot pose as the token. The rule must not inherit `MetaTxModuleStandalone`.

| Topology | What to bind |
| --- | --- |
| B — `CMTAT.setRuleEngine(rule)` (works on v3.0.0: its `setRuleEngine` has no ERC-165 gate) | the **token** |
| A — behind a `RuleEngine` | the **RuleEngine** |

### 4.7 ERC-3643

The rule debits the `value` passed in the callback and never reads `totalSupply()`. It is therefore **not affected by the ERC-3643 post-update ordering** (NM-11) that forced the `…ERC3643` variants of the supply-cap rules, so it needs no variant. Add it to the compatibility matrix in `RULE_SEMANTICS.md` §6 as **supported via RuleEngine**.

## 5. Limitations to document (not fixable in the rule)

| Limitation | Consequence | Guidance |
| --- | --- | --- |
| `crosschainMint` reaches the rule as a mint, and `crosschainBurn` does not restore the cap | Bridging round trips use up the cap. On v3.0.0 a bridge mint cannot be told apart from a new issuance (spender is `address(0)`) | **Not suitable for bridged tokens.** A future option could exempt a bridge minter on the 4-argument path (CMTAT ≥ v3.3); out of scope for v1 |
| The mint leg of `burnAndMint` consumes the cap | A correction or reissue uses up authorised volume | Operator calls `increaseIssuanceCap` for the reissued amount; the event is the audit trail |
| Removing the rule (`removeRule`, `setRuleEngine(address(0))`) lifts the cap, and mints made meanwhile are never counted | Issuance can exceed the cap without any on-chain signal | Governance: revoke `MINTER_ROLE` before detaching. When replacing the instance, deploy the new one with `initialIssued = old.totalIssued()` |
| One instance per token | Behind a `RuleEngine` bound to several tokens, all their mints share one counter | One engine per token, or Topology B. Same caveat as `RuleMaxTotalSupply` |
| `forcedTransfer` bypasses the engine | It never mints, so it does not affect the counter | No action (stated for completeness) |

## 6. Rejected alternatives

- **Add a "per-token mode" to `RuleMintAllowance`.** It is keyed by minter and debits on the 4-argument path only. On CMTAT ≥ v3.3 every mint carries a non-zero spender, so a global mode would need a different key and different views. A flag that changes what a quota means is the same objection as R4.
- **Derive cumulative issuance from the token.** CMTAT does not track cumulative minted supply, so state in the rule is unavoidable.

## 7. Implementation steps

1. `src/rules/operation/abstract/RuleIssuanceCapInvariantStorage.sol`: role, code `71` and its message, errors, events.
2. `src/rules/operation/abstract/RuleIssuanceCapBase.sol`: §4.2–§4.6.
3. `src/rules/operation/RuleIssuanceCap.sol` and `RuleIssuanceCapOwnable2Step.sol`:
   - ERC-165 advertises `IRULE_INTERFACE_ID`, `IRULE_LEGACY_INTERFACE_ID`, `RULE_ENGINE_INTERFACE_ID`, ERC-1404 extend and `IERC7551Compliance`;
   - the Ownable variant also advertises `Ownable2StepERC165Module`.
4. Add both contracts to `test/Version.t.sol` and `test/InterfaceId/RuleInterfaceIdCompatibility.t.sol`.

## 8. Tests (target 100% coverage)

- **Unit tests:**
  - both overloads debit a mint;
  - transfers, burns and zero-value mints are no-ops;
  - an exact-remaining mint passes and remaining + 1 reverts;
  - cap set / increase / decrease, including below `totalIssued`;
  - `initialIssued`;
  - a non-bound caller is rejected;
  - a second `bindToken` reverts.
- **Views:** `detectTransferRestriction` / `canTransfer` / `…From` agree with enforcement, before and after each operation.
- **CMTAT v3.3 integration** (in-repo submodule): Topology A and B; `mint`, `batchMint`, `burn`, `burnAndMint`, `crosschainMint`.
- **CMTAT v3.0.0 integration**: the point of the issue, so it must be tested against the real token.
  - Done in the repository: `lib/CMTATv3.0.0` is pinned and compiles here (solc 0.8.36, OZ 5.7.0).
  - Add `test/CMTATv3.0.0/RuleIssuanceCapV300.t.sol` on the existing harness (`CMTATv300TestBase` and the four variant mixins).
- **ERC-3643** (`FOUNDRY_PROFILE=erc3643`): a mint through the real T-REX token via a `RuleEngine` is debited exactly once.
- **Invariant tests:**
  - `totalIssued == initialIssued + Σ minted`;
  - `totalIssued` never decreases;
  - burns never change state;
  - a mint above `remainingIssuance()` always reverts.

## 9. Documentation

- New `doc/technical/contracts/RuleIssuanceCap.md`, including the §3 reasoning and the §5 table.
- `RULE_SEMANTICS.md`: per-rule row and §6 ERC-3643 row.
- `doc/README.md` and the root `README.md` (new rule, code `71`).
- `CLAUDE.md` / `AGENTS.md`: rule table and code range.
- `CHANGELOG.md`.

## 10. Proposed answer on the issue (summary)

- **Non-replenishing per-token cap:** accepted as a new rule, `RuleIssuanceCap`. It works on CMTAT v3.0.0 (3-argument path) and ≥ v3.3 (both overloads) and is bound to its caller. Its views reflect the remaining cap. The cross-chain and `burnAndMint` caveats in §5 apply.
- **Replenishing mode:** not planned. Use `RuleMaxTotalSupply`, which already caps outstanding supply on CMTAT v3.0.0. It sees forced burns, which a counter cannot, and it can never block a redemption.
- **Audit scope:** adding the rule before the planned audit puts it in scope at the cost of one more stateful contract. It is small: roughly the size of `RuleMintAllowance`.
