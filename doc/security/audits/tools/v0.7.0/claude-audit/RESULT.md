# Result — CMTA Rules v0.7.0 security review (delta since v0.6.0)

> AI-assisted review. Not an audit by an audit company. Production source must not cite this file; code changes it
> causes are recorded in `doc/security/audits/CLAUDE_ANALYSIS_SUMMARY.md`.

Scope, actors and threat IDs: [`THREAT_MODEL.md`](./THREAT_MODEL.md). Test plan:
[`TEST_IMPROVEMENT.md`](./TEST_IMPROVEMENT.md). PoCs: `test/ThreatModel/ThreatModelV070Tests.t.sol`.

**Bottom line: no Critical, High, Medium or Low finding.** The new `RuleIssuanceCap` enforces its counter correctly on
every path a bound caller can reach, and nobody else can reach it. All five findings concern deployment shapes
the rule cannot detect (a RuleEngine serving several tokens, a wrong binding, a gap before attachment) or the
extension contract of `RuleMaxTotalSupplyBase`.

## 1. Claude Skills Used

| Skill | Findings contributed |
|---|---|
| `sc-analyse-and-test-solidity` | Workflow; all findings |
| `rwa-token-audit` | F-2 (view vs enforcement under mis-binding), CH-1 and CH-2 verified safe |
| `cmtat-audit` | V3-1, CH-2 screened as documented design / fixed upstream |
| `audit-cmtat` | F-1 (engine fan-out), IF-1 verified safe |
| `audit-access-control` | F-3, AC-1 to AC-4 verified safe |

## 2. Test execution summary

`forge test --match-contract ThreatModelV070Tests -vv`: **16 passed, 0 failed** (fuzz: 256 runs each).

| Test | Threat | Type | Gas (μ for fuzz) | Result |
|---|---|---|---|---|
| `testIC1_SharedEngineCountsOtherTokensMints_CurrentBehaviour` | IC-1 | Integration | 13,824,064 | PASS |
| `testIC1_SharedEngineCapsTokenBByTokenAsCounter_CurrentBehaviour` | IC-1 | Integration | 13,758,165 | PASS |
| `testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour` | IC-2 | Integration | 6,650,260 | PASS |
| `testIC3_IssuanceBeforeAttachIsNotCounted_CurrentBehaviour` | IC-3 | Integration | 6,736,733 | PASS |
| `testIC3_LiveLegCatchesDetachedOverMint` | IC-3 | Integration | 6,743,397 | PASS |
| `testFuzz_IC4_OnlyBoundCallerRecords` | AC-2 | Fuzz | 1,637,079 | PASS |
| `testIC4_SingleBindingAndCounterSurvivesRebind` | AC-3 | Unit | 1,681,549 | PASS |
| `testIC4_TokenContractLockedForAdmin` | AC-4 | Unit | 1,616,486 | PASS |
| `testFuzz_IC5_ViewMatchesEnforcement` | IC-5, IC-10 | Fuzz | 1,676,316 | PASS |
| `testIC5_ZeroValueMintRefusedAboveCap` | IC-5 | Unit | 1,652,062 | PASS |
| `testIC6_CapRoleCanRaiseIssuanceCap` | IC-6 | Integration | 6,749,819 | PASS |
| `testMTS1_StockTransferredIsPublicAndStateless` | AC-5 | Unit | 1,249,102 | PASS |
| `testMTS1_UngatedSubclassIsDrivableByAnyone_CurrentBehaviour` | AC-5 | Unit | 1,285,115 | PASS |
| `testMTS2_CapRoleCannotRepointToken` | AC-1 | Unit | 1,415,352 | PASS |
| `testFuzz_MTS2_IncreaseDecreaseNeverWrap` | MTS-2 | Fuzz | 1,248,685 | PASS |
| `testB85_EngineSurfacesSharedCode` | B85-1 | Integration | 8,502,143 | PASS |

Tests suffixed `_CurrentBehaviour` assert behaviour this review considers a hazard: a fix must make them fail.

Full suites after adding the PoCs: see §7.

## 3. Findings

### Findings summary

