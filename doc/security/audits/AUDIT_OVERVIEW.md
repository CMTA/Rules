# Audit & Security-Analysis Overview

> This is a security **overview** (analyses index + triage). It is **not** the vulnerability-reporting policy
> (that belongs in a root `SECURITY.md`).

**Current package version:** `v0.6.0`
**Scope:** production contracts under `src/` — mocks/tests (`src/mocks`, `test/`) and dependencies (`lib/`) are excluded from static-analysis runs unless a run is explicitly marked *mocks included*.

> ⚠️ This project has **not** undergone a formal third-party security audit. The analyses below are automated
> static analysis plus AI-assisted review, with the project team's triage.

## Analyses

| Date | Type | Tool / Source | Version | Reports |
|---|---|---|---|---|
| 2026-08-18 | AI-assisted review | Claude Code (Anthropic) | v0.6.0 | [**CLAUDE_ANALYSIS.md**](./tools/v0.6.0/CLAUDE_ANALYSIS.md) (code quality, `src/`) |
| 2026-08-21 | Static analysis | Slither 0.11.5 | v0.6.0 | [report](./tools/v0.6.0/slither-report.md) · [feedback](./tools/v0.6.0/slither-report-feedback.md) — re-run after the RuleEngine `v3.0.0-rc6` bump, supersedes 2026-08-18 |
| 2026-08-21 | Static analysis | Aderyn 0.6.5 | v0.6.0 | [report](./tools/v0.6.0/aderyn-report.md) · [feedback](./tools/v0.6.0/aderyn-report-feedback.md) — re-run after the RuleEngine `v3.0.0-rc6` bump, supersedes 2026-08-18 |
| 2026-08-17 | AI automated scan | [Nethermind AuditAgent (AI)](https://auditagent.nethermind.io/) | v0.5.0 | [report (PDF)](./tools/v0.5.0/nethermind_audit_agent_report_v0.5.0.pdf) · [feedback](./tools/v0.5.0/nethermind_audit_agent_report_v0.5.0-feedback.md) |
| 2026-08-12 | AI-assisted review | Claude Code (Anthropic) | v0.5.0 | [**CLAUDE_ANALYSIS.md**](./tools/v0.5.0/CLAUDE_ANALYSIS.md) (code quality, `src/`) · [**CLAUDE_ANALYSIS_SCRIPT.md**](./tools/v0.5.0/CLAUDE_ANALYSIS_SCRIPT.md) (deployment scripts) |
| 2026-07 | AI-assisted review | Claude (Anthropic) + custom security-audit skills | v0.4.0 | [**CLAUDE_AUDIT.md**](./tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md) |
| 2026-08-11 | Static analysis | Slither 0.11.5 | v0.5.0 | [report](./tools/v0.5.0/slither-report.md) · [feedback](./tools/v0.5.0/slither-report-feedback.md) |
| 2026-08-11 | Static analysis | Aderyn 0.6.5 | v0.5.0 | [report](./tools/v0.5.0/aderyn-report.md) · [feedback](./tools/v0.5.0/aderyn-report-feedback.md) |
| 2026-07-14 | Static analysis | Slither 0.11.5 | v0.4.0 | [report](./tools/v0.4.0/slither-report.md) · [feedback](./tools/v0.4.0/slither-report-feedback.md) |
| 2026-07-14 | Static analysis | Aderyn 0.6.5 | v0.4.0 | [report](./tools/v0.4.0/aderyn-report.md) · [feedback](./tools/v0.4.0/aderyn-report-feedback.md) |
| 2026-04-16 | Static analysis | Slither / Aderyn | v0.3.0 | [slither](./tools/v0.3.0/slither-report.md) · [aderyn](./tools/v0.3.0/aderyn-report.md) |
| 2026-03-16 | AI-assisted review | Wake Arena (Ackee) | v0.2.0 | [tools/v0.2.0](./tools/v0.2.0/) |

## Static-analysis results (v0.6.0)

Re-run **2026-08-21** for the `v0.6.0` release, at solc `0.8.36`, with the same tool versions as `v0.5.0` so the
delta is directly comparable. This supersedes the 2026-08-18 run, which was already one commit stale when it
was committed. Scope: production contracts only — mocks excluded, vendored dependencies excluded
via the `lib` filter.

| Tool | High | Medium | Low | Info | Relevant to fix? |
|---|---|---|---|---|---|
| Slither 0.11.5 | 2 | 11 | 18 | 15 | **No** — both High-impact results are the long-standing false positive on a permissioned path; see [feedback](./tools/v0.6.0/slither-report-feedback.md) |
| Aderyn 0.6.5 | 0 | 0 | 9 categories (346 instances) | 0 | **No** — every Low is by design, environmental or cosmetic; see [feedback](./tools/v0.6.0/aderyn-report-feedback.md) |

**Nothing to fix in `v0.6.0`.** Both deltas are small and fully attributed:

- **Slither 44 → 46 (+2).** One `calls-loop` on `RuleWhitelistWrapperBase._checkRule` — the NM-20 polarity guard,
  bounded by `maxRules` and reachable only from a `RULES_MANAGEMENT_ROLE` configuration call, never a transfer.
  One `dead-code` on `RuleChainlinkPoRBase._detectTransferRestrictionOnNotify`, which is a **false positive worth
  reading**: acting on it would delete the seam `RuleChainlinkPoRERC3643` exists to override. It is called twice
  in the same file, the contract is at 100% function coverage, and the byte-identical seam in
  `RuleMaxTotalSupplyBase` is not flagged — the detector is unreliable for `internal virtual` functions reached
  through inheritance.
- **Aderyn 336 → 346 (+10)** on +203 nSLOC, and the +10 is *exactly* the five new production files appearing once
  each in `Unspecific Solidity Pragma` and `PUSH0 Opcode`. No new category.

Two non-results are more informative than the totals. **`Centralization Risk` did not move (80 → 80)** despite
four new deployable contracts: the ERC-3643 variants subclass existing deployables and override one `internal`
hook, adding no privileged external function. **`Empty Block` did not move (70 → 70)** either, so no new
access-control hook was introduced.

**Re-run 2026-08-18 → 2026-08-21, after the RuleEngine `v3.0.0-rc6` bump: no detector moved in either tool.**
Slither holds 46 results across the same nine detectors, Aderyn holds 346 instances across the same nine
categories, and the only body changes are line numbers plus four renamed snippets. Two commits are covered — the
NatSpec trim (`c1ebe57`, which is what made the 2026-08-18 reports stale) and the rc6 bump (`f920b07`), which
renamed `onlyComplianceManager` to `onlyTokenBindingManager`, renamed `_authorizeComplianceBindingChange` to
`_authorizeTokenBindingChange` and deleted one redundant override. Aderyn's nSLOC moved 4 146 → 4 145. Slither's
**contract count rose 221 → 225 without any change in `src/`**: rc6 split the binding registry out of
`ERC3643ComplianceModule` into five new upstream contracts and removed one, all under `lib/` and all filtered out
of the results — flagged here so a future reader does not mistake it for scope creep. Two stable counts carry
information: `dead-code` staying at 3 confirms the deleted override was reachable and therefore redundant rather
than load-bearing, and `Centralization Risk` staying at 80 confirms the rename re-gated nothing.

As in `v0.5.0`: a clean static-analysis report means the tools' pattern sets matched nothing. **None of the seven
findings fixed in this release was reachable by either analyser** — they came from the Nethermind AuditAgent scan
and manual review, and are semantic (accounting phase, callback ordering, interface polarity) where these tools
are syntactic.

Commands used for `v0.6.0` (mocks excluded):

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.6.0/slither-report.md
aderyn -x mocks --output doc/security/audits/tools/v0.6.0/aderyn-report.md
```

## Static-analysis results (v0.5.0)

Scope: production contracts only — mocks excluded (`-x mocks` / `mocks` filter) and vendored dependencies
excluded via the `lib` filter. Run **2026-08-13** at solc `0.8.36`, superseding the earlier `v0.5.0` runs.

| Tool | High | Medium | Low | Info | Relevant to fix? |
|---|---|---|---|---|---|
| Slither 0.11.5 | 2 | 11 | 17 | 14 | **No** — all false-positive, by-design or cosmetic; see [feedback](./tools/v0.5.0/slither-report-feedback.md) |
| Aderyn 0.6.5 | 0 | 0 | 9 categories (336 instances) | 0 | **No** — all Low, by-design / environment / cosmetic; see [feedback](./tools/v0.5.0/aderyn-report-feedback.md) |

**Nothing to fix in `v0.5.0`.** Every delta from v0.4.0 traces to the three contracts added in this release
(`RuleChainlinkPoR`, `RuleReceiverWhitelist`, `IdentityRegistryWhitelist`) and each was verified against the
source before dismissal. The two new Slither categories are `uninitialized-local` (variables assigned inside a
`try` whose `catch` reverts or returns) and `timestamp` (the Proof-of-Reserve staleness comparison, which is the
feature itself).

**Latest re-run (2026-08-13, solc `0.8.36`, after the cap-manager split): Slither 44, Aderyn 336 instances.** The split of `RuleMaxTotalSupplyBase` / `RuleMaxBalanceBase` into `TotalSupplyCapManager` / `BalanceCapManager` moved **no** detector: Slither reports the same 44 results one for one, and Aderyn's only change is one pragma and one PUSH0 instance per new file. Storage layout and ABI were separately verified identical for all four affected deployable contracts. The seven contracts added for
`RuleMaxBalance` and the `ChainlinkPoRFeedManager` split produced exactly **one** new Slither finding — a
`balanceOf` configuration probe whose discarded return value is the point — and **no** new Aderyn category. The
dependency and compiler bumps (solc `0.8.36`, OpenZeppelin `v5.7.0`, RuleEngine `v3.0.0-rc5`, CMTAT
`v3.3.0-rc3`) moved no detector at all. An earlier re-run the same day had lowered both counts (Slither 46 → 43,
Aderyn 333 → 315) while contract count and nSLOC rose. The reduction is earned by the `AddressSetBatchLib` refactor, which replaced duplicated batch
loops with one shared implementation that consumes the `EnumerableSet` return values instead of discarding them;
Aderyn's *Loop Contains `require`/`revert`* category disappeared entirely. One informational disposition was
**corrected** rather than re-confirmed: Slither's `unused-state` on the four `TRANSFERRED_SELECTOR_*` constants
in `RuleNFTAdapter` was previously dismissed as a false positive, but each constant occurs exactly once in the
repository — its own declaration. They are genuinely unreferenced. Impact is nil (`internal constant`, so no
storage and not emitted into bytecode), so the disposition is cosmetic rather than a fix.

Note for readers comparing runs: the Slither command must filter **`lib`**, not `submodules` — this is a Foundry
project, so a generic filter pulls the whole vendored dependency tree into scope and inflates the count roughly
four-fold with OpenZeppelin-internal findings.

The substantive issues fixed in this release — the guarded `totalSupply()` reads (codes 51 / 78), the live
feed-decimals read that prevents a stale-cache over-mint, and the removal of two inert public roles from
`IdentityRegistryWhitelist` — were found by **manual review, not by either tool**. A clean static-analysis report
means the tools' pattern sets matched nothing; it is not evidence of correctness.

## AI automated scan results — Nethermind AuditAgent (v0.5.0)

Scan **2026-08-17** (Scan ID `10`, commit `01632da0…951e204c`, 89 contracts / 9 764 LoC) with
[**Nethermind AuditAgent**](https://auditagent.nethermind.io/).

> ⚠️ **This is an AI-powered automated scan, not a formal human-led audit.** Nethermind's own notice states the
> report "has been generated entirely by AI… does not constitute a full security audit… must be independently
> verified", and that it does not authorise describing the project as "audited by Nethermind". The
> [feedback file](./tools/v0.5.0/nethermind_audit_agent_report_v0.5.0-feedback.md) is that independent
> verification: every finding was opened against the cited `file:line`.

| Tool | High | Medium | Low | Info | Relevant to fix? |
|---|---|---|---|---|---|
| [Nethermind AuditAgent (AI)](https://auditagent.nethermind.io/) | 0 | 13 | 11 | 0 | **7 fixed** (NM-3, 6, 10, 11, 17, 18, 20 — `v0.6.0`), 16 accepted as design, 1 declined; **nothing left open** — see [feedback](./tools/v0.5.0/nethermind_audit_agent_report_v0.5.0-feedback.md) |

**Nothing exploitable, and no contract change required for the CMTAT path.** There are **no false positives** —
all 24 findings describe real code — but 17 restate positions already reached, documented in-source and recorded
in `CLAUDE_AUDIT.md` (F-4, F-5, F-7 and the accepted-risk rows for a reverting oracle/registry), and the 24 items
collapse to roughly **11 distinct claims** (approval/quota scoping is reported six times, cap-rule token binding
twice, spender-less hooks twice, short ABI return data twice). Every described failure is fail-closed
(over-restriction, a blocked transfer) or inert (a rule that cannot screen an identity it is never given); none
of the 13 Medium ratings survives verification at Medium.

**NM-11 — fixed in `v0.6.0` for two of the three cap rules.** The three rules assume the token notifies *before*
moving the value; ERC-3643 / T-REX notifies *after*, so the observation already includes the amount and the stock
rule counts it twice, reverting mints that are fully within the cap. `v0.6.0` adds a stateless `CapAccounting`
primitive and a `_detectTransferRestrictionOnNotify` hook on each cap rule — defaulting to today's CMTAT
behaviour — then ships **`RuleChainlinkPoRERC3643`** and **`RuleMaxTotalSupplyERC3643`** (each with an
`Ownable2Step` variant) as one-line overrides of it. Only the write path is re-phased: ERC-3643 calls
`canTransfer` *before* `_mint` and `created` *after*, both in one transaction, so the read views must keep
projecting the pending amount. 49 tests, including two suites driving the **genuine** vendored T-REX token and
four that pin the stock rules failing on it. **`RuleMaxBalance` is deliberately excluded** — a post-update
variant would revert an agent's `forcedTransfer` and, on T-REX ≤ 4.1 where `recoveryAddress` routes through it,
brick wallet recovery; that is a policy decision, not a hook override. Write-ups:
`doc/technical/contracts/RuleChainlinkPoRERC3643.md`, `RuleMaxTotalSupplyERC3643.md`, `RULE_SEMANTICS.md` §5.

A second ERC-3643 hazard surfaced while testing it and is now pinned: T-REX deploys then initialises, and an
uninitialised `Token` reports `decimals() == 0`, so a PoR rule built before `init` silently caches the wrong
decimals and mis-scales the reserves. Remedy is deployment order, documented on the contract page.

**Fixed in `v0.6.0` — NM-6.** `RuleNFTAdapter`'s ERC-7943 spender-aware overloads called the delegated hook
unconditionally, while the `ITransferContext` entrypoints normalised `sender == from` to the direct hook. The
three interfaces signal a direct transfer differently — ERC-7943 documents its `spender` as "the address
performing the transfer (**owner**/operator)" and `ctx.sender` is the token's `msg.sender`, so on both an owner
arrives as `spender == from`, whereas CMTAT uses `spender == address(0)` and the 3-arg overload. The adapter now
normalises on a shared `_isDelegated` predicate; the 4-arg CMTAT path is deliberately left alone, so the primary
integration path and every existing restriction code are unchanged. The one behavioural correction is
`RuleSpenderWhitelist`, which had been rejecting owner-initiated ERC-721 `transferFrom` with code 66 despite
documenting that direct transfers are always allowed; the deny-lists blocked such a transfer before and after and
only relabelled the code. Pinned by
[`test/TransferContext/OverloadParity.t.sol`](../../../test/TransferContext/OverloadParity.t.sol) — the suite
already existed for this property but tested only two of the three input shapes, which is why the gap survived;
reverting the fix now fails 6 of its 10 tests across 5 rules.

**Four findings carry a specified, unimplemented improvement** — NM-5, NM-17, NM-18 and NM-23/24 —
each with the code, its cost and its limit. The two cheapest and clearest wins: assert in
`approveAndTransferIfAllowed` that the approval it created was consumed (NM-17); and ERC-165-check the wrapper's
children in a `_checkRule` override, the pattern `RuleEngineBase` already uses (NM-18). Two carry hard limits
worth knowing before planning work: **NM-5 cannot be fully fixed at the rule level** — the compliance hooks carry
no token identity, so isolating two tokens behind one engine needs an upstream interface change, and only the
"one instance, two engines" half is reachable — and NM-18's read-time containment hits the same uncatchable-decode
problem as NM-23, so only its configuration-time layer is recommended.

The scan reached a strictly different class of issue than Slither and Aderyn, which found none of these: the
static analysers match syntactic patterns, while every AuditAgent finding is semantic — about which hook is
called, in what order, and with which arguments.

## Static-analysis results (v0.4.0)

Both tools were **re-run on 2026-07-14**, after the security remediation landed. Counts below are from that run.

| Tool | High | Medium | Low | Info | Relevant to fix? |
|---|---|---|---|---|---|
| Slither 0.11.5 | 2 | 6 | 16 | 12 | **No** — all false-positive or by-design ([feedback](./tools/v0.4.0/slither-report-feedback.md)) |
| Aderyn 0.6.5 | 0 | 0 | 9 findings | 0 | **No** — all Low, by-design or false-positive ([feedback](./tools/v0.4.0/aderyn-report-feedback.md)) |

**Result: nothing to fix in `v0.4.0`.** The two High-severity Slither `arbitrary-send-erc20` hits are false positives — `approveAndTransferIfAllowed` (light + multi-token variants) is gated by `onlyTransferApprover`, a recorded approval, an allowance check, and a bound token. All other findings are accepted by design (centralization, unspecific pragma, PUSH0, template-method modifiers/empty blocks, `EnumerableSet` loop cost, spec-aligned naming) or tool limitations (`unused-return`/`unused-state`, per-contract analysis).

Slither's tally is **unchanged** from the pre-remediation run. Aderyn moved 8 → 10 Low, of which one was real and was fixed, leaving 9:

- **L-7 `Loop Contains require/revert` (new, 3 instances)** — batch adds now revert on `address(0)` instead of skipping it. Aderyn recommends "forgive on fail and continue", which is exactly the behaviour this release removed: a silent skip left the emitted `AddAddresses` event naming the sentinel as a set member when it was not. **The recommendation is deliberately rejected; do not act on it.**
- **`Unused Import` (2 instances) — found and FIXED during this run.** A dead `RuleTransferValidation` import in the two `RuleSpenderWhitelist` deployment files (pre-existing, not a regression). It was the only actionable item across both tools; both imports were removed, the build is clean, 511 tests pass, and a re-run confirms the finding is gone.

## AI-assisted review results (v0.4.0)

**0 Critical · 0 High · 0 Medium · 2 Low · 8 Informational** — plus 8 observations verified safe or accepted by design. Full detail, including invariant and access-control verification, in [`CLAUDE_AUDIT.md`](./tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md).

| ID | Severity | Finding | Status |
|---|---|---|---|
| F-1 | **Low** | `RuleIdentityRegistry` over-screens vs ERC-3643: it verified sender, spender and minter, where the spec mandates the **receiver only**. Blocked issuance when the minter was unregistered, and **trapped de-listed holders** (they could neither receive nor send). | ✅ **Fixed** — conformant by default; stricter checks moved behind opt-in flags *(breaking)* |
| F-4 | **Low** | `RuleConditionalTransferLightMultiToken` keys approvals by `msg.sender`, not by `token`, so behind a `RuleEngine` no wiring delivers per-token isolation. | ⚠️ **Documented** — rule declared direct-binding-only; code unchanged (a true fix needs an upstream `RuleEngine` interface change) |
| F-2 | Info | Supply-cap restriction views panic on overflow instead of returning code `50`. | ✅ **Fixed** — overflow-safe views |
| F-3 | Info | `approveAndTransferIfAllowed` was inoperable behind a `RuleEngine` (`bindToken` conflated the ERC-20 target with the authorized caller). | ✅ **Fixed** — `bindRuleEngine` splits the two roles |
| F-5 | Info | The whitelist wrapper does not ERC-165-check its child rules. | ⚙️ **Partially fixed** — `IAddressList` now advertised; the wrapper guard remains open |
| F-7 | Info | `RuleMintAllowance.canTransfer` is hardcoded to "allowed" and disagrees with enforcement. | ⚠️ **By design** — documented as non-authoritative |
| F-8 | Info | Multi-token `detectTransferRestriction` depends on `msg.sender`, so third-party pre-flight always reads "not approved". | ✅ **Fixed** — caller-explicit `…ForToken` views |
| F-9 | Info | `unbindToken` leaves stale approvals / mint quota. | ✅ **Mitigated** — `resetApproval` / `clearMintAllowances` added |
| F-10, F-14 | Info | Multi-token doc contradicted itself on approval scoping; project guide stale. | ✅ **Fixed** (documentation) |

Additionally, **two standards-conformance defects were fixed** that were not in the original finding list: enabling mint/burn by whitelisting `address(0)` made `isVerified(address(0))` (ERC-3643) and `whitelist(address(0))` (a **mandatory** ERC-2980 getter) return `true`. Mint/burn permission is now an explicit `allowMint` / `allowBurn` flag and the zero address can never enter a list *(breaking)*.

## Substantive findings that were fixed (AI / manual review)

From the Wake Arena AI review (v0.2.0) and internal `RuleMintAllowance` review:

| Source | ID | Finding | Resolution |
|---|---|---|---|
| Wake Arena | H-1 | ConditionalTransferLight approvals not scoped by token | **Fixed** — single-token binding enforced in `bindToken`; `RuleConditionalTransferLight_TokenAlreadyBound` added. |
| Wake Arena | M-1 | Incomplete `supportsInterface` breaks ERC-165 discovery | **Fixed** — pre-computed interface IDs + `IERC7551Compliance`; full ERC-3643 `ICompliance` ID (`0x3144991c`) handled. |
| Wake Arena | I-1 | RuleERC2980 docs omit frozen spender on `transferFrom` | **Fixed (doc)** — README / AGENTS / CLAUDE updated. |
| Wake Arena | I-2 | `hasRole` admin implicitly passes all role checks | **Fixed (doc)** — documented intentional design + off-chain monitoring guidance. |
| Internal review | — | `RuleMintAllowance` allowance shared across bindings | **Fixed** — single-target binding enforced (`RuleMintAllowance_TokenAlreadyBound`). |
| Internal review | — | `SanctionListOracle` mock `removeFromSanctionsList` set `true` instead of `false` | **Fixed** — corrected to un-sanction; regression test added (mock/test-only). |

See the per-version report directories under [`tools/`](./tools/) for the full outputs and triage.
