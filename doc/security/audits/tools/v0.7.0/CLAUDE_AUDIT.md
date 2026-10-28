# Claude Security Audit — CMTA Rules `v0.7.0`

| | |
|---|---|
| **Tool** | Claude (Anthropic), driven by a set of custom smart-contract security-audit skills |
| **Codebase audited** | CMTA Rules `v0.7.0`: the production code under `src/` added or changed since `v0.6.0` |
| **Severity framework** | Code4rena (Critical / High / Medium / Low / Info) |
| **Method** | Threat model → privileged-surface enumeration → targeted manual review → executable proofs-of-concept → adversarial review of every finding |
| **Date** | 2026-10-26 |

**Method note.** The review was driven by a set of internal, task-specific security-audit skills covering the CMTAT / ERC-3643 compliance model, real-world-asset token checks, the CMTAT audit history, and access control. Every candidate finding then went through an independent pass whose job was to dismiss or downgrade it; one finding was downgraded as a result, as recorded below. **The specific internal skills used are intentionally not enumerated here.**

External tooling: **Foundry** (`forge test`, fuzzing at 256 runs) and **Slither 0.11.6** printers (`function-summary`, `inheritance-graph`) as a comprehension aid only. No static-analysis output was promoted to a finding.

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

**Out of scope:** `lib/` and `src/mocks/`; the code unchanged since `v0.6.0`, which the `v0.4.0` audit ([`CLAUDE_AUDIT.md`](../v0.4.0/claude-audit/CLAUDE_AUDIT.md)) and later reviews cover. Dependencies are trusted, but two of their properties decide in-scope behaviour: RuleEngine `v3.0.0-rc7` can bind **several** tokens, and its `_checkBoundToken` compares the raw `msg.sender`.

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

The new `RuleIssuanceCap` enforces its counter correctly on every path open to a bound caller, and no other account can call those paths. Three of the five Info findings are deployment configurations the rule cannot detect: a RuleEngine serving several tokens, a binding to the wrong address, and mints made before the rule is attached. The other two are a missing warning on an extension point of `RuleMaxTotalSupplyBase` and the shared code 85.

### Hypotheses that were checked and found NOT to hold

- **An unprivileged account can inflate or burn the issuance budget.** Both `transferred` overloads, `created` and `destroyed` are `onlyBoundToken`; a fuzz test over random callers, spenders and amounts never moves the counter. The rule inherits no `RuleNFTAdapter` entrypoints, so there is no ungated `ITransferContext` overload.
- **A second caller can be bound around the single-binding check.** The RuleEngine itself has batch and self-binding paths, but `RuleIssuanceCapBase` inherits only the base `ERC3643ComplianceModule`, whose only binding entrypoint is `bindToken`, which the rule overrides.
- **The view and the write path disagree.** Fuzzed over random counter, supply, cap and amount up to 2¹²⁸: the view reports 0 exactly when the bound mint succeeds, and the 3- and 4-argument views agree.
- **The cap arithmetic overflows.** `CapAccounting` compares headroom rather than `issued + value`; the write-path addition runs only after that check.
- **A mint path skips the rule, or notifies it twice.** Every CMTAT mint path (`mint`, `batchMint`, `burnAndMint`, `crosschainMint`) calls the rule exactly once, on CMTAT `v3.3` and `v3.0.0`.

---

## 3. Findings

### 3.1 Summary

| ID | Severity | Status | Finding | Component | PoC |
|---|---|---|---|---|---|
| F-1 | Info (downgraded from Low) | ⚠️ Documented | A RuleEngine serving several tokens shares one issuance counter | `RuleIssuanceCapBase.sol` (`bindToken`, `_afterMintChecked`) | `testIC1_SharedEngineCountsOtherTokensMints_CurrentBehaviour`, `testIC1_SharedEngineCapsTokenBByTokenAsCounter_CurrentBehaviour` |
| F-2 | Info | ⛔ Declined | The bound caller is not checked against `tokenContract`; the views report OK | `RuleIssuanceCapBase.sol`, `bindToken` | `testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour` |
| F-3 | Info | ⚠️ Documented | `_afterMintChecked` does not warn that `transferred` is ungated | `RuleMaxTotalSupplyBase.sol`, `_afterMintChecked` | `testMTS1_UngatedSubclassIsDrivableByAnyone_CurrentBehaviour` |
| F-4 | Info | ⚠️ Documented | Mints before attachment are not counted | `RuleIssuanceCapBase.sol` | `testIC3_IssuanceBeforeAttachIsNotCounted_CurrentBehaviour` |
| F-5 | Info | By design | Code 85 does not say which rule is unbound | `RuleBindingInvariantStorage.sol` | `testB85_EngineSurfacesSharedCode` |

