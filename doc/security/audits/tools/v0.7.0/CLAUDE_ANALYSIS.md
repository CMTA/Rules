# Rules `v0.7.0` — Code Quality Review

Scope: production contracts under `src/` (mocks excluded from the metrics, included where a finding concerns
them), plus the tests and agent guides where a finding concerns them. Compiler solc `0.8.36`, EVM `prague`.
Reviewed **2026-10-26** against the `v0.7.0` tree (HEAD `3e970b7` plus the changes recorded here).
Produced with Claude Code.

**Nothing in this report is a vulnerability.** Nothing found here lets an unauthorised party move value, bypass
a restriction, or brick a contract. It is a quality review: one gas inefficiency on the new hot path, convention
drift (a `virtual` gap across the library, test names inside production comments), two stale statements in the
agent guide, and coverage and edge-case gaps in the new tests. Where a check passed, that is recorded too.

Following the `v0.6.0` review, this one concentrates on **code added or changed in `v0.7.0`**:
- `RuleIssuanceCap` and the `RuleMaxTotalSupplyBase` hook it uses;
- `remainingMintable()`, `MAX_TOTAL_SUPPLY_ROLE`, `increase` / `decreaseMaxTotalSupply` and the `(previous, new)` event;
- the RuleEngine `v3.0.0-rc7` migration;
- the new CMTAT v3.0.0 test harness.

The mechanical checks (braces, guards, `virtual`, NatSpec length, references to docs and tests) were run over the
whole of `src/` and `test/`.

## Disposition summary

| ID | Finding | Outcome |
|---|---|---|
| A-1 | No loop added in `v0.7.0` production code | ✅ Checked, nothing to do |
| B-1 | `RuleIssuanceCapBase._afterMintChecked` read `totalIssued` and `maxTotalSupply` twice, once for `require`'s eagerly evaluated error arguments | ✅ Fixed — **−345 gas per mint**, measured |
| B-2 | The issuance read path reads `maxTotalSupply` twice (counter leg, then the inherited live leg) | ⬜ Left — a warm read; caching it would mean re-implementing the inherited leg |
| C-1 | One emit site per event in the new code | ✅ Checked |
| C-2 | `TokenContractUpdated` carries only the new value, unlike its sibling `MaxTotalSupplyUpdated(previous, new)` | ⬜ Left — a second event break for little value |
| D-1 | `MAX_TOTAL_SUPPLY_ROLE` declared in two deployables | ✅ Fixed — `RuleMaxTotalSupplyRolesStorage`, the project's own `RuleAddressSetRolesStorage` pattern |
| D-2 | `RuleIssuanceCap` deployables repeat ~20 lines of standard role / ERC-165 boilerplate | ⬜ Left — chosen design (B′), to avoid diamond inheritance |
| E-1 | 63 `public` / `external` functions in 16 files not `virtual`; siblings disagreed | ✅ Fixed — runtime size of all 58 deployables identical; rule added to `CLAUDE.md` |
| F-1 | `IRule` ids, `IRuleEngine`, and what `RuleIssuanceCap` does *not* advertise | ✅ Checked, correct |
| F-2 | `MaxTotalSupplyUpdated` is a project event, so changing it is not a standard deviation | ✅ Checked |
| G-1 | Production comments named test functions, a test file and a mock file (4 sites, 3 files) | ✅ Fixed — substance kept, rule added to `CLAUDE.md` |
| G-2 | `CLAUDE.md` gave a false reason for `IdentityRegistryWhitelist`'s design ("setters are not `virtual`") | ✅ Fixed — stale since `v0.5.0` |
| G-3 | `CLAUDE.md` said `RuleIdentityRegistry` screens the minter; the code exempts it, per ERC-3643 | ✅ Fixed |
| G-4 | NatSpec length: max 19, median 4, p90 9 — within the 20-line ceiling | ✅ Checked; the guide's p90 figure corrected (8 → 9) |
| G-5 | `CLAUDE_AUDIT.md` / `CLAUDE_ANALYSIS.md` cited from production comments (5 by filename, 2 by bare ID) | ✅ Fixed — the project rule now forbids citing AI-assisted reports from production source; official company audits remain citable |
| H-1 | An unbound `RuleIssuanceCap` answers "allowed" on every view while every mint reverts | ✅ Fixed (decision: option b) — shared code 85 in all three binding rules |
| H-2 | `_afterMintChecked` re-checks a condition the CMTAT write path has already checked | ⬜ Left — it is what makes the counter safe on a re-phased write path |
| H-3 | On `RuleIssuanceCap`, `maxTotalSupply` means cumulative issuance | ⬜ Left — documented; a renamed getter would be a second ABI |
| I-1 | No new cross-contract interface requirement | ✅ Checked |
| J-1 | `RuleIssuanceCap` is itself the reuse probe of `RuleMaxTotalSupplyBase`, and compiles | ✅ Checked |
| K-1 | One uncovered function, three untested boundaries | ✅ Fixed — 4 tests; `src/` now 100 % lines / statements / branches / functions |
| K-2 | Mutation spot-checks on `v0.7.0` code | ✅ 5 of 5 killed |
| L-1 | 5 braceless `if` bodies, all in tests added this release | ✅ Fixed |
| M-1 | `require` vs `if` / `revert` | ✅ Checked — 3 bare `revert`s are not convertible; the one `require` with storage-read arguments fixed under B-1 |