| ID | Short description | Severity | Status | Component / location | Skill | PoC |
|---|---|---|---|---|---|---|
| F-1 | Multi-token RuleEngine shares one issuance counter | Info (judge: Low → Info) | Confirmed | `RuleIssuanceCapBase.sol` (`bindToken`, `_afterMintChecked`); `RuleIssuanceCap.md` § Binding | `audit-cmtat` | `testIC1_*` (2) |
| F-2 | Binding not tied to `tokenContract`; views report OK | Info | Confirmed | `RuleIssuanceCapBase.sol`, `bindToken` | `rwa-token-audit` | `testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour` |
| F-3 | `_afterMintChecked` hook does not warn that `transferred` is ungated | Info | Confirmed | `RuleMaxTotalSupplyBase.sol`, `_afterMintChecked` NatSpec | `audit-access-control` | `testMTS1_UngatedSubclassIsDrivableByAnyone_CurrentBehaviour` |
| F-4 | Mints before attachment are invisible to the counter | Info | By-design, documented | `RuleIssuanceCapBase.sol` | Independent analysis | `testIC3_IssuanceBeforeAttachIsNotCounted_CurrentBehaviour` |
| F-5 | Code 85 does not identify which rule is unbound | Info (judge: dismissible) | By-design | `RuleBindingInvariantStorage.sol` | Independent analysis | `testB85_EngineSurfacesSharedCode` |
| AC-1 | Cap role cannot repoint the token | — | NOT-A-FINDING (verified) | `RuleMaxTotalSupply.sol` hooks | `audit-access-control` | `testMTS2_CapRoleCannotRepointToken` |
| AC-2 | Only the bound caller moves the counter | — | NOT-A-FINDING (verified) | `RuleIssuanceCapBase.sol` | `audit-access-control` | `testFuzz_IC4_OnlyBoundCallerRecords` |
| AC-3 | No second binding path | — | NOT-A-FINDING (verified) | `RuleIssuanceCapBase` inherits only the base `ERC3643ComplianceModule` | `audit-access-control` | `testIC4_SingleBindingAndCounterSurvivesRebind` |
| AC-4 | `setTokenContract` locked | — | NOT-A-FINDING (verified) | `_authorizeTokenContractManager` | `audit-access-control` | `testIC4_TokenContractLockedForAdmin` |
| AC-5 | Stock `transferred` public but stateless | — | NOT-A-FINDING (see F-3 for subclasses) | `RuleMaxTotalSupplyBase.sol` | `audit-access-control` | `testMTS1_StockTransferredIsPublicAndStateless` |
| IC-5 | View and enforcement agree | — | NOT-A-FINDING (verified) | `RuleIssuanceCapBase.sol` | `rwa-token-audit` | `testFuzz_IC5_ViewMatchesEnforcement` |
| IC-6 | Cap role can raise the cap | — | NOT-A-FINDING (trusted actor) | `TotalSupplyCapManager.sol` | `audit-access-control` | `testIC6_CapRoleCanRaiseIssuanceCap` |
| IC-7 | Bridge round trips / `burnAndMint` use up the cap | — | NOT-A-FINDING (documented) | `RuleIssuanceCap.md` | `cmtat-audit` | `RuleIssuanceCapV300` suite |
| IC-8 | ERC-3643 double count | — | NOT-A-FINDING (unsupported, documented) | `RuleIssuanceCap.md` § ERC-3643 | `rwa-token-audit` | Unit re-phase harness |
| IC-9 | `initialIssued` below supply | — | NOT-A-FINDING (constructor reverts) | constructor | Independent analysis | `RuleIssuanceCapUnit` |
| IC-10 | Overflow on the write or read path | — | NOT-A-FINDING (verified) | `CapAccounting.sol` | Independent analysis | `testFuzz_IC5_ViewMatchesEnforcement` |
| MTS-2 | Increase / decrease wrap | — | NOT-A-FINDING (verified) | `TotalSupplyCapManager.sol` | Independent analysis | `testFuzz_MTS2_IncreaseDecreaseNeverWrap` |
| MTS-3 | Wrong `previous` in the event | — | NOT-A-FINDING (verified) | `_setMaxTotalSupply` | Independent analysis | existing event tests |
| B85-2 | Code 85 collides | — | NOT-A-FINDING (unique in `src/` and RuleEngine) | restriction-code space | Independent analysis | ✗ (grep) |
| B85-3 | `RuleMintAllowance.canTransfer` semantics change | — | NOT-A-FINDING (documented in CHANGELOG v0.7.0) | `RuleMintAllowanceBase.sol` | Independent analysis | `UnboundRuleViews` |
| IF-1 | Legacy `IRule` id over-claims | — | NOT-A-FINDING (verified) | `RuleTransferValidation.sol` | `audit-cmtat` | `RuleInterfaceIdCompatibility` |
| IF-2 | Scripts pick the wrong engine | — | NOT-A-FINDING (verified) | `script/DeployCMTATWith*.s.sol` | Independent analysis | CI `forge script` dry run |
| CH-1 | A mint path skips the rule | — | NOT-A-FINDING (verified) | CMTAT mint paths | `rwa-token-audit` | `RuleIssuanceCapV300`, integration |
| CH-2 | Hook fires twice per mint | — | NOT-A-FINDING (verified) | CMTAT / RuleEngine | `cmtat-audit` | integration (`totalIssued == CAP` after 60 + 40) |
| V3-1 | Cap rules lose a leg on CMTAT v3.0.0 | — | NOT-A-FINDING (spender ignored by design) | 3-arg path | `cmtat-audit` | `test/CMTATv3.0.0/` |

