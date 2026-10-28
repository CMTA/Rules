# Aderyn `v0.7.0` — triage

```bash
aderyn -x mocks --output doc/security/audits/tools/v0.7.0/aderyn-report.md
```

Tool: **Aderyn 0.6.5** · Compiler: solc `0.8.38`, EVM `osaka` · Run date: **2026-10-28** (pre-release re-run, see [Pre-release re-run](#pre-release-re-run-2026-10-28); the two 2026-10-26 runs are described under [First run: nine unused imports, fixed](#first-run-nine-unused-imports-fixed)) Scope: production contracts only, mocks excluded via `-x mocks`. 98 source files. **4 354 nSLOC.** **0 High · 10 Low categories, 377 instances.**

**Executive triage: nothing to fix.** Aderyn reports no High or Medium finding. Every Low category is by design, environmental, cosmetic or a verified false positive. The one real defect it found this release, nine unused imports, was fixed before the committed run.

## Pre-release re-run (2026-10-28)

Re-run before tagging, after the code-quality changes made since the first runs (37 files under `src/`) and the compiler and EVM bump (solc `0.8.36` → `0.8.38`, `prague` → `osaka`).

**377 → 381 instances (+4)** on **4 354 → 4 501 nSLOC**, 98 → 100 files. The four new instances are one `Unspecific Solidity Pragma` and one `PUSH0 Opcode` in each of the two files added by those changes, `RuleBindingInvariantStorage` and `RuleMaxTotalSupplyRolesStorage`. Every other category is unchanged, and nothing new needs fixing. The delta table below compares the first run with `v0.6.0`.

### Scope check

`lib/`, `test/` and `src/mocks/` citations are all **0**. Aderyn reads the Foundry config and scopes to `src/` by itself; `-x mocks` is the only exclusion. The new test-only `lib/CMTATv3.0.0` submodule is not in scope.

## Summary

| ID | Finding | Instances | Disposition | Why |
|---|---|---|---|---|
| L-1 | Centralization Risk | 89 | **By design** | The regulated-issuer model. Roles gating configuration *are* the product; the trust model is documented in `CLAUDE_AUDIT.md` |
| L-2 | Unspecific Solidity Pragma | 98 | **By design** | `^0.8.27` is deliberate — a library consumed by projects that pin their own compiler. Raised from `^0.8.20` this release: `require(cond, CustomError())` needs 0.8.27, and RuleEngine rc7 declares the same floor |
| L-3 | Address State Variable Set Without Checks | 3 | **False positive** | Each setter validates: non-zero, `code.length != 0`, and a probe call that must not revert |
| L-4 | Literal Instead of Constant | 2 | Cosmetic | Unchanged (`ChainlinkPoRFeedManager`) |
| L-5 | PUSH0 Opcode | 100 | **Environment** | solc `0.8.38` targeting `osaka`. Relevant only to a chain without PUSH0, which this library does not target |
| L-6 | Modifier Invoked Only Once | 2 | **By design** | One modifier per capability. New: `TotalSupplyCapManager.onlyTokenContractManager`, used by `setTokenContract` only, because repointing the token is deliberately a separate permission from changing the cap |
| L-7 | Empty Block | 81 | **By design** | `_authorize*()` overrides whose whole body is `onlyRole(...)` / `onlyOwner`, plus intentional no-op hooks |
| L-8 | Costly operations inside loop | 3 | **By design** | Bounded batch operations over an operator-supplied array |
| L-9 | State Change Without Event | 2 | **False positive** | See below |
| L-10 | Unchecked Return | 1 | **False positive** | A configuration probe: the call is made to learn whether it reverts, so discarding the value is the point |

### L-9 State Change Without Event — `RuleMaxTotalSupplyBase.transferred` (×2, new)

**False positive.** Aderyn infers "state change" from the function no longer being `view`; it does not look at what the body does. Both overloads were made non-`view` this release only so that `RuleIssuanceCap` can record mints through the `_afterMintChecked` hook, which is empty in `RuleMaxTotalSupplyBase`. The stock rule writes no storage, and that is no longer an inference but a test: `testTransferredNeverWritesStorage` calls both overloads for a mint, a transfer and a burn under `vm.record()` and asserts that `vm.accesses(rule)` reports **zero writes**. In `RuleIssuanceCap`, where the hook does write, every recorded mint emits `IssuanceRecorded`, so the detector's concern does not apply there either.

## First run: nine unused imports, fixed

The first run of the day reported an extra category, **Unused Import (9)**, one per validation base: `RuleBlacklistBase`, `RuleChainlinkPoRBase`, `RuleERC2980Base`, `RuleIdentityRegistryBase`, `RuleMaxBalanceBase`, `RuleMaxTotalSupplyBase`, `RuleReceiverWhitelistBase`, `RuleSanctionsListBase`, `RuleSpenderWhitelistBase`.

**Real, and introduced by this release.** The RuleEngine `v3.0.0-rc7` migration turned `override(IRuleEngine)` into a plain `override` on each 4-argument `transferred`, which left `IRuleEngine` referenced only by an `@inheritdoc IRuleEngine` NatSpec tag. Aderyn does not count NatSpec as a use. `forge lint` does, which is why it did not catch it.

**Fix:**
- The `IRuleEngine` import was removed from all nine files.
- The tag now names a contract the file already uses: `@inheritdoc RuleTransferValidation` in the three files that inherit it, and `@inheritdoc IRule` in the three that already import `IRule`.
- The remaining three files, whose only base is `RuleNFTAdapter`, got a one-line `@notice`. `@inheritdoc` must name the contract that declares the function, and importing `RuleTransferValidation` only for a doc tag would recreate the same finding.
- `RuleTransferValidation`'s own NatSpec on that function was rewritten to read well when inherited (behaviour plus `@param`s, with the rc7 note moved to a plain comment).

No code or ABI change; 1 285 tests pass. The second run reports the category gone and nothing else moved.

## Delta from `v0.6.0`

**346 → 377 instances (+31)** on **4 145 → 4 354 nSLOC (+209)**. Categories **9 → 10**: one added, `State Change Without Event`; none removed.

| ID | v0.6.0 | v0.7.0 | Δ | Source of the change |
|---|---|---|---|---|
| L-1 Centralization Risk | 80 | 89 | **+9** | `RuleIssuanceCap` (+3) and `RuleIssuanceCapOwnable2Step` (+4): cap and binding functions; `RuleMaxTotalSupply` and its Ownable2Step variant (+1 each): the new `_authorizeTokenContractManager` hook |
| L-2 Unspecific Solidity Pragma | 92 | 96 | **+4** | the four new files: `RuleIssuanceCap`, `RuleIssuanceCapOwnable2Step`, `RuleIssuanceCapBase`, `RuleIssuanceCapInvariantStorage` |
| L-5 PUSH0 Opcode | 94 | 98 | **+4** | the same four files |
| L-6 Modifier Invoked Only Once | 1 | 2 | **+1** | `onlyTokenContractManager` |
| L-7 Empty Block | 70 | 81 | **+11** | the new deployables' `_authorize*` / `_onlyComplianceManager` hooks (+6), `RuleIssuanceCapBase.created` / `destroyed` no-ops (+2), the empty `_afterMintChecked` hook (+1), `_authorizeTokenContractManager` in the two `RuleMaxTotalSupply` deployables (+2) |
| L-9 State Change Without Event | — | 2 | **+2** | `RuleMaxTotalSupplyBase.transferred` no longer `view` |
| L-3, L-4, L-8, Unchecked Return | 8 | 8 | — | |

Every instance was matched file by file against the `v0.6.0` report. No pre-existing file gained or lost an instance except the two `RuleMaxTotalSupply` deployables and `TotalSupplyCapManager` / `RuleMaxTotalSupplyBase`, all of which changed in this release.

Two points worth stating:

- **`RuleIssuanceCapBase` adds no instance to L-1.** All its privileged entry points (`set` / `increase` / `decreaseMaxTotalSupply`, `setTokenContract`) are inherited from `TotalSupplyCapManager`. The new rule's centralisation surface is only `bindToken` / `unbindToken`, counted in the deployables.
- **`L-3` did not grow.** `RuleIssuanceCap` adds no address setter: the observed token is locked after construction.

## Notes on the two large categories

`L-2` and `L-5` together are **194 of 377 instances (51%)**, and both are one-per-file. As in previous releases: treat a jump that is not a multiple of the new-file count as the signal, not the totals. This release added four production files and both categories grew by exactly four.

## What a clean report does and does not mean

Aderyn's detectors matched one real defect (the imports, cosmetic) and nothing that affects behaviour. That is not evidence of correctness. The properties that matter for `RuleIssuanceCap` are semantic and are covered by tests, not by pattern matching:
- burns never restore room;
- the counter cannot be skipped on an ERC-3643-style re-phased write path;
- the live-supply backstop catches uncounted mints.

They are covered by the unit, CMTAT v3.0.0 and invariant suites, and two injected bugs prove the invariants can fail.
