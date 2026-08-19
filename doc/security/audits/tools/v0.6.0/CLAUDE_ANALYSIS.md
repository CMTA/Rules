# Rules `v0.6.0` — Code Quality Review

Scope: production contracts under `src/` (mocks excluded from the metrics, included where a finding concerns
them). Compiler solc `0.8.36`, EVM `prague`. Reviewed **2026-08-18** against the `v0.6.0` tree.
Produced with Claude Code.

**Nothing in this report is a vulnerability.** Nothing found here lets an unauthorised party move value, bypass
a restriction, or brick a contract. It is a quality review: convention drift, documentation that outgrew its
code, and one structural inconsistency. Where a check passed, that is recorded too — a "keep this as it is"
verdict is a result, not an absence of one.

This review deliberately concentrates on **code added in `v0.6.0`**, since `v0.5.0`'s review
(`CLAUDE_ANALYSIS.md`, 28 findings) covered the pre-existing surface and its dispositions still hold.

## Disposition summary

| ID | Finding | Outcome |
|---|---|---|
| A-1 | External calls inside a loop in the wrapper's new `_checkRule` | ⬜ Left — bounded, configuration-only, and the point of the guard |
| B-1 | No repeated storage reads in the new code | ✅ Checked, nothing to do |
| C-1 | `RuleIdentityRegistryBase` writes + emits inline in 4 places; every sibling rule uses a `_setX` helper | ⬜ **Decide** — actionable, with a trap; see the entry |
| D-1 | The notification-seam NatSpec was byte-identical in 3 files, 25 lines each | ✅ Fixed — shortened to 13, derivation already in the docs |
| E-1 | Two `internal` functions missing `virtual`, against the project's own convention | ✅ Fixed + regression test |
| F-1 | Interface IDs and ERC-165 advertisement | ✅ Checked, correct |
| G-1 | 7 NatSpec blocks over the project's stated 20-line ceiling, all added this release | ✅ Fixed — max block now 19 |
| G-2 | No documentation-path pointers in production contracts | ✅ Checked, convention holds |
| H-1 | `CapAccounting` members both used; no dead code introduced | ✅ Checked |
| I-1 | The wrapper requires exactly the one function it calls | ✅ Checked, correct by construction |

**7 checked-and-correct · 3 fixed · 1 left · 1 to decide.** (Rows counted, not estimated.)

## Outstanding

| ID | Item | Why it is still open |
|---|---|---|
| C-1 | Extract `_setIdentityRegistry` / `_setCheckSender` / `_setCheckSpender` | Needs a decision: the constructor and the setter have *different* zero-address semantics, so a naive extraction changes behaviour |

---

## A. Loops and iteration

### A-1. `RuleWhitelistWrapperBase._checkRule` makes external calls reachable from a loop — leave

`_checkRule` now performs two `ERC165Checker.supportsInterface` staticcalls plus one `isAllowList()` call. It is
reached from `setRules`, which loops over the submitted array, so Slither reports `calls-loop`.

**Verdict: leave.** The cost is bounded by `maxRules` (default 10, and `setRules` rejects a longer array), it is
paid once at configuration by `RULES_MANAGEMENT_ROLE`, and **no holder pays it on a transfer**. Validating each
candidate requires calling each candidate; hoisting the calls out of the loop would mean not validating them,
which is the finding the guard exists to close. Recorded so it is not re-opened.

`++i` was checked and is already correct throughout; the pragma is `^0.8.20` and the project compiles at 0.8.36,
where the bounded-loop overflow check is elided automatically — `unchecked { ++i }` would buy nothing and is
correctly absent.

## B. Storage reads

### B-1. Nothing to hoist in the new code — checked

`CapAccounting` is `pure` throughout and declares no storage. `_checkRule` reads no storage. The new
`_detectTransferRestrictionOnNotify` overrides delegate immediately. The cap managers' existing single-read
pattern (`uint256 cap = maxBalance;`) is unchanged.

No finding. Recorded because "we looked" is worth more than silence.

## C. Events

### C-1. `RuleIdentityRegistryBase` is the only configurable rule that writes and emits inline — decide

`identityRegistry`, `checkSender` and `checkSpender` are each written in more than one place, and every write
site carries its own `emit`:

| Field | Write sites | Emits |
|---|---|---|
| `identityRegistry` | constructor `:61`, `setIdentityRegistry:103`, `clearIdentityRegistry:132` | 3, all inline |
| `checkSender` | constructor `:64`, `setCheckSender:114` | 2, all inline |
| `checkSpender` | constructor `:65`, `setCheckSpender:124` | 2, all inline |