**Tally: 0 Critical, 0 High, 0 Medium, 0 Low, 5 Info; 20 threats verified safe or by design.** F-1 was submitted as Low and downgraded by the judge (§8).

### F-1 — A RuleEngine serving several tokens shares one issuance counter (Info, downgraded from Low)

- **Location:** `src/rules/operation/abstract/RuleIssuanceCapBase.sol`, `bindToken` and `_afterMintChecked`;
  `doc/technical/contracts/RuleIssuanceCap.md`, § Binding.
- **Skill:** `audit-cmtat` (check 4, RuleEngine integration).

In Topology A the rule binds the **RuleEngine**, and `onlyBoundToken` accepts any call from it. RuleEngine rc7 is
multi-tenant: `TokenBindingModule.bindToken` adds to a set, so one engine can serve tokens A and B. Every mint of
either token then reaches the same `RuleIssuanceCap` and is recorded in one `totalIssued`, while the live-supply
leg reads only `tokenContract` (token A).

```solidity
// RuleIssuanceCapBase: the counter has no notion of which token minted
function _afterMintChecked(uint256 value) internal virtual override {
    uint256 issued = totalIssued;
    ...
    totalIssued = issued + value;
```

PoC (`testIC1_SharedEngineCountsOtherTokensMints_CurrentBehaviour`): token B mints 90; `totalIssued` becomes 90
while token A's supply is 0; token A can then mint only 10 of its cap of 100. The mirror test shows token B blocked
by token A's history.

**Impact.** Wrong enforcement for both tokens: token A's authorised issuance is consumed by another token (a
denial of issuance), and token B is capped by a counter that is not its own. No funds move and no cap is exceeded
for token A. The precondition is a deliberate admin configuration that is already warned against: the rule's
NatSpec says "One instance per token: the counter is that token's history", `RuleIssuanceCap.md` says "To protect
another token, deploy another instance", and RuleEngine's `bindToken` carries a `@custom:security-note` that
downstream state of stateful rules is shared across all bound tokens. What is missing is the explicit statement,
in `RuleIssuanceCap.md` § Binding and the `bindToken` NatSpec, that the **bound engine** must serve only
`tokenContract` (as `RuleConditionalTransferLight.bindRuleEngine` says). Fails closed, no funds move: Info.

**Recommendation.** Documentation, at minimum: in `RuleIssuanceCap.md` § Binding and in the `bindToken` NatSpec,
state that the bound RuleEngine must serve only `tokenContract`. Optional hardening (see F-2): in
`_checkBindingTarget`, accept `token == tokenContract`, or an engine that reports `isTokenBound(tokenContract)`.
That catches a wrong binding but not a second token bound to the engine later, so the documentation is still
needed.

### F-2 — The bound caller is not checked against `tokenContract`; views report OK (Info)

- **Location:** `RuleIssuanceCapBase.bindToken`.
- **Skill:** `rwa-token-audit` (check 7, view vs enforcement).

`bindToken` accepts any non-zero address. If the compliance manager binds a wrong address (a typo, the previous
engine), every operation of the real token reverts with `TokenBinding_UnauthorizedCaller`, but
`detectTransferRestriction` reports 0, because code 85 is only returned while **no** caller is bound.
PoC: `testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour`.

**Impact.** Admin error only; fails closed (no mint can succeed). The divergence is the same class H-1 closed for
the unbound case, but for a wrong binding no view can detect it without knowing the caller.

**Recommendation.** Optional: override `_checkBindingTarget(token)` to require `token == address(tokenContract)`
or `ITokenBinding(token).isTokenBound(address(tokenContract))` (in `try/catch`). Cheap, configuration-time only.

### F-3 — `_afterMintChecked` does not warn that `transferred` is ungated (Info)

