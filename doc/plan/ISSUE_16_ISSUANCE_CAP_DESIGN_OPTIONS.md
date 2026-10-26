# Analysis — where to implement the non-replenishing issuance cap (CMTA/Rules#16)

> Status: **implemented in v0.7.0 as Option B′** (inherit `RuleMaxTotalSupplyBase`, own deployables; see the B′ note below §5). Contracts: `RuleIssuanceCapBase`, `RuleIssuanceCap`, `RuleIssuanceCapOwnable2Step`; documentation: `doc/technical/contracts/RuleIssuanceCap.md`. Earlier status: design analysis. It refines [`ISSUE_16_RULE_ISSUANCE_CAP.md`](./ISSUE_16_RULE_ISSUANCE_CAP.md), which proposed a standalone rule with no replenishing mode, now that `RuleMaxTotalSupply` has gained `remainingMintable()`, `MAX_TOTAL_SUPPLY_ROLE`, `increase` / `decrease` and the `(previous, new)` event ([`ISSUE_16_RULE_MAX_TOTAL_SUPPLY_COVERAGE.md`](./ISSUE_16_RULE_MAX_TOTAL_SUPPLY_COVERAGE.md)).
>
> **Design priority: minimise code duplication.** Every option is scored on how much existing code it copies, not only on correctness and impact.

## 1. The requirement

From the issue:

| # | Requirement |
| --- | --- |
| R3 | **Non-replenishing by default**: burns do not restore the cap |
| R4 | **Optionally a replenishing mode** (burn restores the cap), **fixed at deployment** |
| — | Everything else as already analysed: one cap per token, works on CMTAT v3.0.0 (3-argument mint path) and ≥ v3.3, operator set / increase / decrease with events, views reflect the remaining cap, `transferred` callable only by the bound caller |

Replenishing behaviour is exactly what `RuleMaxTotalSupply` does today: it reads the live `totalSupply()`. The non-replenishing behaviour needs one thing the rule does not have: a **counter of cumulative issuance** (`totalIssued`) and a caller allowed to write it.

Everything else is already implemented once:
- the cap and its setters, `MAX_TOTAL_SUPPLY_ROLE`, the `(previous, new)` event, the revert-free `totalSupply()` read and token validation, in `TotalSupplyCapManager`;
- the cap comparison (`CapAccounting`);
- the ERC-1404 surface, the mint-only routing, `remainingMintable()` and the ERC-3643 re-phasing seam, in `RuleMaxTotalSupplyBase`;
- the role constant, the ERC-165 answers and the access-control hooks, in the deployables.

A design that minimises duplication **adds the counter and nothing else**.

## 2. Constraints that decide between the options

Each was checked against the code or the compiler; none is an opinion.

| # | Constraint | Consequence |
| --- | --- | --- |
| K1 | **A `view` function cannot be overridden by a state-changing one**, but a state-changing one **can** be overridden by a `view` one. Both checked with solc 0.8.36. The first is rejected with *"Overriding function changes state mutability from "view" to "nonpayable""*; the second compiles | A subclass that writes needs the parent's chain to be non-`view`. Read-only-ness can be narrowed in a subclass but never widened back |
| K2 | In `RuleMaxTotalSupplyBase`, every function is now `virtual`. The public `transferred` overloads, `canReturnTransferRestrictionCode` and `messageForTransferRestriction` were made `virtual` in v0.7.0. **`virtual` is free**: it changes no bytecode, ABI or gas, only what the compiler lets a subclass override. The `transferred` overloads and the internal `_transferred` / `_transferredFrom` are still **`view`** | The only real change the subclass needs is dropping `view` from those four functions (K1), plus one empty hook |
| K3 | **A counter needs a trusted writer.** Anyone can call a public `transferred`; with a counter, a caller could inflate it and freeze minting | The counting rule restricts callers (`onlyBoundToken` via `ERC3643ComplianceModule`, as `RuleMintAllowance` does). It binds the token in direct mode, or the RuleEngine behind an engine |
| K4 | **The counter only sees what reaches the rule.** It misses mints made while the rule is detached, and it counts `crosschainMint` and the mint leg of `burnAndMint` as new issuance | A counter-only check can be exceeded silently after a detach. The inherited live-supply check cannot (§5.4) |
| K5 | **Cumulative issuance is always at least the current supply** (`issued ≥ totalSupply`), whenever every mint was counted | `initialIssued` can be validated at construction, and the inherited live-supply check is redundant in normal operation: it only fires when the counter was bypassed |
| K6 | **ERC-3643 re-phases the write path to `_detectTransferRestriction(from, to, 0)`** (`RuleMaxTotalSupplyERC3643`) | If the counter check lives only in `_detectTransferRestriction`, it is evaluated with `value = 0` on ERC-3643 and silently skipped. The counter must also be enforced in a write hook that receives the real `value` (§5.3) |

