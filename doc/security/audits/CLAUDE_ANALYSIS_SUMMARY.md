# AI-assisted review findings in production code — summary

This file is the **link between production code and the AI-assisted review reports** (`CLAUDE_AUDIT.md`, `CLAUDE_ANALYSIS*.md`). Production source no longer cites those reports or their finding IDs (see the rule in `CLAUDE.md`). Each comment carries its own conclusion, and the history behind it is recorded **here**.

Why not in the code: those reports are rewritten each release and their IDs restart at `-1`: `CLAUDE_ANALYSIS.md` D-1 names three different findings in v0.5.0, v0.6.0 and v0.7.0. A citation baked into deployed, verified source cannot be corrected and cannot even say which report it meant. This file can be corrected at any time.

## How to use this file

- **When an AI-assisted finding changes production code** (or explains why it must not change), add an entry here instead of citing the finding in a comment. The comment states the conclusion; the entry records where it came from.
- **One entry per code location.** Columns:
  - **Location**: `file:line` at the time of writing, plus the symbol, which survives line drift.
  - **Code**: the line the comment documents.
  - **Comment**: what the source says now, and what it said before if a citation was removed.
  - **Finding**: report, release, ID and title. Always give the release: IDs repeat across releases.
  - **Change applied**: what the finding changed in the code, or "none" with the reason.
- **Keep it current.** Line numbers drift; when a symbol moves, update the line. When a finding is superseded, say so in the entry rather than deleting it.
- **Official audits by an audit company** are not listed here: production source may cite them directly, by bare filename and finding ID.

## Relocated citations (removed from production comments in v0.7.0)

### S-1. `_transferHash` — injectivity of the hand-rolled preimage

| | |
|---|---|
| Location | `src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol:162`, `_transferHash` |
| Code | `function _transferHash(address from, address to, uint256 value) internal pure virtual returns (bytes32 hash) {` |
| Comment before | `// … Injectivity is verified in `CLAUDE_AUDIT.md` F-12; the exact layout is documented above.` |
| Comment now | `// … Injective because all three words are fixed-width, so distinct (from, to, value) tuples cannot share a preimage; the exact layout is documented above.` |
| Finding | `CLAUDE_AUDIT.md` (v0.4.0) **F-12**, "`_transferHash` assembly is injective and memory-safe": **not a finding**, verified safe |
| Change applied | None. The audit confirmed the assembly; it is pinned by the fuzz test `testFuzz_HASH1_ApprovalBucketsAreDistinct` (invariant INV-6) |

### S-2. `resetApproval` (multi-token) — why approvals can be stranded

| | |
|---|---|
| Location | `src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol:213`, `resetApproval` |
| Code | `function resetApproval(address token, address from, address to, uint256 value)` |
| Comment before | `… It is also the only way to clear approvals stranded under a key that can never be consumed (see `CLAUDE_AUDIT.md` finding F-4).` |
| Comment now | `… that can never be consumed: behind a RuleEngine, approvals recorded for a token are looked up under the engine's address, never under the token's.` |
| Finding | `CLAUDE_AUDIT.md` (v0.4.0) **F-4** (Low), "Multi-token approvals are keyed by `msg.sender`, not by `token`" |
| Change applied | Documented, not changed in code: the rule is **direct-binding only** (never behind a RuleEngine), and `resetApproval` deliberately does not require the token to be bound, so stranded approvals can still be cleared |

### S-3. `_setCheckSpender` — event emitted from the internal setter

| | |
|---|---|
| Location | `src/rules/validation/abstract/core/RuleWhitelistShared.sol:186`, `_setCheckSpender` |
| Code | `function _setCheckSpender(bool value) internal virtual {` |
| Comment before | `… could reconstruct `allowMint` and `allowBurn` from genesis but had to special-case `checkSpender` (`CLAUDE_ANALYSIS.md` C-2).` |
| Comment now | `… could reconstruct `allowMint` and `allowBurn` from genesis but had to special-case `checkSpender`.` |
| Finding | `CLAUDE_ANALYSIS.md` (**v0.5.0**) **C-2**, "`checkSpender`'s initial value is never announced". Not the v0.7.0 C-2, which is unrelated |
| Change applied | The event moved into the internal setter, which the constructors call, so the initial value is announced at deployment like `allowMint` / `allowBurn` |