**10 fixed · 9 checked-and-correct · 5 left · 0 to decide.** (24 rows, counted.)

## Outstanding

Nothing. H-1, the only item left for decision, was decided (option b) and implemented; see the entry.

---

## A. Loops and iteration

### A-1. No loop added in `v0.7.0` production code — checked

`RuleIssuanceCapBase`, the `TotalSupplyCapManager` additions and the `RuleMaxTotalSupplyBase` hook contain no loop.
The only loops touched this release are in tests. The pragma is now `^0.8.27` and the project compiles at
0.8.36, so `unchecked { ++i }` would buy nothing anywhere and is correctly absent.

## B. Storage reads

### B-1. `_afterMintChecked` read two slots twice on every mint — fixed, −345 gas

```solidity
require(
    !_issuanceExceededBy(value),                       // reads totalIssued, maxTotalSupply
    RuleIssuanceCap_IssuanceCapExceeded(address(this), totalIssued, maxTotalSupply, value) // reads both again
);
...
uint256 issued = totalIssued + value;                  // and totalIssued a third time
```

`require(cond, Error(args))` evaluates `args` before testing `cond`, so the error arguments were read on the
**success** path of every mint. The fix loads both slots once into locals and feeds them to the condition, the
error and the update.

**Measured**, not estimated: a dedicated harness called the bound rule's `transferred(address(0), …)` after an
identical warm-up, measuring `gasleft()` around the call. Each variant was toggled in place and run through the
same harness, which was then deleted.

| | Gas per mint (rule only, warm) |
|---|---|
| Before | 5 602 |
| After | **5 257 (−345)** |
| `RuleMaxTotalSupply`, for reference | 2 442 |

All reads are warm, so this is the saving from removing four warm `SLOAD`s and the extra comparisons, not
`2 100`-gas cold reads. The difference from `RuleMaxTotalSupply` (~2 800) is the counter's own `SSTORE` plus the
`IssuanceRecorded` event.

### B-2. The issuance read path reads `maxTotalSupply` twice — left

`RuleIssuanceCapBase._detectTransferRestriction` reads `maxTotalSupply` for the counter leg, then calls
`super._detectTransferRestriction`, which reads it again after the external `totalSupply()` call. The second read
is warm. Removing it would mean passing the cap into the inherited leg or re-implementing it, which undoes the
point of inheriting it. **Not measured**; left because the remedy costs more in duplication than a warm read
costs in gas.

## C. Events

### C-1. One emit site per event — checked

`grep -rn 'emit <Event>' src/` gives one site each:
- `MaxTotalSupplyUpdated` in `_setMaxTotalSupply`, called by the constructor and all three setters;
- `TotalIssuedInitialized` in the constructor;
- `IssuanceRecorded` in `_afterMintChecked`.

The "every write emits" invariant is structural, not a convention.

### C-2. `TokenContractUpdated` has no `previous` field — left

`MaxTotalSupplyUpdated` gained `(previous, new)` in this release; its sibling `TokenContractUpdated(address indexed
newTokenContract)` did not.

