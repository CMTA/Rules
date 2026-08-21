# Aderyn `v0.6.0` — triage

```bash
aderyn -x mocks --output doc/security/audits/tools/v0.6.0/aderyn-report.md
```

Tool: **Aderyn 0.6.5** · Compiler: solc `0.8.36` · Run date: **2026-08-21** (re-run after the RuleEngine
`v3.0.0-rc6` bump; supersedes the 2026-08-18 run)
Scope: production contracts only, mocks excluded via `-x mocks`. 94 source files, 87 detectors. **4 145 nSLOC.**
**0 High · 9 Low categories, 346 instances.**

**Executive triage: nothing to fix.** Aderyn reports no High or Medium finding. Every Low category is by design,
environmental or cosmetic, and **no new category appeared** in a release that added five production contracts and
two interfaces.

### Scope check

`lib/`, `test/` and `src/mocks/` citations are all **0**. Aderyn reads the Foundry config and scopes to `src/`
by itself, so it needs no equivalent of Slither's `--filter-paths`; `-x mocks` is the only exclusion.

## Summary

| ID | Finding | Instances | Disposition | Why |
|---|---|---|---|---|
| L-1 | Centralization Risk | 80 | **By design** | The regulated-issuer model. Roles gating configuration *are* the product; the trust model is documented in `CLAUDE_AUDIT.md` |
| L-2 | Unspecific Solidity Pragma | 92 | **By design** | `^0.8.20` is deliberate — this is a library consumed by projects that pin their own compiler |
| L-3 | Address State Variable Set Without Checks | 3 | **False positive** | Each setter validates: non-zero, `code.length != 0`, and a probe call that must not revert |
| L-4 | Literal Instead of Constant | 2 | Cosmetic | — |
| L-5 | PUSH0 Opcode | 94 | **Environment** | solc `0.8.36` targeting `prague`. Relevant only to a chain without PUSH0, which this library does not target |
| L-6 | Modifier Invoked Only Once | 1 | **By design** | The template-method access-control hook: one modifier per capability, by construction |
| L-7 | Empty Block | 70 | **By design** | Mostly `_authorize*()` overrides whose entire body is the `onlyRole(...)` / `onlyOwner` modifier — an empty body is the idiom, not an oversight — plus intentional no-op hooks (`RuleSpenderWhitelistBase._transferred`) |
| L-8 | Costly operations inside loop | 3 | **By design** | Bounded batch operations over an operator-supplied array |
| L-9 | Unchecked Return | 1 | **False positive** | A configuration probe: the call is made to learn whether it reverts, so discarding the value is the point |

## Delta from `v0.5.0`

**336 → 346 instances (+10)** on **3 942 → 4 145 nSLOC (+203)**. Categories unchanged at 9 — none added, none
removed.

| ID | v0.5.0 | v0.6.0 | Δ |
|---|---|---|---|
| L-2 Unspecific Solidity Pragma | 87 | 92 | **+5** |
| L-5 PUSH0 Opcode | 89 | 94 | **+5** |
| L-1, L-3, L-4, L-6, L-7, L-8, L-9 | 160 | 160 | — |

**The delta is exactly the new files, once each in the two per-file categories.** This release added seven files
under `src/`, of which two are mock harnesses excluded by `-x mocks`, leaving **five production files**:

- `CapAccounting.sol`
- `RuleChainlinkPoRERC3643.sol` / `RuleChainlinkPoRERC3643Ownable2Step.sol`
- `RuleMaxTotalSupplyERC3643.sol` / `RuleMaxTotalSupplyERC3643Ownable2Step.sol`

5 files × (1 pragma + 1 PUSH0) = +10. Nothing else moved.

That is a stronger result than the raw number suggests, and worth stating explicitly:

- **`L-1 Centralization Risk` did not grow (80 → 80)** even though four new deployable contracts landed. The
  ERC-3643 variants subclass the existing deployables and override one `internal` hook, adding **no new
  privileged external function**. The centralisation surface is unchanged.
- **`L-7 Empty Block` did not grow (70 → 70)**. The new contracts' `_detectTransferRestrictionOnNotify`
  overrides have real bodies, and no new `_authorize*()` hook was introduced.
- **`L-9 Unchecked Return` did not grow**, despite `RuleWhitelistWrapperBase._checkRule` gaining two
  `ERC165Checker.supportsInterface` calls and one `isAllowList()` — all three are consumed by a `require`.

## Re-run within `v0.6.0` (2026-08-18 → 2026-08-21)

**No detector moved.** All 9 categories hold their exact instance counts, so the summary table above is
unchanged. Two commits landed between the runs:

- `c1ebe57` — trimmed NatSpec to the 20-line ceiling and marked two pointer-passed guards `virtual`.
- `f920b07` — RuleEngine `v3.0.0-rc6`: `onlyComplianceManager` renamed to `onlyTokenBindingManager`,
  `_authorizeComplianceBindingChange` renamed to `_authorizeTokenBindingChange`, and the redundant
  `RuleConditionalTransferLightMultiTokenBase` binding-authorization override deleted.

The entire body diff is line numbers plus four renamed `L-7` snippets, which is the expected shape: renaming a
hook cannot change how many empty blocks exist, and the deleted override was **not** an empty block — it had a
body — so `L-7` correctly stays at 70. nSLOC moved **4 146 → 4 145**: −3 for the deleted override, −12 for
`forge fmt` re-flowing two multi-line signatures onto one line, +14 for two added imports and two signatures
that `forge fmt` expanded the other way.

Worth stating for the same reason as the `v0.5.0` delta below:

- **`L-1 Centralization Risk` did not grow (80 → 80).** The rename touched two access-control hooks and one
  modifier; no privileged external function was added, removed or re-gated. That the count is stable is the
  cheap confirmation that a rename really was a rename.
- **`L-6 Modifier Invoked Only Once` did not grow (1 → 1)**, and still points at
  `RuleWhitelistShared.onlyCheckSpenderManager`. `onlyTokenBindingManager` is invoked four times in
  `RuleConditionalTransferLightBase` alone, so it correctly does not appear.

## Notes on the two large categories

`L-2` and `L-5` together are **186 of 346 instances (54%)**, and both are one-per-file:

- **`L-2 Unspecific Solidity Pragma`** — Aderyn wants a pinned pragma. For an application this is good advice;
  for a **library** it is not. Every contract here is `^0.8.20` so consumers can compile against their own
  pinned version. Pinning would force downstream projects onto this repo's exact compiler.
- **`L-5 PUSH0 Opcode`** — flags that bytecode from solc ≥ 0.8.20 contains `PUSH0`, which pre-Shanghai chains
  reject. `foundry.toml` targets `prague`; the deployment targets are all post-Shanghai. If that ever changes,
  this becomes a real finding — it is environmental, not wrong.

Both will grow by one per file on every future release. **Treat a jump that is not a multiple of the new-file
count as the signal**, not the totals themselves.

## What a clean report does and does not mean

Aderyn's detectors matched nothing actionable. As with Slither, that is not evidence of correctness: the seven
findings fixed in this release came from the Nethermind AuditAgent scan and manual review, and **neither static
analyser reached any of them**. They are semantic — accounting phase, callback ordering, interface polarity —
and these tools match syntactic patterns.