All PoCs are in `test/ThreatModel/ThreatModelV070Tests.t.sol`. Tests suffixed `_CurrentBehaviour` assert the behaviour the finding describes; fixing the finding must make them fail.

### 3.2 F-1 — A RuleEngine serving several tokens shares one issuance counter (Info, downgraded from Low)

In Topology A the rule binds the **RuleEngine**, and `onlyBoundToken` accepts any call from it. A RuleEngine can bind several tokens. Every mint of any of them is then forwarded to the same `RuleIssuanceCap` and is recorded in one `totalIssued`, while the live-supply check reads only `tokenContract`.

```solidity
// RuleIssuanceCapBase: the counter does not know which token minted
function _afterMintChecked(uint256 value) internal virtual override {
    uint256 issued = totalIssued;
    ...
    totalIssued = issued + value;
```

**PoC.** Token B mints 90: `totalIssued` becomes 90 while token A's supply is 0, and token A can then mint only 10 of its cap of 100. The mirror test shows token B blocked by token A's history.

**Impact.** Token A's authorised issuance is consumed by another token (issuance is denied), and token B is capped by a counter that is not its own. No cap is exceeded for token A and no funds move.

**Severity adjustment.** Submitted as Low; downgraded to Info by the adversarial pass. The trigger is a deliberate admin configuration that is already warned against: the rule's NatSpec ("One instance per token: the counter is that token's history"), the rule's documentation ("To protect another token, deploy another instance"), and RuleEngine's `bindToken` security note that state in stateful rules is shared across all bound tokens. What is missing is one explicit sentence: the **engine** bound to this rule must serve only `tokenContract`, as `RuleConditionalTransferLight.bindRuleEngine` already says.

**Recommendation.** Add that sentence to `RuleIssuanceCap.md` § Binding and to the `bindToken` NatSpec.

**Status: documented, behaviour unchanged** (see §6). The PoCs still pass, as they should: the configuration is now warned against, not prevented.

### 3.3 F-2 — The bound caller is not checked against `tokenContract`; the views report OK (Info)

`bindToken` accepts any non-zero address. If the compliance manager binds a wrong address (a typo, a previous engine), every operation of the real token reverts with `TokenBinding_UnauthorizedCaller`, but `detectTransferRestriction` reports 0: code 85 is returned only while **no** caller is bound. `RULE_SEMANTICS.md` already states that only the fully unbound state is visible to a view.

**Impact.** Admin error only; it fails closed (no mint can succeed through a wrong binding). The cost is diagnosis: an operator sees every mint revert with `TokenBinding_UnauthorizedCaller` while the token's `detectTransferRestriction` answers 0, and nothing on-chain says the binding is the cause.

#### Context: where a check could go

`bindToken` in `RuleIssuanceCapBase` ends in `TokenBindingModule._bindToken`, which already calls a hook made for this purpose: `_checkBindingTarget(address token) internal view virtual`, empty in RuleEngine `rc7` ("hook for host-specific restrictions on which addresses may be bound; reverts to reject"). Every binding path the rule inherits goes through it, and `unbindToken` does not, so a wrong binding can always be removed.

Two legitimate targets exist, one per topology:

| Topology | Correct target | How to recognise it on-chain |
|---|---|---|
| B, rule set directly on the token | the token | `target == address(tokenContract)` |
| A, rule inside a RuleEngine | the engine | `IERC3643Compliance(target).isTokenBound(address(tokenContract))` returns `true`. `isTokenBound` is part of the ERC-3643 compliance interface, which RuleEngine implements (`ITokenBinding`) |

#### Option A: check at binding time (recommended if implemented)

```solidity
// RuleIssuanceCapInvariantStorage
error RuleIssuanceCap_BindingTargetNotServingToken(address target, address tokenContract);

// RuleIssuanceCapBase
/**
 * @notice Accepts only the observed token, or an engine that already serves it.
 */
function _checkBindingTarget(address target) internal view virtual override {
    address token = address(tokenContract);
    if (target == token) {
        return;
    }
    require(_servesToken(target, token), RuleIssuanceCap_BindingTargetNotServingToken(target, token));
}

/**
 * @notice True when `engine` reports `token` as bound. Never reverts.
 */
function _servesToken(address engine, address token) internal view virtual returns (bool) {
    // A `try` to a codeless address (an EOA, a typo) fails outside the `catch`; reject it explicitly.
    if (engine.code.length == 0) {
        return false;
    }
    try ITokenBinding(engine).isTokenBound(token) returns (bool bound) {
        return bound;
    } catch {
        return false;
    }
}
```