**Verdict: leave.** Changing it is a second event-signature break in the same release. On `RuleIssuanceCap` the
token is locked, so the event fires once, at construction, where there is no previous value. On
`RuleMaxTotalSupply` repointing the token is a rare admin action, and the previous value is the prior event.

## D. Duplication

### D-1. `MAX_TOTAL_SUPPLY_ROLE` declared twice — fixed

`RuleMaxTotalSupply` and `RuleIssuanceCap` each declared `keccak256("MAX_TOTAL_SUPPLY_ROLE")`. The project already
has the pattern for exactly this: `RuleAddressSetRolesStorage` holds the address-list roles, inherited only by the
layer that checks them, so that a contract reusing the internal layer does not publish roles it never checks.

New `RuleMaxTotalSupplyRolesStorage`:
- inherited by both AccessControl deployables (and by `RuleMaxTotalSupplyERC3643` through `RuleMaxTotalSupply`);
- **not** by the Ownable2Step variants, which gate the same functions on the owner.

The role getter is unchanged on every contract that had it (`rule.MAX_TOTAL_SUPPLY_ROLE()` is asserted by the role
tests of both rules).

### D-2. `RuleIssuanceCap` deployables repeat the standard boilerplate — left

About 20 code lines each: constructor wiring, the ERC-165 merge, and the `_authorize*` / `_onlyComplianceManager`
hooks. This is the B′ decision recorded in `ISSUE_16_ISSUANCE_CAP_DESIGN_OPTIONS.md`. Inheriting the
`RuleMaxTotalSupply` deployables instead would remove it but create a diamond on top of an already deep chain.
Every rule in the library repeats this boilerplate.

## E. `virtual` / override convention

### E-1. 63 `public` / `external` functions were not `virtual` — fixed

`CLAUDE.md` required `virtual` on `internal` functions; `v0.5.0` (`fad06a7`) extended it to public *mutating*
functions. Views, pure functions and the compliance entrypoints were left inconsistent:
- `RuleBlacklistBase.transferred` was `virtual`, `RuleSanctionsListBase.transferred` was not;
- `RuleMaxTotalSupplyBase` had to be opened in this release before `RuleIssuanceCap` could extend it.

That is the consequence: a missing `virtual` is invisible until someone needs to subclass, and then it blocks them.

Scan (production code only):

```bash
python3 - <<'EOF'
import re,glob
for f in sorted(glob.glob('src/**/*.sol',recursive=True)):
    if '/mocks/' in f: continue
    s=open(f).read()
    for m in re.finditer(r'function\s+(\w+)\s*\([^{;]*?[{;]', s, re.S):
        pre=s[:m.start()]
        if pre.rfind('\ninterface ') > max(pre.rfind('\ncontract '), pre.rfind('\nabstract contract '), pre.rfind('\nlibrary ')): continue
        if re.search(r'\b(public|external)\b', m.group(0)) and 'virtual' not in m.group(0): print(f, m.group(1))
EOF
```

It found **63** functions in 16 files, now marked; the scan returns nothing.
- **Bytecode:** `forge build --sizes` lists identical runtime sizes for all 58 `Rule*` / `Identity*` deployables before and after.
- **Tests:** all pass unchanged.
- **Guard:** the rule is now in `CLAUDE.md`, pointing at this scan. **What guards it is the convention and the scan, not a compile-time harness:** only `RuleMaxTotalSupplyBase` is held by a real subclass (`RuleIssuanceCap` overrides its `transferred`, `canReturnTransferRestrictionCode` and `messageForTransferRestriction`). A harness overriding all 63 would be a large file proving a keyword.

## F. ERC / specification conformance

### F-1. Interface ids — checked, correct

- Every rule advertises both `IRule` ids (`0xb1a69752`, rc7, and `0x2497d6cb`, legacy) and `IRuleEngine`. This is pinned per distinct `supportsInterface` by `RuleInterfaceIdCompatibility`, and killing the legacy id is caught (mutant m5, K-2).
- `RuleIssuanceCap` implements `created` / `destroyed` (via `ERC3643ComplianceModule`) but does **not** advertise the full ERC-3643 `ICompliance` id. That is correct: ERC-3643 is not supported in v1, because the inherited live-supply leg double-counts on a post-update notification. Advertising it would invite exactly that integration. **Checked by reading** `supportsInterface` (`AccessControlEnumerable` or `RuleTransferValidation`, neither of which lists the compliance id), not by a dedicated test.