So "every write emits" is held **by convention rather than structurally**: nothing forces the next person adding
a write path to emit, and nothing forces them to validate.

**The evidence that this is the exception, not the style, is the siblings.** Nine `_setX` helpers already exist
across five contracts, each owning validation + write + event:

```
RuleWhitelistShared._setCheckSpender / _setAllowMintBurn
BalanceCapManager._setMaxBalance / _setBalanceToken
TotalSupplyCapManager._setMaxTotalSupply / _setTokenContract
ChainlinkPoRFeedManager._setReservesFeed / _setTokenMetadata / _setMaxStalenessSeconds
```

`RuleWhitelistShared` already has a `_setCheckSpender(bool)` — the **same field name and type** that
`RuleIdentityRegistryBase` writes inline. That names the helper and settles what the house style is.

**The trap, and why this is a decision rather than a fix.** The constructor and the setter have deliberately
*different* zero-address semantics:

- `setIdentityRegistry(address(0))` **reverts** (`RuleIdentityRegistry_RegistryAddressZeroNotAllowed`).
- The constructor treats `address(0)` as "leave unset, emit nothing" — that is how a rule is deployed with checks
  disabled.
- `clearIdentityRegistry()` writes `address(0)` **and emits**.

A naive `_setIdentityRegistry` that hoists the `require` would make the three-argument constructor revert on the
documented "no registry" deployment, and would break `clearIdentityRegistry`. The extraction is still worth
doing — moving validation into the helper is the *feature*, because it then guards every path — but the helper
has to model three cases, not one. Suggested shape: `_setIdentityRegistry(address, bool allowZero)`, or a
separate `_clearIdentityRegistry()`.

**Verdict: decide.** Real inconsistency with a real payoff, but it changes constructor behaviour if done
carelessly, and `RuleIdentityRegistry` is on the ERC-3643 identity path. Not folded into this release.

## D. Duplication

### D-1. The notification-seam NatSpec was byte-identical across three files — fixed

`_detectTransferRestrictionOnNotify` carried a **25-line** NatSpec block in `RuleChainlinkPoRBase`,
`RuleMaxTotalSupplyBase` and `RuleMaxBalanceBase`. All three hashed identically: 75 lines of documentation, one
copy of the information.

**Fixed.** Shortened to 13 lines each, keeping the two things a reader of the source must have — *this is the
seam an ERC-3643 variant overrides*, and *the read path is deliberately not routed through it* — and dropping
the worked example and the failure narrative, which `RULE_SEMANTICS.md` §5 already carries in full. No
cross-reference was added in either direction, per the project's convention.

The four deployment variants (`…ERC3643`, `…ERC3643Ownable2Step`) are near-identical to their pairs, differing
only in the base they extend. That is the established house pattern for every rule in the library, so it is
**not** reported as duplication.

## E. `virtual` / override convention

### E-1. Two `internal` functions missing `virtual` — fixed

`CLAUDE.md`: *"All `internal` functions should be marked `virtual`."* Two did not comply:

- `RuleAddressSetInternal._requireNotZeroAddress` (`:64`)
- `RuleERC2980Internal._requireNotZeroAddress` (`:142`)

Both are the batch zero-address guard, and both are **passed to `AddressSetBatchLib.addBatch` as an internal
function pointer** — which is also why Slither's `dead-code` detector reports them as unused (it does not trace
function pointers). Two findings about the same two lines.

**Verified before changing, not assumed:**

| Question | Method | Result |
|---|---|---|
| Is `virtual` legal on a function used as a pointer? | compile | yes |
| Does dispatch actually reach an override *through the pointer*? | harness that overrides it and reverts | **yes** — override reached |
| Does it cost gas? | `--gas-report`, same test, toggled in place | **identical**: `addAddress` 92 220, `addAddresses` 140 637 both ways |

The middle row is the one that mattered. Solidity resolves an internal function pointer at the point of
assignment, so it was not obvious the override would be the implementation `addBatch` ends up calling. It is —
but a compile-only check would have passed either way and left the guard *looking* extensible while the base
implementation kept running.

**Fixed**, with `test/VirtualHooks/BatchGuardPointerVirtual.t.sol` pinning both properties. Removing `virtual`
fails the build with *"Trying to override non-virtual function"* — confirmed by mutation, so the guard is not a
test that has never failed.

## F. ERC / specification conformance

### F-1. Interface IDs and advertisement — checked, correct

- `IADDRESS_LIST_INTERFACE_ID` (`0x5d10e182`) is still computed from the flattened helper interface, and is
  **unchanged** despite two selectors being factored into parent interfaces this release — the flattened set did
  not move, which is the property that matters and is asserted in `AddressListInterfaceId.t.sol`.