### S-4. `AddressSetBatchLib` — why the batch loops are shared

| | |
|---|---|
| Location | `src/rules/validation/abstract/RuleAddressSet/AddressSetBatchLib.sol:22`, library header |
| Code | `library AddressSetBatchLib {` |
| Comment before | `… only the {RuleAddressSetInternal} copy was covered by a zero-address test (`CLAUDE_ANALYSIS.md` D-1).` |
| Comment now | `… only the {RuleAddressSetInternal} copy was covered by a zero-address test.` |
| Finding | `CLAUDE_ANALYSIS.md` (**v0.5.0**) **D-1**, "`RuleERC2980Internal` is `RuleAddressSetInternal`, pasted twice — ~190 lines". Not the v0.6.0 or v0.7.0 D-1 |
| Change applied | The duplicated batch add/remove loops were extracted into this library. The zero-address guard is passed as a function pointer, so each rule keeps its own error |

### S-5. `_addAddress` — forwarding the set's "changed" result

| | |
|---|---|
| Location | `src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol:93`, `_addAddress` |
| Code | `function _addAddress(address targetAddress) internal virtual returns (bool) {` |
| Comment before | `… the same one `add` already does internally (`CLAUDE_ANALYSIS.md` B-4).` |
| Comment now | `… the same one `add` already does internally.` |
| Finding | `CLAUDE_ANALYSIS.md` (**v0.5.0**) **B-4**, "`contains()` followed by `add()`/`remove()` — double set lookup, 8 sites" |
| Change applied | The helpers return `EnumerableSet`'s boolean, and callers use it instead of a preceding `contains()`, removing one lookup at 8 sites |

### S-6. `_addExemptAddress` — the zero address never enters the exemption list

| | |
|---|---|
| Location | `src/rules/validation/abstract/core/BalanceCapManager.sol:147`, `_addExemptAddress` |
| Code | `function _addExemptAddress(address targetAddress) internal virtual {` |
| Comment before | `… by the function pointer `_addAddresses` passes to `AddressSetBatchLib`. Invariant I-12.` |
| Comment now | `… by the function pointer `_addAddresses` passes to `AddressSetBatchLib`. Either way the zero address can never enter the exemption list.` |
| Finding | Invariant **I-12**, defined in `CLAUDE.md` (Standards conformance): the zero address can never enter any list, on single and batch adds alike. Its wording was corrected by `CLAUDE_ANALYSIS.md` (v0.5.0) after it had described batch adds as skipping the zero address |
| Change applied | None here: the invariant was already enforced; the comment named it by ID only |

### S-7. `RuleWhitelistWrapper_ChildIsNotAnAddressList` — the ERC-165 guard on children

| | |
|---|---|
| Location | `src/rules/validation/abstract/RuleAddressSet/invariantStorage/RuleWhitelistInvariantStorage.sol:81` |
| Code | `error RuleWhitelistWrapper_ChildIsNotAnAddressList(address rule);` |
| Comment before | `… bricking every check whose targets were not already resolved. Nethermind AuditAgent NM-18, audit F-5.` |
| Comment now | `… bricking every check whose targets were not already resolved. Nethermind AuditAgent NM-18.` |
| Finding | `CLAUDE_AUDIT.md` (v0.4.0) **F-5** (Info), "Wrapper does not ERC-165-check its child rules": partially fixed then (prerequisite shipped), completed with Nethermind AuditAgent NM-18 in v0.6.0 |
| Change applied | `RuleWhitelistWrapper._checkRule` rejects a child that does not advertise the batch-query interface, with this error |

The **Nethermind AuditAgent** citations (`NM-17`, `NM-18`, `NM-20`) remain in five production comments pending a decision: AuditAgent is an AI scan run by a company, between the two categories the rule distinguishes.

## v0.7.0 review — code changed by `CLAUDE_ANALYSIS.md` (v0.7.0)

No production comment cites these; this is their only link to the code.