### F-2. `MaxTotalSupplyUpdated` is a project event — checked

The `(previous, new)` change is an ABI break for indexers, recorded as such in the changelog. It does not alter any
standard's declaration: the event belongs to this project, so the "never change a standard event" rule does not
apply.

## G. Code / documentation mismatch

### G-1. Production comments named tests and a mock — fixed

| File | Reference | Now |
|---|---|---|
| `RuleConditionalTransferLightApprovalBase.sol` | "Pinned by `testDocumentedPreimageMatchesTheStorageKey`" | dropped; the comment already states the exact preimage |
| `RuleMaxBalanceBase.sol` | "Pinned by `testMintExactlyToTheCapProvesPreUpdateAccounting`" | dropped; the assumption and its consequence stay |
| `AddressListInterfaceId.sol` (2) | `src/mocks/IAddressListInterfaceIdHelper.sol`, `test/InterfaceId/AddressListInterfaceId.t.sol` | replaced by what the value *is*: the XOR of every selector of `IAddressList` and its parents, and the selector of `areAddressesListed(address[])` |

Tests and mocks are renamed and moved; a verified contract's source cannot be, and a reader on a block explorer
cannot open the test. The scan for `\.t\.sol|\btest[A-Z_]…|test/|src/mocks/` over production `src/` now returns
nothing. `CLAUDE.md` gained the corresponding rule, alongside the existing one for `doc/technical/`.

### G-2. `CLAUDE.md` gave a false reason for `IdentityRegistryWhitelist` — fixed

> "only the internal layer, because `RuleAddressSet`'s public `addAddress`/`removeAddress` are not `virtual` …"

They have been `virtual` since `fad06a7` (v0.5.0, the day after this sentence was written), and the
`keyHasPurpose` reverse index the reason protected was later removed. The design is still right for its own
reason: one write path (`registerIdentity` / `deleteIdentity`, `IDENTITY_REGISTRAR_ROLE`), and no `addAddress` or
`ADDRESS_LIST_*` roles published. The note now says so, and records that the earlier reason no longer applies.

### G-3. `CLAUDE.md` said `RuleIdentityRegistry` screens the minter — fixed

The guide listed it with the deny-lists as screening the mint spender, "so the minter must itself be
identity-verified". The code exempts mints (`from != address(0)` in the `checkSpender` condition), as ERC-3643
requires and as the same guide's conformance section says three paragraphs later. The guide contradicted itself.
The conformance section and the code agree, so the list was the stale part. Also confirmed against a real CMTAT
v3.0.0 token (`RuleIdentityRegistryV300`).

### G-4. NatSpec length — checked

866 blocks in production `src/`: **median 4 lines, 90th percentile 9, longest 19.** Nothing reaches the 20-line
ceiling. The guide quoted a p90 of 8; it now quotes the measured 9.

### G-5. Citations of `CLAUDE_AUDIT.md` / `CLAUDE_ANALYSIS.md` in production comments — left, with one caveat

Five production comments cite an agent-written report, always in the same form: the **bare filename in
backticks, followed by the finding ID**, with no path.

| Site | Cited as | Report it means | What the comment relies on it for |
|---|---|---|---|
| `RuleConditionalTransferLightApprovalBase.sol:165` (`_transferHash`) | `` `CLAUDE_AUDIT.md` F-12 `` | v0.4.0 audit, findings table: "`_transferHash` assembly is injective and memory-safe" | why the hand-rolled hashing preimage is safe |
| `RuleConditionalTransferLightMultiTokenBase.sol:205` (`resetApproval` NatSpec) | `` (see `CLAUDE_AUDIT.md` finding F-4) `` | v0.4.0 audit §3.3: multi-token approvals keyed by `msg.sender` | why approvals can be stranded under a key that is never consumed |
| `RuleWhitelistShared.sol:183` (`checkSpender` event) | `` (`CLAUDE_ANALYSIS.md` C-2) `` | **v0.5.0** review: "`checkSpender`'s initial value is never announced" | why the event is emitted from the internal setter |
| `AddressSetBatchLib.sol:10` (library header) | `` (`CLAUDE_ANALYSIS.md` D-1) `` | **v0.5.0** review: "`RuleERC2980Internal` is `RuleAddressSetInternal`, pasted twice" | why the batch loops were extracted |
| `RuleAddressSetInternal.sol:89` (`_addAddress`) | `` (`CLAUDE_ANALYSIS.md` B-4) `` | **v0.5.0** review: "`contains()` followed by `add()` — double set lookup" | why the set mutation's return value is forwarded |

