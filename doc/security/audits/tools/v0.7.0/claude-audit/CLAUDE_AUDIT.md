# Claude Security Audit — CMTA Rules `v0.7.0`

| | |
|---|---|
| **Tool** | Claude (Anthropic), driven by a set of custom smart-contract security-audit skills |
| **Codebase audited** | CMTA Rules `v0.7.0`: the production code under `src/` added or changed since `v0.6.0` |
| **Severity framework** | Code4rena (Critical / High / Medium / Low / Info) |
| **Method** | Threat model → privileged-surface enumeration → targeted manual review → executable proofs-of-concept → adversarial review of every finding |
| **Date** | 2026-10-26 |

**Method note.** The review was driven by a set of internal, task-specific security-audit skills covering the
CMTAT / ERC-3643 compliance model, real-world-asset token checks, the CMTAT audit history, and access control.
Every candidate finding then went through an independent pass whose job was to dismiss or downgrade it; one
finding was downgraded as a result, as recorded below. **The specific internal skills used are intentionally not
enumerated here.**

External tooling: **Foundry** (`forge test`, fuzzing at 256 runs) and **Slither 0.11.6** printers
(`function-summary`, `inheritance-graph`) as a comprehension aid only. No static-analysis output was promoted to a
finding.

This is an AI-assisted review, not an audit by an audit company. Production source does not cite it.

---

## 1. Scope

**In scope:** the code changed between tag `v0.6.0` and `v0.7.0` (122 files under `src/`, +957 / −258 lines):

| Area | Files |
|---|---|
| New rule `RuleIssuanceCap` | `src/rules/operation/RuleIssuanceCap*.sol`, `abstract/RuleIssuanceCapBase.sol`, `abstract/RuleIssuanceCapInvariantStorage.sol` |
| `RuleMaxTotalSupply` changes | `TotalSupplyCapManager.sol` (relative setters, `(previous, new)` event, token-contract hook), `RuleMaxTotalSupplyBase.sol` (non-`view` `transferred`, `_afterMintChecked`, `remainingMintable`), `RuleMaxTotalSupplyRolesStorage.sol` |
| Code 85 for unbound rules | `RuleBindingInvariantStorage.sol`; `_ruleNotBound()` in `RuleConditionalTransferLightBase`, `RuleMintAllowanceBase`, `RuleIssuanceCapBase` |
| Dependency migration | CMTAT `v3.3.0-rc4`, RuleEngine `v3.0.0-rc7` (both `IRule` ids advertised), pragma `^0.8.27`, deployment scripts |
| Convention changes | 63 functions marked `virtual`; comment changes. No runtime effect: runtime sizes identical |

**Out of scope:** `lib/` and `src/mocks/`; the code unchanged since `v0.6.0`, which the `v0.4.0` audit
([`CLAUDE_AUDIT.md`](../../v0.4.0/claude-audit/CLAUDE_AUDIT.md)) and later reviews cover. Dependencies are trusted,
but two of their properties decide in-scope behaviour: RuleEngine `v3.0.0-rc7` can bind **several** tokens, and
its `_checkBoundToken` compares the raw `msg.sender`.

---

## 2. Executive summary

**No Critical, High, Medium or Low issue was found.**

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Info | 5 |

The new `RuleIssuanceCap` enforces its counter correctly on every path a bound caller can reach, and no other
account can reach it. Three of the five Info findings are deployment shapes the rule cannot detect: a RuleEngine
serving several tokens, a binding to the wrong address, and mints made before the rule is attached. The other two
are a missing warning on an extension point of `RuleMaxTotalSupplyBase` and the shared code 85.

### Hypotheses that were checked and found NOT to hold

- **An unprivileged account can inflate or burn the issuance budget.** Both `transferred` overloads, `created` and
  `destroyed` are `onlyBoundToken`; a fuzz test over random callers, spenders and amounts never moves the counter.
  The rule inherits no `RuleNFTAdapter` entrypoints, so there is no ungated `ITransferContext` overload.
- **A second caller can be bound around the single-binding check.** The RuleEngine itself has batch and
  self-binding paths, but `RuleIssuanceCapBase` inherits only the base `ERC3643ComplianceModule`, whose only binding
  entrypoint is `bindToken`, which the rule overrides.