| Location | Code | Finding | Change applied |
|---|---|---|---|
| `src/rules/operation/abstract/RuleIssuanceCapBase.sol`, `_afterMintChecked` | `uint256 issued = totalIssued;` / `uint256 cap = maxTotalSupply;` | **B-1**, two slots re-read for `require`'s eagerly evaluated error arguments | Read once into locals: −345 gas per mint, measured |
| `src/rules/validation/abstract/invariant/RuleMaxTotalSupplyRolesStorage.sol` | `bytes32 public constant MAX_TOTAL_SUPPLY_ROLE = keccak256("MAX_TOTAL_SUPPLY_ROLE");` | **D-1**, the role declared in two deployables | Declared once, inherited by `RuleMaxTotalSupply` and `RuleIssuanceCap` only |
| 16 files under `src/rules/` | `public` / `external` function headers | **E-1**, 63 functions not `virtual` | All marked `virtual`; runtime sizes unchanged |
| `RuleConditionalTransferLightApprovalBase.sol`, `RuleMaxBalanceBase.sol`, `AddressListInterfaceId.sol` | NatSpec | **G-1**, comments named test functions, a test file and a mock file | References removed; each comment states what the test proved |
| `src/rules/operation/abstract/RuleBindingInvariantStorage.sol`; `_ruleNotBound()` in `RuleConditionalTransferLightBase`, `RuleMintAllowanceBase`, `RuleIssuanceCapBase` | `uint8 public constant CODE_RULE_NOT_BOUND = 85;` | **H-1**, unbound rules answered "allowed" while every operation reverted | Every view reports code 85 while no caller is bound |
| the seven comments of S-1 to S-7 | NatSpec | **G-5**, AI-assisted reports cited from production source | Citations moved into this file |

## v0.7.0 security audit — code changed by `CLAUDE_AUDIT.md` (v0.7.0)

Not the v0.4.0 `CLAUDE_AUDIT.md`, whose F-1 is an unrelated `RuleIdentityRegistry` finding.

### A-1. `bindToken` — a bound RuleEngine must serve only `tokenContract`

| | |
|---|---|
| Location | `src/rules/operation/abstract/RuleIssuanceCapBase.sol:83`, `bindToken` |
| Code | `function bindToken(address token)` |
| Comment before | `@dev Reverts while a caller is bound; call `unbindToken` first to migrate.` / `@param token The token or RuleEngine to bind.` |
| Comment now | adds `WARNING: a bound RuleEngine MUST serve only `tokenContract`. The counter does not know which token minted, so every token the engine serves would consume this token's issuance budget.` and, on `@param token`, `A RuleEngine MUST serve only `tokenContract`.` |
| Finding | `CLAUDE_AUDIT.md` (**v0.7.0**) **F-1** (Info, downgraded from Low), "A RuleEngine serving several tokens shares one issuance counter" |
| Change applied | NatSpec and `RuleIssuanceCap.md` § Binding only; behaviour unchanged, so the `testIC1_*_CurrentBehaviour` PoCs still pass |

### A-2. `_afterMintChecked` — a recording subclass must gate `transferred`

| | |
|---|---|
| Location | `src/rules/validation/abstract/base/RuleMaxTotalSupplyBase.sol:213`, `_afterMintChecked` |
| Code | `function _afterMintChecked(uint256 value) internal virtual {}` |
| Comment before | `@dev The extension point for a subclass that must record accepted mints (`RuleIssuanceCap`). … cannot be skipped by the re-phasing.` |
| Comment now | adds `WARNING: both `transferred` overloads are public and ungated here, which is safe only because this contract writes nothing. A subclass that writes state in this hook MUST restrict both overloads to its bound caller (as `RuleIssuanceCap` does with `onlyBoundToken`), or anyone can record mints.` |
| Finding | `CLAUDE_AUDIT.md` (**v0.7.0**) **F-3** (Info), "`_afterMintChecked` does not warn that `transferred` is ungated" |
| Change applied | NatSpec only; behaviour unchanged, so `testMTS1_UngatedSubclassIsDrivableByAnyone_CurrentBehaviour` still passes |