What it costs: one external `view` call on `bindToken` only, so no gas on the transfer path; one new custom error; no storage, no ABI change to existing functions. Tests: `testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour` must be inverted into a regression test, plus cases for an EOA, an engine that does not serve the token, an engine that does, and a contract without `isTokenBound`.

**Drawbacks**

1. **It conflicts with the gap-free deployment order of F-4.** That order binds the rule to the engine (step 4) *before* binding the token to the engine (step 5), precisely so that every mint reverts until the rule is in place. With this check, step 4 reverts: the engine does not serve the token yet. Swapping the two steps makes the check pass but reopens the window F-4 closes: between `engine.bindToken(token)` and `engine.addRule(rule)`, the engine accepts the token's mints without the cap rule. The deployer would be back to "nobody mints in between" by procedure. **This is the main reason not to implement the check as is.**
2. **It is a snapshot.** It checks the engine once, at binding. It does not prevent the engine from later binding a second token (F-1), nor notice the engine later unbinding `tokenContract` (harmless: the engine then rejects the token's calls, so mints revert anyway).
3. **It trusts the target's answer.** Any contract can return `true` from `isTokenBound`. The check catches mistakes, not a malicious compliance manager, who is trusted anyway.
4. **Engines without `isTokenBound` are refused.** A custom engine that does not implement the ERC-3643 compliance binding functions cannot be bound, even if it would work. Fail-closed, but an interoperability cost.
5. **Test churn.** About 40 `bindToken` calls appear in the `RuleIssuanceCap` suites; most bind a stand-in address (for example `address(0xCA11)` in the unit tests) rather than a real token or engine. Those would need a mock that answers `isTokenBound`, or to bind the token mock itself.
6. **Inconsistency with the sibling rules.** `RuleMintAllowance` and `RuleConditionalTransferLight` bind the same way and would keep accepting any address, unless the same hook is added to them.

#### Option B: detect a wrong binding in the views

Extend `_ruleNotBound()` so that the views also report 85 when the bound caller is neither the token nor an engine serving it. That closes the view/enforcement gap itself instead of preventing it. Drawbacks: an external call on **every** read, and on every write too, since the write path runs the same `_detectTransferRestriction`; it must be `try/catch`-guarded to keep the views non-reverting; and the answer can change without any action on the rule (the engine unbinds the token). Not recommended: it puts a configuration check on the hot path.

#### Option C: also require a single-token engine

Additionally require `getTokenBounds().length == 1` on the engine, which would address F-1 at binding time. Drawbacks: `getTokenBounds` belongs to RuleEngine's extended module, not to the ERC-3643 interface, so other engines would be refused; it is still a snapshot, and RuleEngine can later add a token through `bindToken`, the batch functions or token self-binding. Not recommended.

#### Option A misses the likely mistakes

Option A checks that the target is *related* to the token, not that it is the address that will call the rule:

- **A stale engine passes.** After a migration from engine E1 to E2 (`setRuleEngine(E2)`), E1 still reports `isTokenBound(token) == true` unless `E1.unbindToken(token)` was called. Binding the rule to E1 passes, and every mint reverts because E2 is the caller. This is the "previous engine" case this finding describes.
- **A topology mix-up passes, both ways.** The token branch accepts the token even when the rule sits behind an engine, and the engine branch accepts a serving engine even when the rule is set directly on the token. In both cases the real caller is rejected.
- **The strict fix contradicts both documented setup orders.** Requiring `token.ruleEngine() == address(this)` (or `== target`) would catch all three mistakes, but both documented orders bind *before* installing: `bindToken` then `setRuleEngine` in the direct topology, and the rule bound to the engine before the engine binds the token in the gap-free order (F-4). At binding time the final configuration does not exist yet, so no check can be both strict and compatible with them.

#### Decision: declined

**The maintainers declined F-2; the code is unchanged.** Option A catches typos and EOAs but not the mistakes an operator is likely to make, its strict form rejects the documented setup orders, and options B and C put a check on the hot path or depend on a RuleEngine-only function. The failure is fail-closed and caused by the trusted compliance manager, and the F-4 deployment order already keeps every mint reverting until the setup is correct. `testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour` stays as the record of the accepted behaviour.

### 3.4 F-3 — `_afterMintChecked` does not warn that `transferred` is ungated (Info)

`RuleMaxTotalSupplyBase.transferred` became non-`view` in `v0.7.0` so that a subclass can record mints, and anyone can call it. That is safe for the stock rule, which writes nothing (asserted with `vm.accesses`). The hook's NatSpec names it as the extension point for recording but does not say that a recording subclass must also restrict both `transferred` overloads, as `RuleIssuanceCap` does. The PoC subclass, which only overrides the hook, lets any account record arbitrary mints.

**Impact.** None in shipped contracts; a hazard for library users. **Recommendation.** Add one sentence to the hook's `@dev`: a subclass that writes in this hook must restrict both `transferred` overloads to its bound caller.

### 3.5 F-4 — Mints made while the rule is not attached are not counted (Info)

**Context: what the counter can see.** `RuleIssuanceCap` is not part of the token. It learns about a mint only when the token notifies it, and the token notifies only the rule engine it is currently configured with (`CMTAT.setRuleEngine`). So `totalIssued` counts exactly the mints made while **both** hold:

1. the rule is attached: set on the token directly, or added to the RuleEngine set on the token;
2. the rule is bound to the caller that notifies it (`bindToken`), otherwise the notification reverts.

Any mint outside those periods is never notified to the rule, so it is never counted and never checked against the counter. There are two such periods:

| Window | When it happens | Already documented? |
|---|---|---|
| **Before first attachment** | Between deploying the rule (`initialIssued` is fixed in the constructor) and the `setRuleEngine` / `addRule` call that installs it | **No** |
| **While detached** | After `setRuleEngine(address(0))`, a switch to another engine, or `removeRule`, until the rule is installed again | Yes: the WARNING in `RuleIssuanceCap.md` |

**Example.** Cap 100, `initialIssued = 0`. Before the rule is installed, the issuer mints 100 and burns 100. The rule is then attached with `totalIssued = 0`, and 100 more can be minted. Lifetime issuance is 200 against a cap of 100 (`testIC3_IssuanceBeforeAttachIsNotCounted_CurrentBehaviour`).

**What still holds.** The inherited live-supply check reads `totalSupply()` on every mint, so after re-attachment the **supply** can never exceed the cap; if the unnoticed mints pushed it over, minting stays blocked (`testIC3_LiveLegCatchesDetachedOverMint`). What is lost is only the non-replenishing property for the uncounted period: a mint-and-burn inside the window leaves no trace.

**Why it is Info.** Only accounts allowed to mint on the token can create the gap, and the issuer controls who they are and when the rule is installed. It is an operational precondition, not something an outsider can trigger.

**What "revoke `MINTER_ROLE` first" means.** In CMTAT, `mint` requires `MINTER_ROLE`. The documented detach procedure is: remove the role from every minter, then detach, then re-attach, then grant the role back. With no minter during the window, no uncounted mint can happen. Two points the current wording does not make, and should:

- **The token's default admin can always mint.** CMTAT's `AccessControlModule.hasRole` returns `true` for every role when the account holds `DEFAULT_ADMIN_ROLE`, so revoking `MINTER_ROLE` from the minters does not stop the admin. The admin, who is also the one detaching the rule, must simply not mint during the window.
- **Pausing the token does not help.** CMTAT's pause stops transfers, not mint and burn.

**Recommendation (documentation only).** In `RuleIssuanceCap.md`, extend the warning to the first-attachment window and make the setup order explicit:

1. deploy the rule with `initialIssued` equal to the issuance so far;
2. `bindToken` (the token, or the RuleEngine);
3. install it (`setRuleEngine` on the token, or `addRule` on the engine);
4. only then grant `MINTER_ROLE`, or start minting.

For a token that is already live, apply the same "no minting during the window" rule between deployment and installation, and pass as `initialIssued` the issuance at the moment of installation, not at deployment.

A code fix is not proposed: the rule cannot observe mints it is not told about, and the live-supply check already bounds the supply.

**Status: documented** (see §6). The documentation also gives a stronger order than the one above, for the RuleEngine topology: set the engine in the CMTAT constructor and bind the token to the engine last. A RuleEngine rejects every call from a token it has not bound, so every mint, the admin's included, reverts until the cap rule is installed, and the window disappears instead of being kept empty by procedure. The rule itself cannot be passed to the token's constructor, since it reads the token's supply at construction, so the direct topology keeps the procedural order.

### 3.6 F-5 — Code 85 does not name the unbound rule (Info)

Three rules share `CODE_RULE_NOT_BOUND = 85` and one message. This is the stated design; each rule's `detectTransferRestriction` can be queried. No change recommended; the adversarial pass considered the finding dismissible.

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

Negative results: a holder of `MAX_TOTAL_SUPPLY_ROLE` cannot repoint the observed token; the admin cannot repoint `RuleIssuanceCap`'s token; a trusted forwarder cannot impersonate the bound token, because the check uses the raw `msg.sender`.

**Centralization premise.** The default admin implicitly holds every role, and the cap role can raise the cap at will: non-replenishment holds relative to the cap the issuer sets. This is inherent to the model, not a finding.

---

## 6. Remediation — what was implemented

| Finding | Status | What changed | Verified by |
|---|---|---|---|
| F-1 | ⚠️ Documented, behaviour unchanged | `bindToken` NatSpec (`RuleIssuanceCapBase.sol`) gains a WARNING and an `@param` note that a bound RuleEngine must serve only `tokenContract`; `RuleIssuanceCap.md` § Binding gains a WARNING explaining what a multi-token engine does to the counter | Doc change only; the two `testIC1_*_CurrentBehaviour` PoCs still pass, since the behaviour they pin is unchanged |
| F-3 | ⚠️ Documented, behaviour unchanged | `_afterMintChecked` NatSpec (`RuleMaxTotalSupplyBase.sol`) gains a WARNING: both `transferred` overloads are ungated, and a subclass that writes in the hook must restrict them to its bound caller | Doc change only; `testMTS1_UngatedSubclassIsDrivableByAnyone_CurrentBehaviour` still passes, as the base is unchanged |
| F-4 | ⚠️ Documented, behaviour unchanged | `RuleIssuanceCap.md` gains a "Deployment order" section: the window before first installation, the setup order for each topology, the admin caveat, and the `initialIssued` rule for a live token. It adds a gap-free order not in the original recommendation: set the RuleEngine in the CMTAT constructor and bind the token to the engine **last**, so every mint, the admin's included, reverts until the cap rule is in place | New tests `testDeploymentWithEngineInConstructorLeavesNoUncountedWindow` and `testDeploymentWithEngineInConstructorBlocksGrantedMinter` (real CMTAT `v3.3` + RuleEngine `rc7`); `testIC3_IssuanceBeforeAttachIsNotCounted_CurrentBehaviour` still passes, as the rule is unchanged |
| F-2 | ⛔ Declined | None: a binding check misses the likely mistakes (stale engine, topology mix-up) and, in its strict form, rejects both documented setup orders (§3.3) | `testIC2_BindingUnrelatedCallerIsAccepted_CurrentBehaviour` pins the accepted behaviour |
| F-5 | By design, not changed | — | — |

No runtime code changed. The NatSpec change is recorded in `CLAUDE_ANALYSIS_SUMMARY.md`, as production comments do not cite this report.

What the review added: 16 tests in `test/ThreatModel/ThreatModelV070Tests.t.sol` (13 unit and integration tests, the integration ones on a real CMTAT `v3.3` token and RuleEngine `rc7`; 3 fuzz tests). After adding them and after the documentation changes for F-1, F-3 and F-4 (plus two integration tests for F-4): `forge test` 1310 passed, 0 failed; `FOUNDRY_PROFILE=erc3643 forge test` 53 passed, 0 failed; `forge fmt --check` clean.

---

## 7. Potential Improvements (open backlog)

| # | Improvement | Addresses | Effort | Breaking? | Priority |
|---|---|---|---|---|---|
| — | None open | — | — | — | — |

The documentation items are done (F-1, F-3, F-4; §6). The binding check proposed for F-2 was declined (§3.3): it is recorded there with its implementation, its drawbacks and two alternatives, should the question come back.

---

## 8. Scope & duplicate check

All five findings are in scope (code added in `v0.7.0`). None duplicates a static-analysis result: the `v0.7.0` Slither and Aderyn runs report nothing on these paths except a `dead-code` false positive on `_afterMintChecked`, which is called through virtual dispatch. F-1 is a variant of the "one token per instance" limitation already documented for `RuleMaxTotalSupply` and `RuleChainlinkPoR`, applied to a stateful rule.

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

The `v0.7.0` changes introduce no vulnerability. `RuleIssuanceCap` is correct for its documented deployment (one instance per token, bound to that token or to an engine serving only it), and its counter is closed to every caller but the bound one. No work remains open: F-1, F-3 and F-4 are documented, F-2 was declined, and F-5 is by design.