- **The view and the write path disagree.** Fuzzed over random counter, supply, cap and amount up to 2¹²⁸: the
  view reports 0 exactly when the bound mint succeeds, and the 3- and 4-argument views agree.
- **The cap arithmetic overflows.** `CapAccounting` compares headroom rather than `issued + value`; the write-path
  addition runs only after that check.
- **A mint path skips the rule, or notifies it twice.** Every CMTAT mint path (`mint`, `batchMint`, `burnAndMint`,
  `crosschainMint`) reaches the rule exactly once, on CMTAT `v3.3` and `v3.0.0`.

---

## 3. Findings

### 3.1 Summary

| ID | Severity | Status | Finding | Component | PoC |
|---|---|---|---|---|---|
| F-1 | Info (downgraded from Low) | Open | A RuleEngine serving several tokens shares one issuance counter | `RuleIssuanceCapBase.sol` (`bindToken`, `_afterMintChecked`) | `testIC1_SharedEngineCountsOtherTokensMints_CurrentBehaviour`, `testIC1_SharedEngineCapsTokenBByTokenAsCounter_CurrentBehaviour` |
| F-2 | Info | Open | The bound caller is not checked against `tokenContract`; the views report OK | `RuleIssuanceCapBase.sol`, `bindToken` | `testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour` |
| F-3 | Info | Open | `_afterMintChecked` does not warn that `transferred` is ungated | `RuleMaxTotalSupplyBase.sol`, `_afterMintChecked` | `testMTS1_UngatedSubclassIsDrivableByAnyone_CurrentBehaviour` |
| F-4 | Info | Open (documented in part) | Mints before attachment are not counted | `RuleIssuanceCapBase.sol` | `testIC3_IssuanceBeforeAttachIsNotCounted_CurrentBehaviour` |
| F-5 | Info | By design | Code 85 does not say which rule is unbound | `RuleBindingInvariantStorage.sol` | `testB85_EngineSurfacesSharedCode` |

All PoCs are in `test/ThreatModel/ThreatModelV070Tests.t.sol`. Tests suffixed `_CurrentBehaviour` assert the
behaviour the finding describes; fixing the finding must make them fail.

### 3.2 F-1 — A RuleEngine serving several tokens shares one issuance counter (Info, downgraded from Low)

In Topology A the rule binds the **RuleEngine**, and `onlyBoundToken` accepts any call from it. A RuleEngine can
bind several tokens. Every mint of any of them then reaches the same `RuleIssuanceCap` and is recorded in one
`totalIssued`, while the live-supply check reads only `tokenContract`.

```solidity
// RuleIssuanceCapBase: the counter does not know which token minted
function _afterMintChecked(uint256 value) internal virtual override {
    uint256 issued = totalIssued;
    ...
    totalIssued = issued + value;
```

**PoC.** Token B mints 90: `totalIssued` becomes 90 while token A's supply is 0, and token A can then mint only 10
of its cap of 100. The mirror test shows token B blocked by token A's history.

**Impact.** Token A's authorised issuance is consumed by another token (issuance is denied), and token B is
capped by a counter that is not its own. No cap is exceeded for token A and no funds move.

**Severity adjustment.** Submitted as Low; downgraded to Info by the adversarial pass. The trigger is a deliberate
admin configuration that is already warned against: the rule's NatSpec ("One instance per token: the counter is
that token's history"), the rule's documentation ("To protect another token, deploy another instance"), and
RuleEngine's `bindToken` security note that state in stateful rules is shared across all bound tokens. What is
missing is one explicit sentence: the **engine** bound to this rule must serve only `tokenContract`, as
`RuleConditionalTransferLight.bindRuleEngine` already says.

**Recommendation.** Add that sentence to `RuleIssuanceCap.md` § Binding and to the `bindToken` NatSpec.

### 3.3 F-2 — The bound caller is not checked against `tokenContract`; the views report OK (Info)

`bindToken` accepts any non-zero address. If the compliance manager binds a wrong address (a typo, a previous
engine), every operation of the real token reverts with `TokenBinding_UnauthorizedCaller`, but
`detectTransferRestriction` reports 0: code 85 is returned only while **no** caller is bound. `RULE_SEMANTICS.md`
already states that only the fully unbound state is visible to a view.