## 3. Option A — a mode flag inside `RuleMaxTotalSupply` (default: replenishing)

`RuleMaxTotalSupplyBase` gains `immutable mode`, `totalIssued`, the binding module and a mode branch. No new contract.

| | |
| --- | --- |
| Duplication | **None**, and the least new code of all options |
| Impact on existing users | **Breaking for everyone, including users who never pick the new mode:** <br>• the constructor gains a `mode` parameter, and Solidity has no constructor overloading, so the signature changes for every deployment script and integrator; <br>• every deployment gains `bindToken` / `unbindToken` and the binding-manager role; <br>• the counter-free mode would still need either a binding step or a mode-conditional modifier |
| Readability | `maxTotalSupply`, `MaxTotalSupplyUpdated` and code 50 would mean two different things depending on a flag that is invisible in an event or a restriction code |
| Verdict | **Not recommended.** Zero duplication bought with a breaking change to an audited rule that most users deploy in its current form |

## 4. Option C — a sibling rule on `TotalSupplyCapManager`

The previous version of this analysis recommended this. It leaves `RuleMaxTotalSupplyBase` untouched and builds `RuleIssuanceCapBase` beside it, on the manager.

| | |
| --- | --- |
| Duplication | **High.** The sibling cannot inherit `RuleMaxTotalSupplyBase`, so it re-implements about **60 of its 103 code lines**: <br>• the constructor and the 50 / 51 code-to-message mapping; <br>• both `transferred` overloads and the write-path error mapping; <br>• the mint-only `_detectTransferRestriction` live leg and `_detectTransferRestrictionFrom`; <br>• the `_detectTransferRestrictionOnNotify` seam and the `remainingMintable()` wrapper. <br>It also cannot inherit the `RuleMaxTotalSupply` / `…Ownable2Step` deployables (30 code lines each), so it copies their role constant, ERC-165 merge and authorisation hooks. Every future fix to the stock rule's ERC-1404 or ERC-3643 handling must then be made twice |
| Impact on existing users | None |
| Verdict | **Rejected under the duplication priority.** Its only advantage, an untouched `RuleMaxTotalSupplyBase`, costs roughly 110 duplicated code lines |

## 5. Option B — extend `RuleMaxTotalSupply` through hooks (recommended)

### 5.1 Shape

Open `RuleMaxTotalSupplyBase` once (K2), then add the counter in a thin subclass that **inherits the existing deployables**, so even the role constant, the ERC-165 answers and the access-control hooks are reused:

```
TotalSupplyCapManager ── CapAccounting        (unchanged)
          ▲
RuleMaxTotalSupplyBase                        (4 × non-view, 1 new empty hook; already all-virtual)
          ▲                         ▲
RuleMaxTotalSupply[Ownable2Step]   RuleIssuanceCapBase          ← NEW: counter + binding, ~45 code lines
          ▲                         ▲
          └──── RuleIssuanceCap[Ownable2Step] ────┘            ← NEW: ~10 code lines each
                (is RuleMaxTotalSupply, RuleIssuanceCapBase)
```

### 5.2 One-time changes to `RuleMaxTotalSupplyBase`

Already done, at no cost: the public `transferred` overloads, `canReturnTransferRestrictionCode` and `messageForTransferRestriction` are `virtual` (v0.7.0). What remains:

| Change | Why | Effect on `RuleMaxTotalSupply` |
| --- | --- | --- |
| `transferred` (both overloads): drop `view` | K1: the subclass adds `onlyBoundToken` and a write | Selectors and behaviour unchanged. The ABI `stateMutability` of `transferred` changes from `view` to `nonpayable`, which is what `IRule` / `IRuleEngine` already declare. No on-chain caller is affected |
| `_transferred`, `_transferredFrom`: drop `view` | Same | Internal only; no ABI effect |
| New `function _afterMintChecked(uint256 value) internal virtual {}`, called by `_transferred` / `_transferredFrom` after the live check passes, on mints only | The single seam the counter plugs into | Empty: no behaviour or gas change of substance |

**What is lost:** the compiler no longer proves that `RuleMaxTotalSupply`'s write path never writes. Replace that guarantee with a test: `vm.record()`, call both `transferred` overloads, and assert `vm.accesses(rule)` reports **zero storage writes**. A future change that adds a write then fails CI, which is the same protection in a different place. This one test is the whole price of zero duplication.

### 5.3 `RuleIssuanceCapBase` — all the new logic

```solidity
abstract contract RuleIssuanceCapBase is RuleMaxTotalSupplyBase, ERC3643ComplianceModule {
    uint256 public totalIssued;                       // cumulative, never decreases

    constructor(uint256 initialIssued_) {             // K5: issuance can never be below current supply
        (bool ok, uint256 supply) = _currentSupply();
        require(ok && initialIssued_ >= supply, RuleIssuanceCap_InitialIssuedBelowSupply(initialIssued_, supply));
        totalIssued = initialIssued_;
    }

    // Write path: restrict the caller, then reuse the parent unchanged.
    function transferred(address from, address to, uint256 value) public override onlyBoundToken { super.transferred(from, to, value); }
    function transferred(address s, address from, address to, uint256 value) public override onlyBoundToken { super.transferred(s, from, to, value); }

    // The only new behaviour. Enforced here, with the REAL value, so ERC-3643 re-phasing (K6) cannot skip it.
    function _afterMintChecked(uint256 value) internal override {
        require(!_capExceededBy(totalIssued, maxTotalSupply, value), RuleMaxTotalSupply_InvalidTransfer(/* …, */ CODE_ISSUANCE_CAP_EXCEEDED));
        totalIssued += value;
        emit IssuanceRecorded(value, totalIssued);
    }

    // Read path: project the counter leg in front of the inherited live leg.
    function _detectTransferRestriction(address from, address to, uint256 value) internal view override returns (uint8) {
        if (from == address(0) && _capExceededBy(totalIssued, maxTotalSupply, value)) return CODE_ISSUANCE_CAP_EXCEEDED;
        return super._detectTransferRestriction(from, to, value);
    }

    function _remainingMintable() internal view override returns (bool ok, uint256 headroom) {
        (ok, headroom) = super._remainingMintable();                    // live leg
        uint256 counterRoom = _capHeadroom(totalIssued, maxTotalSupply); // counter leg
        if (counterRoom < headroom) headroom = counterRoom;
    }

    // code 71 added to canReturnTransferRestrictionCode / messageForTransferRestriction via super;
    // created / destroyed: onlyBoundToken no-ops; bindToken: single binding (as RuleMintAllowance).
}
```

The comparison (`_capExceededBy`, `_capHeadroom`) comes from `CapAccounting`; nothing is re-implemented.

The counter leg appears twice, in the read path and in the write hook. That is not duplicated logic but the same `CapAccounting` call in two places, which K6 requires. If preferred, it can be factored into one `_issuanceExceeded(value)` helper.

### 5.4 What the subclass gets for free

| Inherited unchanged | From |
| --- | --- |
| `setMaxTotalSupply`, `increaseMaxTotalSupply`, `decreaseMaxTotalSupply`, their errors and `MaxTotalSupplyUpdated(previous, new)` | `TotalSupplyCapManager` |
| Revert-free `totalSupply()` read, token validation, `setTokenContract` | `TotalSupplyCapManager` |
| Live-supply leg (code 50), unreadable supply (code 51), mint-only routing, the spender ignored on both overloads | `RuleMaxTotalSupplyBase` |
| `remainingMintable()` public wrapper | `RuleMaxTotalSupplyBase` (only `_remainingMintable` is overridden) |
| `MAX_TOTAL_SUPPLY_ROLE`, `_authorizeMaxTotalSupplyManager`, `_authorizeTokenContractManager`, ERC-165 merge | the `RuleMaxTotalSupply` / `…Ownable2Step` deployables |