- **Location:** `src/rules/validation/abstract/base/RuleMaxTotalSupplyBase.sol`, NatSpec of `_afterMintChecked`.
- **Skill:** `audit-access-control`.

`RuleMaxTotalSupplyBase.transferred` became non-`view` in v0.7.0 so that a subclass can record mints, and it is
callable by anyone. That is safe for the stock rule, which writes nothing (`testTransferredNeverWritesStorage`,
`testMTS1_StockTransferredIsPublicAndStateless`). The hook's NatSpec presents it as *the* extension point for
recording, without saying that a recording subclass must also gate both `transferred` overloads, as
`RuleIssuanceCap` does with `onlyBoundToken`. PoC `testMTS1_UngatedSubclassIsDrivableByAnyone_CurrentBehaviour`:
a subclass that only overrides the hook lets any account record arbitrary mints.

**Impact.** None in shipped contracts. A library-user hazard: the library exists to be subclassed, and the
documented extension point leads to an open write path.

**Recommendation.** Add one sentence to the hook's `@dev`: "`transferred` is public and ungated here; a subclass
that writes in this hook must restrict both overloads to its bound caller."

### F-4 — Mints before attachment are invisible to the counter (Info, by design)

The counter starts at `initialIssued` and only sees mints that reach the rule. A mint-and-burn between deployment
and attachment (or while detached) is not counted, so lifetime issuance can exceed the cap. The live-supply leg
still keeps the **supply** under the cap (`testIC3_LiveLegCatchesDetachedOverMint`). Documented: the WARNING in
`RuleIssuanceCap.md` ("detaching the rule lifts the cap while detached; revoke `MINTER_ROLE` first") and design
note K4. **Recommendation:** extend the existing WARNING to the window between deployment and attachment (deploy,
bind and attach before granting `MINTER_ROLE`).

### F-5 — Code 85 does not identify which rule is unbound (Info, by design)

Three rules share `CODE_RULE_NOT_BOUND = 85` and one message. Behind a RuleEngine with several stateful rules, the
token reports 85 without naming the rule (`testB85_EngineSurfacesSharedCode`). One shared constant is the stated
design (it avoids a code per rule for the same condition); the operator can query each rule's
`detectTransferRestriction`. No change recommended.

### Non-findings (one line each)

- **AC-1:** `setTokenContract` requires `DEFAULT_ADMIN_ROLE` (owner on Ownable2Step); a holder of `MAX_TOTAL_SUPPLY_ROLE` is rejected.
- **AC-2:** both `transferred` overloads, `created` and `destroyed` are `onlyBoundToken`, which compares raw `msg.sender` (not `_msgSender()`), so a forwarder cannot impersonate the token.
- **AC-3:** the RuleEngine itself adds batch and self-binding paths (`ERC3643ComplianceExtendedModule`), but `RuleIssuanceCapBase` inherits only the base `ERC3643ComplianceModule`, whose sole binding entry point is `bindToken`, which the rule overrides; there is no path around the single-binding check.
- **AC-4:** `_authorizeTokenContractManager` always reverts, for every caller.
- **IC-5 / IC-10:** the fuzz test compares view and write over random `(issued, supply ≤ issued, cap, value)` up to 2¹²⁸; they agree and `totalIssued` moves only on success. `CapAccounting` compares headroom, so `issued + value` never overflows in a view; the write-path addition happens only after the headroom check.
- **IC-6:** raising the cap is a trusted-role action; non-replenishment is relative to the cap, as documented.
- **IC-7 / IC-8:** documented as unsuitable (bridged tokens) and unsupported (ERC-3643), with tests.
- **IC-9:** the constructor requires `initialIssued >= totalSupply()`.
- **MTS-2 / MTS-3:** named errors before any write; `previous` read before assignment.
- **B85-2:** 85 appears once in `src/` and not in RuleEngine; the duplicated 46 is the documented CTL / multi-token pair.
- **B85-3:** the change from `true` to `false` while unbound is a fix (H-1), stated in the v0.7.0 CHANGELOG.
- **IF-1:** both ids are advertised and every selector of the legacy flattened interface is implemented (`RuleInterfaceIdCompatibility`).
- **IF-2:** scripts use `RuleEngine(deployer, token)` with no forwarder and `RuleEngine2771` otherwise; the deployer is a parameter.
- **CH-1 / CH-2:** every CMTAT mint path (`mint`, `batchMint`, `burnAndMint`, `crosschainMint`) reaches the rule exactly once; integration and v3.0.0 suites assert the counter equals the minted amount.
- **V3-1:** the cap rules ignore the spender, so the 3-argument path loses nothing.