In each case the comment states its own conclusion and the citation adds the history behind it, so a reader
without the repository loses context but not the warning. That is what the project rule requires.

**Verdict: leave.** The review guidelines would remove references to agent-written reports, but this project's
`CLAUDE.md` explicitly allows them ("immutable historical records … cited by bare filename"), and the project's
rule wins. Recorded so the next review does not remove them.

**Caveat: the bare `CLAUDE_ANALYSIS.md` filename is now ambiguous.** The project's rule assumed one file per
name. There are now three `CLAUDE_ANALYSIS.md` reports (v0.5.0, v0.6.0, v0.7.0), and their IDs restart at `-1`:
- **D-1** means the batch-loop extraction in v0.5.0, the notification-seam NatSpec in v0.6.0, and `MAX_TOTAL_SUPPLY_ROLE` in v0.7.0;
- **C-2** exists in both v0.5.0 and v0.7.0, with different meanings.

All three code citations mean **v0.5.0**, but nothing in the comment says so. `CLAUDE_AUDIT.md` is not affected:
there is one (v0.4.0).

The cheapest disambiguation keeps the bare filename and adds the release: `` `CLAUDE_ANALYSIS.md` (v0.5.0) D-1 ``.
The version survives the file moving, as the bare name does. This is the form `CLAUDE.md` already uses for this
report (`` `CLAUDE_ANALYSIS.md` (v0.7.0) E-1 ``). It means three comment edits and one sentence in `CLAUDE.md`'s
citation rule. **Not applied: it changes a project convention, so it is left for the maintainer.**