**Impact.** Admin error only; fails closed. **Recommendation (optional).** Override `_checkBindingTarget(token)` to
accept `address(tokenContract)`, or an engine that reports `isTokenBound(address(tokenContract))` (in `try/catch`).
This catches a wrong binding at configuration time; it does not prevent a second token being bound to the engine
later, so F-1's documentation is still needed.

### 3.4 F-3 — `_afterMintChecked` does not warn that `transferred` is ungated (Info)

`RuleMaxTotalSupplyBase.transferred` became non-`view` in `v0.7.0` so that a subclass can record mints, and anyone
can call it. That is safe for the stock rule, which writes nothing (asserted with `vm.accesses`). The hook's
NatSpec names it as the extension point for recording but does not say that a recording subclass must also restrict
both `transferred` overloads, as `RuleIssuanceCap` does. The PoC subclass, which only overrides the hook, lets any
account record arbitrary mints.

**Impact.** None in shipped contracts; a hazard for library users. **Recommendation.** Add one sentence to the
hook's `@dev`: a subclass that writes in this hook must restrict both `transferred` overloads to its bound caller.

### 3.5 Info findings (condensed)

- **F-4 — mints before attachment are not counted.** The counter starts at `initialIssued` and sees only mints that
  reach the rule. A mint and burn between deployment and attachment is invisible, so lifetime issuance can exceed
  the cap; the live-supply check still keeps the **supply** under it. The detach case is documented ("revoke
  `MINTER_ROLE` first"); the window before first attachment is not. **Recommendation:** extend that warning to it.
- **F-5 — code 85 does not name the unbound rule.** Three rules share `CODE_RULE_NOT_BOUND = 85` and one message.
  This is the stated design; each rule's `detectTransferRestriction` can be queried. No change recommended; the
  adversarial pass considered the finding dismissible.

---

## 4. Invariant Verification

| Invariant | Property | Holds? | Evidence |
|---|---|---|---|
| `INV-IC-1` | `totalIssued` never decreases | ✅ | `IssuanceCapInvariants` (stateful suite with mutation controls); no write path decrements |
| `INV-IC-2` | While bound and attached from deployment, `totalIssued >= totalSupply()` | ✅ conditional | `IssuanceCapInvariants`; does not hold for mints outside that condition (F-4) |
| `INV-IC-3` | A mint succeeds on the write path iff the view reports 0 | ✅ | `testFuzz_IC5_ViewMatchesEnforcement` (256 runs); only a wrong binding diverges (F-2) |
| `INV-IC-4` | Only the bound caller changes `totalIssued` | ✅ | `testFuzz_IC4_OnlyBoundCallerRecords` (256 runs) |
| `INV-IC-5` | At most one caller is bound | ✅ | `testIC4_SingleBindingAndCounterSurvivesRebind` |
| `INV-MTS-1` | The stock `RuleMaxTotalSupply.transferred` writes no storage | ✅ | `testTransferredNeverWritesStorage`, `testMTS1_StockTransferredIsPublicAndStateless` |
| `INV-MTS-2` | `maxTotalSupply` changes only through the setters and never wraps | ✅ | `testFuzz_MTS2_IncreaseDecreaseNeverWrap` (256 runs) |
| `INV-B85` | While unbound, every view of a stateful rule reports 85 and every `transferred` reverts | ✅ | `UnboundRuleViews`, `testB85_EngineSurfacesSharedCode` |

---

## 5. Access-Control Verification

| Function | `RuleIssuanceCap` | `RuleIssuanceCapOwnable2Step` | `RuleMaxTotalSupply` | Verified |
|---|---|---|---|---|
| `transferred` ×2, `created`, `destroyed` | bound caller (raw `msg.sender`) | bound caller | anyone; stateless | ✅ |
| `bindToken` / `unbindToken` | `COMPLIANCE_MANAGER_ROLE` | owner | — | ✅ |
| `setMaxTotalSupply`, `increaseMaxTotalSupply`, `decreaseMaxTotalSupply` | `MAX_TOTAL_SUPPLY_ROLE` | owner | `MAX_TOTAL_SUPPLY_ROLE` | ✅ |
| `setTokenContract` | always reverts | always reverts | `DEFAULT_ADMIN_ROLE` | ✅ |

Negative results: a holder of `MAX_TOTAL_SUPPLY_ROLE` cannot repoint the observed token; the admin cannot repoint
`RuleIssuanceCap`'s token; a trusted forwarder cannot impersonate the bound token, because the check uses the raw
`msg.sender`.

**Centralization premise.** The default admin implicitly holds every role, and the cap role can raise the cap at
will: non-replenishment holds relative to the cap the issuer sets. This is inherent to the model, not a finding.

---

## 6. Remediation — what was implemented

**Nothing yet.** The review changed no production code. All five findings are Info and none changes behaviour for
a correctly configured deployment. The proposed remediations are listed in §7; when one lands, update its
`_CurrentBehaviour` test and record the change in `CLAUDE_ANALYSIS_SUMMARY.md`.

What the review added: 16 tests in `test/ThreatModel/ThreatModelV070Tests.t.sol` (12 unit and integration tests, the
integration ones on a real CMTAT `v3.3` token and RuleEngine `rc7`; 4 fuzz tests). After adding them: `forge test` 1308 passed, 0 failed;
`FOUNDRY_PROFILE=erc3643 forge test` 53 passed, 0 failed; `forge fmt --check` clean.

---

## 7. Potential Improvements (open backlog)

| # | Improvement | Addresses | Effort | Breaking? | Priority |
|---|---|---|---|---|---|
| 1 | State in `RuleIssuanceCap.md` § Binding and the `bindToken` NatSpec that a bound RuleEngine must serve only `tokenContract` | F-1 | Trivial (docs) | No | High |
| 2 | One NatSpec sentence on `_afterMintChecked`: a recording subclass must restrict both `transferred` overloads | F-3 | Trivial (NatSpec) | No | High |
| 3 | Extend the detach warning to the window between deployment and first attachment | F-4 | Trivial (docs) | No | Medium |
| 4 | `_checkBindingTarget` accepting only `tokenContract` or an engine bound to it | F-1, F-2 | Small (code + tests) | No for the standard setup (a RuleEngine binds its token at construction), but the setup order becomes fixed | Low; a design decision |

Items 1–3 close the gap between what the rule needs and what a deployer reads. Item 4 moves part of F-1 and F-2
from documentation into a configuration-time check, at the cost of a fixed setup order (the engine must serve the token before
the rule binds the engine); the maintainers should decide whether that is acceptable.

---

## 8. Scope & duplicate check

All five findings are in scope (code added in `v0.7.0`). None duplicates a static-analysis result: the `v0.7.0`
Slither and Aderyn runs report nothing on these paths except a `dead-code` false positive on `_afterMintChecked`,
which is reached through virtual dispatch. F-1 is a variant of the "one token per instance" limitation already
documented for `RuleMaxTotalSupply` and `RuleChainlinkPoR`, applied to a stateful rule.

**Considered and dismissed:**

| Threat | Reason |
|---|---|
| Cap role raises an issuance cap | Trusted actor; documented |
| Bridge round trips and `burnAndMint` consume issuance | Documented: the rule is not for bridged tokens |
| Live-supply check double-counts on ERC-3643 | ERC-3643 unsupported in `v1`, documented |
| `initialIssued` below the supply | The constructor reverts |
| `MaxTotalSupplyUpdated` reports a wrong `previous` | Read before assignment |
| Code 85 collides with another code | Unique in `src/` and RuleEngine |
| `RuleMintAllowance.canTransfer` returns `false` while unbound | Intended fix, stated in the `v0.7.0` CHANGELOG |
| Legacy `IRule` id claims missing functions | Every selector of the legacy interface is implemented (`RuleInterfaceIdCompatibility`) |
| Scripts pass a forwarder to the plain `RuleEngine` | `RuleEngine2771` is used when a forwarder is set |
| Cap rules lose a leg on CMTAT `v3.0.0` | They ignore the spender, so the 3-argument path loses nothing |

---

## 9. Conclusion

The `v0.7.0` changes introduce no vulnerability. `RuleIssuanceCap` is correct for its documented deployment (one
instance per token, bound to that token or to an engine serving only it), and its counter is closed to every
caller but the bound one. The remaining work is three sentences of documentation and an optional binding check.