## 4. Invariant verification

| Invariant | Holds | Evidence |
|---|---|---|
| INV-IC-1 counter never decreases | Yes | `IssuanceCapInvariants`; no write path decrements |
| INV-IC-2 issuance ≥ supply while attached from deployment | Yes, **conditional** | `IssuanceCapInvariants`; broken by design outside that condition (F-4) |
| INV-IC-3 view OK iff write succeeds | Yes | `testFuzz_IC5_ViewMatchesEnforcement`; only the wrong-binding case diverges (F-2) |
| INV-IC-4 only the bound caller changes the counter | Yes | `testFuzz_IC4_OnlyBoundCallerRecords` |
| INV-IC-5 at most one bound caller | Yes | `testIC4_SingleBindingAndCounterSurvivesRebind` |
| INV-MTS-1 stock `transferred` writes nothing | Yes | `testTransferredNeverWritesStorage`, `testMTS1_StockTransferredIsPublicAndStateless` |
| INV-MTS-2 cap changes only via setters, never wraps | Yes | `testFuzz_MTS2_IncreaseDecreaseNeverWrap` |
| INV-B85 unbound: 85 everywhere, writes revert | Yes | `UnboundRuleViews`, `testB85_EngineSurfacesSharedCode` |

## 5. Access-control verification

| Function | `RuleIssuanceCap` | `RuleIssuanceCapOwnable2Step` | `RuleMaxTotalSupply` | Tested |
|---|---|---|---|---|
| `transferred` ×2, `created`, `destroyed` | bound caller | bound caller | anyone (stateless) | Yes |
| `bindToken` / `unbindToken` | `COMPLIANCE_MANAGER_ROLE` | owner | — | Yes |
| `setMaxTotalSupply`, `increase…`, `decrease…` | `MAX_TOTAL_SUPPLY_ROLE` | owner | `MAX_TOTAL_SUPPLY_ROLE` | Yes |
| `setTokenContract` | always reverts | always reverts | `DEFAULT_ADMIN_ROLE` | Yes |

## 6. Recommendations

| Priority | Action | Finding |
|---|---|---|
| 1 | State in `RuleIssuanceCap.md` § Binding and the `bindToken` NatSpec that a bound RuleEngine must serve only `tokenContract` | F-1 |
| 2 | Add one sentence to the `_afterMintChecked` NatSpec: a recording subclass must gate both `transferred` overloads | F-3 |
| 3 | Extend the detach WARNING to the window between deployment and attachment | F-4 |
| 4 | Optional: `_checkBindingTarget` accepting only `tokenContract` or an engine bound to it | F-1, F-2 |

None of these changes behaviour for a correct deployment. If F-1 and F-3 are fixed in code or NatSpec, update the
`_CurrentBehaviour` tests and record the change in `CLAUDE_ANALYSIS_SUMMARY.md`.

## 7. Build and full-suite results

| Command | Result |
|---|---|
| `forge fmt --check` | clean |
| `forge build` | OK (solc 0.8.38) |
| `forge test` | **1308 passed, 0 failed** (175 suites; 1292 before this review + 16 PoCs) |
| `FOUNDRY_PROFILE=erc3643 forge test` | **53 passed, 0 failed** |

Slither 0.11.6 printers (`function-summary` for the six in-scope deployables, `inheritance-graph`) are in
[`slither-graph/`](./slither-graph/). The detector run for this release is `../slither-report.md`.

## 8. Agent judge

An independent agent, asked to dismiss or downgrade each finding from the code and documentation, re-ran the 16
PoCs (all pass) and returned:

| Finding | Verdict | Argument |
|---|---|---|
| F-1 | **Downgraded Low → Info** | Admin choice already warned against (rule NatSpec, rule doc, RuleEngine `@custom:security-note` on `bindToken`); fails closed. Only the explicit "the bound engine must serve one token" sentence is missing |
| F-2 | Confirmed, Info | `RULE_SEMANTICS.md` already says only the fully unbound state is visible to a view |
| F-3 | Confirmed, Info | Library-user guidance; no shipped contract affected |
| F-4 | Confirmed, Info (borderline) | Issuer controls `MINTER_ROLE` throughout; same as the documented detach case |
| F-5 | Dismissible | Stated design; each rule's view can be queried |
| AC-3 | Conclusion right, wording corrected | The engine has extra binding paths; the rule does not inherit them |
| IC-10, CH-2 | Correct | `_capExceededBy` cannot overflow; the hook runs once per notification |

The corrections are applied above.