The inherited live leg is also the safety net for K4. Mints made while the rule was detached push `totalSupply` up even though the counter missed them, and the live check then freezes minting at the same cap. By K5 it never rejects a mint the counter accepts in normal operation.

### 5.5 Deployables

```solidity
contract RuleIssuanceCap is RuleMaxTotalSupply, RuleIssuanceCapBase {
    constructor(address admin, address token, uint256 cap, uint256 initialIssued)
        RuleMaxTotalSupply(admin, token, cap) RuleIssuanceCapBase(initialIssued) {}
    // + COMPLIANCE_MANAGER_ROLE binding hooks (_onlyComplianceManager, _authorizeTokenBindingChange),
    //   as in RuleMintAllowance; + the override lists the diamond requires.
}
// RuleIssuanceCapOwnable2Step is RuleMaxTotalSupplyOwnable2Step, RuleIssuanceCapBase: same, onlyOwner.
```

Constructor order matters: `RuleMaxTotalSupplyBase` sets `tokenContract` before `RuleIssuanceCapBase` reads `totalSupply()` for the `initialIssued` check. Linearisation guarantees this, because the shared base runs first.

### 5.6 ERC-3643

`RuleIssuanceCapERC3643 is RuleIssuanceCap` needs only the one-line `_detectTransferRestrictionOnNotify → (from, to, 0)` override that `RuleMaxTotalSupplyERC3643` already has. That is one duplicated line, acceptable, or zero if the override is moved into a shared abstract mixin.

The counter stays correct there because it is enforced in `_afterMintChecked` with the real value (K6). Recommend shipping it later, or stating it as unsupported in `RULE_SEMANTICS.md` §6 for v1.

### 5.7 Behaviour

| Operation | `RuleIssuanceCap` (non-replenishing) | `RuleMaxTotalSupply` (replenishing) |
| --- | --- | --- |
| Mint `value` | Rejected with **71** if `totalIssued + value > cap`, or **50** if `totalSupply + value > cap`; otherwise `totalIssued += value` | Rejected with 50 if `totalSupply + value > cap` |
| Burn, `burnFrom`, `crosschainBurn`, forced burn | Cap **not** restored | Room restored |
| `burnAndMint(b, m)` | The mint leg counts `m` in full | Needs room for `m − b` |
| Bridge round trip | Uses up the cap (unsuitable for bridged tokens) | Net zero |
| Mints while the rule is detached | Not counted, but caught by the inherited live leg | Caught |
| Zero-value mint | No-op | No-op |

### 5.8 Refinement adopted: B′ (own deployables)

After weighing complexity against duplication, the implementation inherits `RuleMaxTotalSupplyBase` (all logic reused) but **not** the `RuleMaxTotalSupply` deployables. Each new deployable repeats roughly 20 lines of standard role and ERC-165 boilerplate. That removes the diamond inheritance of §5.5 and the long override lists it requires, at the cost of boilerplate that every rule in the library already repeats. As implemented:
- `canReturnTransferRestrictionCode` became `public` so the subclass can call `super`.
- The observed token is locked through the `_authorizeTokenContractManager` hook rather than by overriding `setTokenContract`.

## 6. The replenishing mode: a flag or a contract choice?

With Option B the replenishing behaviour **is** the parent class. The issue's R4 ("optionally replenishing, fixed at deployment") is met by choosing which contract to deploy:

| Need | Deploy |
| --- | --- |
| Burns do not restore the cap (default for #16) | `RuleIssuanceCap` |
| Burns restore the cap | `RuleMaxTotalSupply` (already exists, no binding needed) |

An `immutable` mode flag inside `RuleIssuanceCap` would be possible: one branch that skips the counter in `_afterMintChecked`, `_detectTransferRestriction` and `_remainingMintable`. But in replenishing mode the contract would then be `RuleMaxTotalSupply` plus a useless binding step: two contracts with identical behaviour, which is duplication at the product level. **Recommendation: no flag.** Document the two-contract choice in both rules' pages and in the issue answer. The deployment choice is just as "fixed at deployment" as an `immutable` flag, and the contract name states the behaviour.

## 7. Side-by-side

| | A: flag in `RuleMaxTotalSupply` | **B: hook extension** | C: sibling on the manager |
| --- | --- | --- | --- |
| Duplicated code | None | **None** (one ERC-3643 line, avoidable) | ~110 code lines (base logic + deployables) |
| New code | Smallest | ~45 lines base + ~10 per deployable | ~45 + ~110 copied |
| Changes to `RuleMaxTotalSupply` | Breaking: constructor, binding surface, dual semantics | Non-breaking: `view` dropped (ABI `stateMutability` only), one empty hook; compiler guarantee replaced by a storage-write test. (`virtual` already added, at no cost) | None |
| Future fixes to the cap logic | One place | **One place** | Two places |
| Default when deployed | Replenishing | Non-replenishing (`RuleIssuanceCap`) | Non-replenishing |
| Replenishing option (R4) | Flag | **Deploy `RuleMaxTotalSupply`** | Flag, or deploy `RuleMaxTotalSupply` |
| Binding confined to the counting rule | No | **Yes** | Yes |

## 8. Migration and operations

- **From `RuleMaxTotalSupply` to `RuleIssuanceCap`:** deploy with `cap` = the authorised amount and `initialIssued` = the issuance so far (at least `totalSupply()`, enforced). Bind the token or engine, then swap the rule. The swap gap is covered by the live-supply leg.
- **Replacing a `RuleIssuanceCap` instance:** pass `initialIssued = old.totalIssued()`.
- **Bridged tokens:** use `RuleMaxTotalSupply`.
- **Emergency stop:** `setMaxTotalSupply(totalIssued)` or lower; burns and transfers continue.
- **`setTokenContract` on `RuleIssuanceCap`:** inherited, admin-only. Repointing keeps `totalIssued`, which then describes another token's history. Either document it, or override it to revert after construction (open question Q3).

## 9. Test plan

- **Base change:** a `vm.record` / `vm.accesses` test asserting that `RuleMaxTotalSupply.transferred` (both overloads) performs **no storage write**. The existing `RuleMaxTotalSupply` suites, including the CMTAT v3.0.0 and invariant suites, must pass unchanged, which proves the opening is behaviour-neutral.
- **`RuleIssuanceCap` unit tests:**
  - mint at, below and above the counter cap and the live cap (codes 71 and 50);
  - burns not restoring the cap;
  - `burnAndMint`;
  - zero-value mint;
  - `initialIssued` validation;
  - `remainingMintable()` returning the minimum of both legs;
  - caller restriction and single binding;
  - all inherited setters and the role working unchanged.
- **CMTAT v3.0.0 and v3.3** (`test/CMTATv3.0.0/` harness, four variant/topology combinations): the requester's setup, a bridge round trip, detach / re-attach caught by the live leg.
- **Invariants:** extend `MaxTotalSupplyHandler`:
  - `totalIssued == initialIssued + Σ accepted mints`;
  - `totalIssued` never decreases;
  - no accepted mint pushes either leg above the cap;
  - no fitting mint is rejected;
  - mutation controls as in `INVARIANT_TESTS.md` §4.
- **ERC-3643** (if shipped): a mint through the real T-REX token is counted once, and the counter is enforced despite the re-phased `value = 0` notification (K6).

## 10. Open questions

| # | Question | Default proposed |
| --- | --- | --- |
| Q1 | Option B? | Yes |
| Q2 | Accept dropping `view` on `RuleMaxTotalSupply.transferred` (ABI `stateMutability` change, guarded by a no-write test)? | Yes: it is the price of zero duplication, and `IRule` / `IRuleEngine` already declare the function non-`view` |
| Q3 | Should `RuleIssuanceCap.setTokenContract` revert after construction, since the counter describes one token's history? | Yes, one-line override |
| Q4 | Replenishing mode: contract choice (no flag) or an `immutable` flag? | Contract choice (§6) |
| Q5 | Ship the ERC-3643 variant in v1? | No, record it as unsupported in `RULE_SEMANTICS.md` §6 |
| Q6 | Name: `RuleIssuanceCap` or `RuleMaxIssuance`? | `RuleIssuanceCap` |