- The two new ids are single-function interfaces that inherit nothing, so stating them as literals is safe:
  `IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID` = `0x20e8e17a`, `IADDRESS_LIST_POLARITY_INTERFACE_ID` = `0xdc4efe10`.
  Both are asserted equal to `type(I…).interfaceId` and to the function selector.
- Every implementer advertises the new ids — the step most often missed when splitting an interface, and the one
  that would otherwise make the new guard reject contracts that were previously fine.
- `address(0)` sentinel handling is unchanged and still correct: it can never enter an address set, and
  `isVerified(address(0))` is `false`.

## G. Code / documentation mismatch

### G-1. Seven NatSpec blocks over the project's own ceiling — fixed

`CLAUDE.md` states the ceiling plainly: *"Keep NatSpec blocks short — 20 lines is the ceiling."* Measured across
`src/` excluding mocks, **824 blocks**:

| | Before | After |
|---|---|---|
| median | 4 | 4 |
| p90 | 9 | 9 |
| max | **26** | **19** |
| blocks ≥ 20 lines | **7** | **0** |

All seven were added in this release — the four ERC-3643 variant headers (26 lines each) and the three seam
blocks from D-1 (25 each). Against a median of 4, a 26-line contract header is not thorough documentation; it is
a document that happens to live in a comment, and it is the first thing a reader of the contract meets.

**Fixed.** Each keeps its conclusion and its warning — *ERC-3643 only*, *picking the wrong variant breaks the cap
silently and nothing reverts*, *only the write path is re-phased* — and drops the worked tables and derivations,
which `doc/technical/contracts/RuleChainlinkPoRERC3643.md`, `RuleMaxTotalSupplyERC3643.md` and
`RULE_SEMANTICS.md` §5–§6 already carry. Nothing was deleted outright; it was moved to where it already existed.

### G-2. No documentation-path pointers in production contracts — checked, convention holds

`CLAUDE.md` forbids citing a `doc/technical/**` page from contract source, because documentation moves and
deployed verified source cannot be edited to follow it. Grepping `src/` for `.md`, `doc/` and `docs/` outside
`src/mocks/` returns **nothing**, and the only remaining citations are audit reports by bare filename
(`CLAUDE_AUDIT.md`, `CLAUDE_ANALYSIS.md`), which the convention explicitly permits — they are immutable records
and the bare filename survives a move.

Worth stating so a future reviewer does not propose removing those: **the audit-report citations are correct and
must stay.**

## H. Weird behaviour

### H-1. No dead or vestigial code introduced — checked

Both `CapAccounting` members are used (`_capExceededBy` 4 references, `_capHeadroom` 2). The new
`_detectTransferRestrictionOnNotify` is called from both write hooks in each of the three cap rules, and
`RuleChainlinkPoRBase` is at 100% function coverage — which is the empirical refutation of Slither's `dead-code`
report on it, triaged separately in `slither-report-feedback.md`.

No fail-open/fail-closed inconsistency was found in the new code: the cap rules fail closed, the wrapper guard
fails closed (absence of a polarity declaration is a refusal), and the `approveAndTransferIfAllowed`
post-condition fails closed.

## I. Interface granularity

### I-1. The wrapper requires exactly what it calls — checked, correct

`RuleWhitelistWrapperBase` calls one function on its children, `areAddressesListed`, and its ERC-165 guard
requires `IAddressListBatchQuery` — that one selector — rather than the eight-selector `IAddressList`. Requiring
the full id would demand four write functions a read-only child has no reason to expose.

The polarity check is a **separate** interface deliberately, and the limit is stated honestly in both the source
and the docs: ERC-165 expresses shape, never semantics, so the guard cannot distinguish an allow-list from a
deny-list by interface alone — hence `IAddressListPolarity` carrying the answer explicitly, and
`RuleSpenderWhitelist` declining to implement it because its set is spenders rather than holders.

No finding. This check is recorded because the correct outcome here is easy to mistake for an omission.

---

## What was measured, and what was reasoned

Measured: NatSpec block distribution (824 blocks, before and after); gas for E-1 (`--gas-report`, same harness
toggled in place); the E-1 override-dispatch behaviour (executing harness); the mutation check that E-1's test
fails without the fix; storage layouts before and after.

Reasoned without executing: A-1's bound (read from `maxRules` and `setRules`), and C-1's proposed helper shape,
which is a design sketch rather than an implemented change.

## Verification

`forge fmt --check` clean. **882 tests pass** on the default profile (881 + the new E-1 regression) and **53** on
`FOUNDRY_PROFILE=erc3643`. Storage layouts unchanged for every affected contract — E-1 and G-1 touch only a
keyword and comments.