**Maintainer decision: forbid them instead.** The project rule was changed: production source may cite **official
audits by an audit company** (bare filename and finding ID), but no longer AI-assisted reports, and no longer
their IDs on their own.
- The five citations above were rewritten so each comment carries its own conclusion. For example, the `_transferHash` comment now states why the preimage is injective (three fixed-width words) instead of pointing to F-12, and the `resetApproval` comment states how approvals get stranded (looked up under the engine's address behind a RuleEngine) instead of pointing to F-4.
- The scan also found two IDs cited **without** the filename: "Invariant I-12" in `BalanceCapManager.sol` and "audit F-5" in `RuleWhitelistInvariantStorage.sol`. These were rewritten too.
- The scan `grep -rnE 'CLAUDE_|audit F-|\bI-[0-9]+\b|\bF-[0-9]+\b|\bINV-[0-9]+' src` (mocks excluded) now returns nothing.
- `CLAUDE.md` / `AGENTS.md` carry the new rule, and their Security Findings Reference no longer says "source comments cite it".
- **The link between code and finding moved to `doc/security/audits/CLAUDE_ANALYSIS_SUMMARY.md`.** For each of the seven sites (S-1 to S-7) it records the code line, the comment before and after, the finding with its release, and the change it applied. It also lists the production-code changes of this review (B-1, D-1, E-1, G-1, H-1, G-5), which no comment cites.
- **Not changed, pending a decision:** five comments cite **Nethermind AuditAgent** findings (`NM-17`, `NM-18`, `NM-20`). AuditAgent is an AI scan run by a company (`AUDIT_OVERVIEW.md` lists it as an "AI automated scan"), so it sits between the two categories.

## H. Weird behaviour

### H-1. An unbound `RuleIssuanceCap` says "allowed" while every mint reverts — decide

Until `bindToken` is called:
- `detectTransferRestriction(address(0), to, v)` and `remainingMintable()` answer as if the mint will succeed;
- the write path reverts with `TokenBinding_UnauthorizedCaller`, because the caller is not bound.

A wallet that pre-flights a mint gets "OK", and the mint fails.

Options:
- **(a)** Leave it. It is documented ("until `bindToken` is called, every mint reverts"), it is a deployment-time misconfiguration that the first mint exposes, and `RuleMintAllowance` and `RuleConditionalTransferLight` have the same shape.
- **(b)** Return a new restriction code from the read path when `getTokenBound() == address(0)`.

(b) is cheap but adds a code to a rule that has three, and it should then be applied to the other two rules for
consistency.

**Decision: (b), implemented for all three rules.**
- **Code:** `CODE_RULE_NOT_BOUND = 85`, declared once in the new `RuleBindingInvariantStorage` and inherited by the three rules' invariant storage. One code with one message, as `IRule` requires of a code shared across rules. `HelperContract` inherits two of the three storages without a clash, because the declaration has a single source.
- **Scope:** every operation, not only mints. Each rule's `transferred` rejects an unbound caller for transfers and burns too, so every view reports 85 while unbound, the `can*` views return `false`, and `RuleIssuanceCap.remainingMintable()` returns `(85, 0)`.
- **What counts as bound:** a token for `RuleMintAllowance` / `RuleIssuanceCap`; a token **or** a RuleEngine for `RuleConditionalTransferLight`, since either may call it. Only the fully unbound state is visible. A view cannot know which caller will notify, so "bound to a token, but used behind an engine that was never bound" still looks fine. This is documented on the contract page.
- **Tests:** `test/Binding/UnboundRuleViews.t.sol`: unbound, then bound, then unbound again, per rule. Forcing each rule's `_ruleNotBound()` to `false` (the old behaviour) fails the test for that rule. Two existing `RuleIssuanceCap` unit tests built a fresh, unbound rule to check something else and now bind it first. No existing `RuleConditionalTransferLight` or `RuleMintAllowance` test queried a view while unbound, so the old behaviour had never been pinned.

### H-2. `_afterMintChecked` repeats a check the CMTAT path already made — leave

On CMTAT the write path calls `_detectTransferRestriction(from, to, value)` (which includes the counter leg) before
the hook. The hook's own `require` can therefore never fail there. **Keep it:** on a write path re-phased to
`value = 0` (the ERC-3643 shape) the earlier check runs without the amount, and this `require` is the only thing
enforcing the counter. A unit test with a re-phasing harness pins that. Its cost is inside the measured 5 257.

### H-3. `maxTotalSupply` means cumulative issuance on `RuleIssuanceCap` — leave

The inherited getter keeps its name. The contract page, the NatSpec and the methods table say what it means
there. An `issuanceCap()` alias was considered in the design analysis and not adopted: a second getter for the
same slot is more surface, not more clarity.

## I. Interface granularity

### I-1. Nothing new to check

`RuleIssuanceCap` requires nothing of another contract beyond the token's `totalSupply()`, inherited from
`TokenSupplyReader`. The only interface guards in the library (`RuleWhitelistWrapper._checkRule`) are unchanged
since `v0.6.0`'s I-1.

## J. Modularity

### J-1. `RuleIssuanceCap` is the reuse probe — checked

The question J asks, *can a downstream contract extend this one?*, was answered this release by building one:
`RuleIssuanceCapBase` extends `RuleMaxTotalSupplyBase` and compiles. It needed the base opened (`virtual`, non-`view`
`transferred`, the hook), which is what E-1 then generalised.
- **Directory placement:** `RuleIssuanceCapBase` sits under `operation/` while extending a `validation/` base. That is correct by the directory's definition (it writes state) and reads naturally.
- **Linearization:** no 5005 or override blockers were met; the override lists that `ERC3643ComplianceModule` and `RuleTransferValidation` require compile as written.

## K. Tests

### K-1. Coverage and boundaries — fixed

`forge coverage --report summary --no-match-coverage '(test|mocks?|script)/'`, after the fixes:

| Scope | Lines | Statements | Branches | Funcs |
|---|---|---|---|---|
| All of `src/` (mocks excluded) | 100 % (1 518 / 1 518) | 100 % (1 480 / 1 480) | 100 % (341 / 341) | 100 % (499 / 499) |
| `RuleIssuanceCapBase` | 100 % (44/44) | 100 % (41/41) | 100 % (11/11) | 100 % (13/13) |
| `TotalSupplyCapManager` | 100 % (42/42) | 100 % (30/30) | 100 % (12/12) | 100 % (12/12) |
| `RuleMaxTotalSupplyBase` | 100 % (43/43) | 100 % (39/39) | 100 % (13/13) | 100 % (12/12) |

Before the fix, `RuleIssuanceCapOwnable2Step` was at 75 % of functions. Its `_authorizeTokenBindingChange` is
reached only through `unbindToken`, which no Ownable2Step test called; that was the one uncovered function in all
of `src/`.

| Family (K.3) | Missing case | Test written |
|---|---|---|
| Authorization | `unbindToken` on the Ownable2Step variant (owner and non-owner) | `testOnlyTheOwnerUnbinds` |
| Boundaries | `initialIssued == totalSupply()` exactly (only reached implicitly, through `0 == 0` setups) | `testConstructorAcceptsInitialIssuedEqualToSupply` |
| Zero and identity | `bindToken(address(0))` on `RuleIssuanceCap` | `testCannotBindTheZeroAddress` |
| Zero and identity | `increase` / `decreaseMaxTotalSupply(0)` | `testZeroIncreaseAndDecreaseAreNoOps` |

Properties fuzzed: `remainingMintable()` against the pre-flight check. Invariant-tested: the cap, the counter,
`remainingMintable()` and the pre-flight view, on a real CMTAT token (`SupplyCapInvariantsBase`,
`IssuanceCapInvariants`). Spot-checked only: role gating, event payloads.

### K-2. Mutation spot-checks — 5 of 5 killed

Each mutation was applied to the source, the non-invariant suite run, and the file restored from a backup:

| Mutant | Change | Result |
|---|---|---|
| m1 | drop `onlyBoundToken` from `RuleIssuanceCapBase.transferred` (3-argument) | killed (1 test) |
| m2 | constructor `initialIssued_ >= supply` → `>` | killed (14 tests) |
| m3 | `decreaseMaxTotalSupply`: `amount <= current` → `<` | killed (1 test) |
| m4 | `_remainingMintable`: take the larger room instead of the smaller | killed (2 tests) |
| m5 | drop `IRULE_LEGACY_INTERFACE_ID` from `RuleTransferValidation.supportsInterface` | killed (2 tests) |

m1 and m3 are killed by a single test each. That is enough to fail CI, but thin. Both are direct negative tests of
the guard, which is the right kind. The invariant suites add five further mutation controls on the cap and counter
(`INVARIANT_TESTS.md` §4), all caught.

## L. Control-flow bodies in braces

### L-1. Five braceless `if` bodies in tests added this release — fixed

`test/invariant/MaxTotalSupplyHandler.sol` (3), `test/CMTATv3.0.0/RuleIssuanceCapV300.t.sol` (1),
`test/CMTATv3.0.0/RuleMaxTotalSupplyV300.t.sol` (1). The scan over `src/` and `test/` now returns nothing.

## M. Guards

### M-1. `require` vs `if` / `revert` — checked

Three bare `revert`s remain in production code, and none is a conditional guard that `require` could express:
- `RuleIssuanceCapBase._authorizeTokenContractManager`: unconditional, since the hook exists to refuse;
- `ChainlinkPoRFeedManager._setReservesFeed` and `BalanceCapManager._setBalanceToken`: inside a `catch` block.

The only `require` in this release's code whose error arguments needed storage reads was `_afterMintChecked`. It now
uses locals (B-1), so `require` is correct there. Every other new guard's arguments are parameters, locals or
constants.

## What was measured, and what was reasoned

- **Measured:**
  - the gas of B-1 (dedicated harness, deleted);
  - runtime sizes before and after E-1;
  - coverage (K-1);
  - the five mutants (K-2);
  - NatSpec lengths (G-4).
- **Reasoned, not measured:**
  - B-2's warm read;
  - F-1's statement that `RuleIssuanceCap` does not advertise the ERC-3643 compliance id (from reading `supportsInterface`).

## Verification

After all changes:
- `forge test`: **1 289 passed**, and `FOUNDRY_PROFILE=erc3643 forge test`: **53 passed**;
- `forge fmt --check` clean, `forge lint src` reports no error or warning;
- the brace, `virtual` and reference scans return nothing.
