# Nethermind AuditAgent `v0.5.0` — triage

Tool: **[Nethermind AuditAgent](https://auditagent.nethermind.io/)** — an **AI-powered automated code scanner**.

> ⚠️ **This is not an audit.** The report carries Nethermind's own *Important Notice*: it "has been generated
> entirely by AI and has not been manually reviewed by Nethermind's security team. It does not constitute a full
> security audit… All findings, observations, and recommendations may contain errors or omissions and must be
> independently verified by a qualified human reviewer before being acted upon." Per Nethermind's terms, this
> scan does **not** authorise anyone to describe the project as "audited by Nethermind". **This document is that
> independent verification**: every one of the 24 findings was opened against the cited `file:line` before a
> disposition was assigned.

## Scan metadata

| | |
|---|---|
| Scan ID | `10` |
| Date | 2026-08-17 |
| Organization / Repository | CMTA / `Rules` |
| Branch / Commit | `main` @ `01632da0…951e204c` (`01632da`, the v0.5.0 merge commit — same tree as HEAD at triage time) |
| Contracts scanned | 89 (all of `src/`; mocks, tests and `lib/` out of scope) |
| Lines of code | 9 764 |

**Tool-reported findings summary — total 24:**

| High | Medium | Low | Info | Best practices |
|---|---|---|---|---|
| **0** | **13** | **11** | 0 | 0 |

## Outcome

**Nothing is exploitable, and no contract change is required for the CMTAT deployment path.**

| Disposition | Count | IDs |
|---|---|---|
| **Fixed** (in `v0.6.0`) | 4 | **NM-3**, **NM-6**, **NM-10**, **NM-11** |
| Accepted as design (real behaviour, intentional, already documented) | 17 | NM-1, 2, 4, 5, 7, 8, 9, 12, 13, 14, 15, 16, 17, 21, 22, 23, 24 |
| Rejected — false positive | 0 | — |
| Informational — valid, optional hardening | 3 | NM-18, 19, 20 |
| Fix recommended | 0 | — |
| **Total** | **24** | |

Two observations about the report as a whole:

1. **No false positives, and no High findings — but heavy duplication.** The 24 items collapse to roughly
   **11 distinct claims**. Approval/quota-scoping behind a shared RuleEngine is reported five times
   (NM-2, 4, 7, 8, 12, 15); the cap rules' static token binding twice (NM-5, 13); spender-less 3-arg hooks twice
   (NM-9, 16); short ABI return data twice (NM-23, 24). Counting each restatement as a separate Medium inflates
   the Medium column well past what the underlying set of issues warrants.
2. **The scanner rediscovered, and re-rated as Medium, four positions this project had already reached,
   documented in-source, and recorded in a prior audit** — F-4 (multi-token approval scoping),
   F-7 (`canTransfer` non-authoritative for `RuleMintAllowance`), F-5 (the wrapper's unchecked children), and
   the v0.4.0 accepted-risk row "reverting sanctions oracle / identity registry bricks transfers". It found the
   right things; it had no way to see that they were already decided.

**Seven entries carry an `Improvement` section** — NM-3, NM-5, NM-6, NM-10, NM-17, NM-18 and NM-23/24 — setting
out what could be implemented, the code to do it, what it buys, what it costs, and where the limit is. Two of
those limits are worth reading before planning work: **NM-5** cannot be fully fixed at the rule level at all (the
compliance hooks carry no token identity, so it needs an upstream interface change), and **NM-18**'s read-time
containment runs into the same uncatchable-decode problem as NM-23, which is why only its configuration-time
layer is recommended.

**Three of the seven have been implemented, all in `v0.6.0`: NM-3, NM-6 and NM-10** — see their `Resolution`
blocks below. The remaining four are specified but not applied.

**The one genuinely new and useful signal** is a theme the scanner keeps circling without naming:
**several rules' guarantees depend on the token's callback shape and ordering, and a real ERC-3643 / T-REX token
supplies neither.** That is developed under NM-11 and NM-9, and it was the only item that warranted new contracts.
It has since been acted on: `v0.6.0` ships ERC-3643 variants of the reserve and supply cap rules, with suites
running against the genuine vendored token.

---

## Per-finding triage

| ID | Severity (tool → ours) | Finding | Disposition |
|---|---|---|---|
| NM-1 | Medium → **Info** | Mint quotas unenforced via `created` / 3-arg `transferred` | Accepted as design — documented CMTAT ≥ v3.3 requirement |
| NM-2 | Medium → **Low** | Mint quotas shared across tokens behind one RuleEngine | Accepted as design — `bindToken` WARNING |
| NM-3 | Medium → **Info** | Early returns in `_detectTransferRestrictionFrom` skip delegation | ✅ **Fixed** in `v0.6.0` |
| NM-4 | Medium → **Low** | Approvals + quotas not token-scoped across shared engine / rebinding | Accepted as design — duplicate of NM-2 / NM-7 |
| NM-5 | Medium → **Low** | Cap rules read a statically configured token's supply | Accepted as design — documented "one token per instance" |
| NM-6 | Medium → **Info** | `RuleNFTAdapter` context vs ERC-7943 spender handling differ | ✅ **Fixed** in `v0.6.0` |
| NM-7 | Medium → **Low** | Single-token approvals reusable across tokens behind one engine | Accepted as design — `bindRuleEngine` WARNING |
| NM-8 | Medium → **Low** | Mint allowances shared across a multi-token engine | Accepted as design — duplicate of NM-2 |
| NM-9 | Medium → **Info** | 3-arg ERC-3643 hooks carry no spender, so spender rules are inert | Accepted as design — topology requirement; see NM-11 |
| NM-10 | Medium → **Info** | Future-dated PoR `updatedAt` skips the staleness check | ✅ **Fixed** in `v0.6.0` |
| NM-11 | Medium → **Low** | Caps double-count when the token notifies **after** moving value | ✅ **Fixed** in `v0.6.0` — ERC-3643 variants for 2 of 3 rules; `RuleMaxBalance` documented as CMTAT-only |
| NM-12 | Medium → **Low** | Single-token approval consumable by another token | Accepted as design — duplicate of NM-7 |
| NM-13 | Medium → **Low** | Cap rules never bind to the calling token; setters can repoint | Accepted as design — duplicate of NM-5 |
| NM-14 | Low → **Low** | Identity-registry failures revert the read path | Accepted as design — trusted dependency (v0.4.0 audit) |
| NM-15 | Low → **Low** | Conditional approvals not token-scoped | Accepted as design — duplicate of NM-7 |
| NM-16 | Low → **Info** | `RuleSpenderWhitelist` inert on spender-less hooks | Accepted as design — duplicate of NM-9 |
| NM-17 | Low → **Low** | `approveAndTransferIfAllowed` leaves a residual approval if no callback | Accepted as design — documented CEI inversion |
| NM-18 | Low → **Low** | Wrapper bricked by a non-`IAddressList` child | Informational — known open item (audit F-5) |
| NM-19 | Low → **Info** | Wrapper does not implement `IAddressList`, so it cannot nest | Informational — enhancement, never advertised |
| NM-20 | Low → **Info** | Wrapper reads a `RuleBlacklist` child's membership as eligibility | Informational — trusted-role misconfiguration |
| NM-21 | Low → **Info** | `RuleMintAllowance` 3-arg pre-flight views fail open | Accepted as design — audit F-7 |
| NM-22 | Low → **Low** | A misbehaving sanctions oracle reverts the read path | Accepted as design — trusted dependency (v0.4.0 audit) |
| NM-23 | Low → **Info** | Short successful return data escapes `try/catch` | Accepted as design — already documented in-source |
| NM-24 | Low → **Info** | Same, for `balanceOf` / `totalSupply` | Accepted as design — duplicate of NM-23 |

---

### NM-1 — Mint quotas are not enforced via `created` or the 3-arg `transferred`

**Claim (Medium).** `RuleMintAllowanceBase` deducts only in `_transferredFrom`, reached only from
`transferred(spender, from, to, value)`. `created(address,uint256)` is empty and the 3-arg `transferred` calls an
empty `_transferred`, so a bound integration reporting mints either way completes them without touching
`mintAllowance`.

**Verdict — accepted as design, correct as written.** The code is exactly as described
(`RuleMintAllowanceBase.sol:63`, `:154-161`, `:258-260`), and confirmed one level up:
`RuleEngineBase.created(to, value)` forwards `_transferred(address(0), to, value)` — the **3-arg** path — so a
token that reports mints through `created` does indeed reach a no-op.

This is not a gap that can be closed by checking harder: **the 3-arg signature carries no minter identity**, so
there is no address to debit. The rule states the requirement in its own NatSpec ("The rule tracks mints via the
4-arg `transferred(spender, from=0, to, value)` path introduced in CMTAT v3.3. The 3-arg path has no minter
identity and performs no deduction"), in `CLAUDE.md` ("Requires CMTAT ≥ v3.3"), and in
`RULE_SEMANTICS.md` §1. On the supported CMTAT ≥ v3.3 path, `_mintOverride` calls
`_checkTransferred(_msgSender(), address(0), to, value)`, the 4-arg overload runs, and the quota is enforced.

*Optional hardening, not applied:* `_transferred` could **fail closed** when `from == address(0)` — reverting a
mint reported without a minter identity rather than passing it. It would fire only where the quota is silently
inert today, and would leave plain transfers and burns untouched. Recorded as a deliberate open choice: it turns
a documented "unsupported topology" into a hard revert, which is the safer default for a quota rule but is a
breaking change for any pre-v3.3 integration.

### NM-2 / NM-4 / NM-8 — Mint quotas shared across tokens behind one RuleEngine

**Claim (Medium ×3).** `mapping(address minter => uint256 allowance)` has no token dimension. Binding one
RuleEngine authorises a caller, not a token, and an engine may serve several tokens; a quota granted for token A
is spendable minting token B.

**Verdict — accepted as design, explicitly documented.** True and known. `bindToken` enforces single-target
binding (`RuleMintAllowance_TokenAlreadyBound`), and its NatSpec carries the WARNING that `unbindToken` does not
clear `mintAllowance` and that quotas survive rebinding, with `clearMintAllowances` provided for migration
(v0.4.0 audit F-9). The residual exposure — an operator binding a **multi-tenant** engine — sits inside the
trust model: the compliance manager who chooses the engine is the same role that grants the quotas. This is the
same shape as the documented "one instance protects one token, with no on-chain guard" position taken for
`RuleMaxTotalSupply` / `RuleChainlinkPoR`, and the reasoning is recorded there: adding a binding guard to a
stateless validation rule is a library-wide decision, not a per-rule patch.

### NM-3 — Early returns in `_detectTransferRestrictionFrom` skip the delegation — ✅ FIXED (`v0.6.0`)

**Claim (Medium).** `RuleIdentityRegistryBase._detectTransferRestrictionFrom` returns `TRANSFER_OK` directly when
the registry is unset or `to == address(0)`, instead of delegating to `_detectTransferRestriction`. A subclass
adding checks to the latter without also overriding the former would have them silently bypassed —
and `RuleSanctionsListBase` documents having fixed this exact anti-pattern.

**Verdict — informational; valid observation, no current impact.** The code is as described
(`RuleIdentityRegistryBase.sol:234-241`), and the cross-reference is accurate: `RuleSanctionsListBase.sol:187-190`
carries precisely that warning. But the two early returns here are **duplicates of the delegate's own first two
guards** (`:197-204`): delegating would return `TRANSFER_OK` for the same inputs, so behaviour is identical today.
No subclass of `RuleIdentityRegistryBase` overrides `_detectTransferRestriction` — the only descendants are the
two deployment variants.

**Improvement — implemented in `v0.6.0`; behaviour-preserving, ~4 lines.** Delegate instead of returning a
literal, exactly as `RuleSanctionsListBase` was changed to do. In
`RuleIdentityRegistryBase._detectTransferRestrictionFrom` (`:234-241`), replace the two early returns:

```solidity
// before
IIdentityRegistryVerified registry = identityRegistry;
if (address(registry) == address(0)) {
    return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
}
if (to == address(0)) {
    return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
}

// after — the guards still scope ONLY the spender check; the delegation is unconditional
IIdentityRegistryVerified registry = identityRegistry;
if (address(registry) == address(0) || to == address(0)) {
    return _detectTransferRestriction(from, to, value);
}
```

Why this is safe:

- **Identical outputs today.** `_detectTransferRestriction` opens with the same two guards (`:197-204`) and
  returns `TRANSFER_OK` for both, so no input changes answer. The existing test suite should pass unmodified —
  if any test moves, the change was not behaviour-preserving and must be re-examined rather than re-baselined.
- **Burn stays exempt from the spender check.** The delegate never screens a spender, so routing burn through it
  preserves the property the current comment at `:247-249` protects. That comment ("Burn is exempt too, but by
  the early return above -- do NOT re-test `to` here") must be rewritten to say the guard now delegates, or it
  becomes a stale claim about code that no longer exists.
- **`view` and gas are unchanged** — one extra internal call, no storage access added.

What it buys: a subclass that overrides only `_detectTransferRestriction` (the natural hook to extend) gets its
check honoured on the `transferFrom`, mint and burn paths instead of silently dropped. That is the trap the
sibling rule already closed, so closing it here also removes an inconsistency between two rules a reader will
compare.

**Also reviewed at the same time:** every other rule that overrides both hooks. `RuleMaxBalanceBase` (`:149-157`),
`RuleMaxTotalSupplyBase` and `RuleChainlinkPoRBase` already delegate unconditionally and needed no change;
`RuleSpenderWhitelistBase._detectTransferRestrictionFrom` (`:102-115`) deliberately does **not** delegate, because
its `_detectTransferRestriction` is a hardcoded `TRANSFER_OK` — left as is.

**Resolution — `v0.6.0`.**

*Changed:* `src/rules/validation/abstract/base/RuleIdentityRegistryBase.sol` — the two early returns become one
guard that delegates, and the `:247-249` comment (which asserted burn was handled "by the early return above")
was rewritten so it describes the code that now exists rather than the code that was removed.

*Regression tests added:*

- `src/mocks/harness/IdentityRegistryDelegationHarness.sol` — `IdentityRegistryExtraCheckHarness`, a subclass
  that overrides **only** `_detectTransferRestriction` to add a registry-independent check. This is the shape
  that exposes the defect, and it mirrors `SanctionsListDelegationHarness` one for one.
- `test/RuleIdentityRegistry/RuleIdentityRegistryDelegation.t.sol` — 8 tests: the subclass check must reach
  `transferFrom` with no registry configured and on `burnFrom`; the two entrypoints must agree; burn must stay
  exempt from the opt-in spender check; the spender check must still short-circuit ahead of the delegated hook;
  and base ERC-3643 screening (receiver-only, unverified sender and minter allowed) must be unchanged.

*Verified, not assumed.* Reverting the source change and re-running the new suite fails 3 of the 8 tests with
exactly the predicted symptoms — `transferFrom must reach the same hook as transfer: 0 != 202`,
`burnFrom must reach the same hook as burn: 0 != 202`, and the two-entrypoint disagreement — and they pass once
the change is restored. The pre-existing 21 `RuleIdentityRegistry` tests pass unmodified, which is the evidence
that the change is behaviour-preserving: had any answer moved, one of them would have.

*Suites:* 828 tests pass on the default profile and 31 on `FOUNDRY_PROFILE=erc3643`. Coverage on the changed
contract: **100% statements, 100% branches**, 98.41% lines — the single uncovered line is the abstract
`_authorizeIdentityRegistryManager` declaration, which no test can execute because only the override runs.

### NM-5 / NM-13 — Cap rules evaluate a statically configured token

**Claim (Medium ×2).** `RuleMaxTotalSupplyBase`, `RuleChainlinkPoRBase` and `RuleMaxBalanceBase` read
`totalSupply()` / `balanceOf()` from a configured address and never verify that `msg.sender` is that token. One
instance behind a shared engine caps the wrong asset; and `setTokenContract` / `setTokenMetadata` /
`setBalanceToken` can repoint the observation target at any callable contract.

**Verdict — accepted as design, documented verbatim.** Both halves are true and both are already on the record.
`CLAUDE.md` states it as a standing gotcha: *"they read `totalSupply()` from the configured `tokenContract`, never
from the token that triggered the check, and behind a RuleEngine they cannot learn that identity. One instance
added to two RuleEngines evaluates both tokens against the first one's supply and feed… Chainlink's
`SecureMintPolicy` blocks this with `onInstall`/`PolicyAlreadyBound`; adding an equivalent here would mean making
a stateless validation rule bindable, which is a library-wide decision. Documented, not fixed."* The repointing
half was catalogued and dismissed in the v0.4.0 audit ("`RuleMaxTotalSupply.setTokenContract` can repoint the
supply oracle — trusted role"), and every repoint emits `TokenContractUpdated` / `TokenMetadataUpdated` /
`MaxBalanceTokenUpdated` for off-chain monitoring.

**Improvement — partially implementable; the complete fix is not available at the rule level.**

*What cannot be done here.* The rule is never told which token triggered a check. `IRule`'s hooks are
`transferred(from, to, value)` and `transferred(spender, from, to, value)` — **no token parameter** — and behind a
RuleEngine `msg.sender` is the engine, so the identity is not recoverable from the call either. `IRule` also has
no `onInstall` hook, so the rule is not even notified when it is added to an engine: `RulesManagementModule._addRule`
only validates and stores the address. A rule that serves two tokens through one engine therefore *cannot*
distinguish them, whatever it stores. Closing that half requires a token argument on the compliance hooks — an
upstream `RuleEngine` / CMTAT interface change, the same conclusion reached for F-4.

*What can be done — opt-in caller binding, closing the "one instance, two engines" half.* This blocks the
deployment mistake the CLAUDE.md gotcha actually describes, and is `view`-preserving:

```solidity
// in TotalSupplyCapManager / ChainlinkPoRFeedManager / BalanceCapManager
/// @notice When set, the only address allowed to notify this rule. Zero = unrestricted (legacy behaviour).
address public boundCaller;

function bindCaller(address caller) public virtual onlyMaxTotalSupplyManager {
    require(caller != address(0), RuleMaxTotalSupply_CallerAddressZeroNotAllowed());
    require(boundCaller == address(0), RuleMaxTotalSupply_CallerAlreadyBound(boundCaller));
    boundCaller = caller;
    emit CallerBound(caller);
}

// in the rule's write hooks only -- never on the ERC-1404 read path
function _assertBoundCaller() internal view virtual {
    address bound = boundCaller;
    require(bound == address(0) || msg.sender == bound, RuleMaxTotalSupply_CallerNotBound(bound, msg.sender));
}
```

Design constraints that make this shape the right one:

- **Bind at configuration, not on first use.** Pinning the first caller lazily would need an `SSTORE` inside
  `_transferred`, which is `internal view` today and whose public `transferred(...)` wrappers are declared `view`.
  Making them non-`view` changes the published ABI mutability of four deployable contracts and turns read-only
  validation rules into stateful ones. An explicit one-shot setter keeps every hook `view` and costs one warm
  `SLOAD` per transfer.
- **Unset must stay permissive**, or the change is breaking for every existing deployment and for the direct
  (Topology B) wiring where the token itself calls the rule.
- **Enforce on the write path only.** Adding the check to `detectTransferRestriction` would make a third party's
  pre-flight query revert or fail, and those views must not revert.
- **Add `unbindCaller`**, symmetric with `unbindToken` on the operation rules, or a mis-set binding bricks the
  rule permanently. Document that unbinding does not reset the observed token.

*What this does and does not buy.* It stops one instance being wired into two RuleEngines — the silent
over-mint/freeze scenario. It does **not** isolate two tokens served by a single engine; that remains open and
must stay documented. Given it is a partial remedy for a documented, trusted-role misconfiguration, the honest
cost/benefit is: worth doing if the cap rules ever ship an upgradeable variant or a deployment script that wires
engines automatically, and not worth a breaking storage-layout change before then.

*Zero-cost alternative available today:* `tokenContract` / `balanceToken` are already public and every change
emits an event, so a deployment checklist plus an off-chain assertion that
`rule.tokenContract() == the token whose engine holds this rule` catches both halves — including the one no
on-chain guard can reach. That is the currently recommended control and should be stated in the deployment guide.

### NM-6 — `RuleNFTAdapter` handles owner-initiated transfers differently across entrypoints — ✅ FIXED (`v0.6.0`)

**Claim (Medium).** `transferred(FungibleTransferContext)` / `(MultiTokenTransferContext)` normalise
`ctx.sender == ctx.from` to the direct `_transferred` hook, while the ERC-7943 5-arg
`transferred(spender, from, to, tokenId, value)` always calls `_transferredFrom`. For `spender == from`,
`RuleSpenderWhitelist` accepts via the context path and rejects via the ERC-7943 path.

**Verdict — informational; confirmed divergence, not a bypass.** The asymmetry is real
(`RuleNFTAdapter.sol:46-63` vs `:89-102`). It is not a loosening of policy: **the context path's answer is the
one that matches the rest of the library.** `RuleSpenderWhitelist`'s documented contract is that *direct*
transfers are always allowed and only delegated ones are screened; an owner moving their own tokens is a direct
transfer, and a plain ERC-20 `transfer` produces exactly the same outcome (CMTAT passes `spender == address(0)`,
taking the 3-arg path). The deviant branch is the ERC-7943 5-arg one, which is **stricter** than intended when a
caller elects to pass `spender == from`. Nothing is admitted that a plain transfer would not admit, so there is
no compliance gap — only an inconsistency for an integrator who reaches for both surfaces.

**Improvement — implemented in `v0.6.0`; contained to one file.** Lift the normalisation the context entrypoints
already perform into a shared helper, and apply it to the ERC-7943 overloads so all six adapter entrypoints agree.

```solidity
// RuleNFTAdapter -- one predicate, used by every entrypoint that receives a spender
/**
 * @notice Returns whether `spender` acts on behalf of `from` rather than as `from` itself.
 * @dev An owner moving their own tokens is a direct transfer: a plain ERC-20 `transfer` reaches
 *      the 3-arg hook with `spender == address(0)`, and the ITransferContext entrypoints already
 *      normalise `sender == from` the same way.
 */
function _isDelegated(address spender, address from) internal pure virtual returns (bool) {
    return spender != address(0) && spender != from;
}
```

Then the two `ITransferContext` entrypoints (`:46-63`) become `if (_isDelegated(ctx.sender, ctx.from))`, and the
three spender-aware ERC-7943 overloads gain the same branch:

```solidity
function transferred(address spender, address from, address to, uint256 /* tokenId */, uint256 value)
    public virtual override(IERC7943NonFungibleComplianceExtend)
{
    if (_isDelegated(spender, from)) {
        _transferredFrom(spender, from, to, value);
    } else {
        _transferred(from, to, value);
    }
}
// identically for detectTransferRestrictionFrom(...) and canTransferFrom(...)
```

Behaviour audit — which rules actually change when `spender == from` on the 5-arg path:

| Rule | Today | After | Net |
|---|---|---|---|
| `RuleSpenderWhitelist` | rejects an unlisted owner (code 66) | allows | **Fixed** — matches its documented "direct transfers are always allowed" |
| `RuleBlacklist`, `RuleSanctionsList`, `RuleERC2980` | blocks via the spender branch | blocks via the `from` branch | none — still blocked, different code |
| `RuleWhitelist` (`checkSpender`) | needs `from` listed *and* spender listed | needs `from` listed | none — same address |
| `RuleIdentityRegistry` (`checkSpender` on, `checkSender` off) | rejects an unverified owner (code 57) | allows | **Observable change**, and the ERC-3643-conformant answer: the spec screens the receiver only, and the same holder's plain `transfer` already passes |

So the deny-lists are unaffected, one rule is corrected, and one loosens in the direction the standard requires.
Cost: one `internal pure` call, no storage. Pin it with a test per affected rule asserting that the 5-arg
`spender == from` call and the 3-arg call return the same code.

*Rejected alternative — normalise the other way* (make the context entrypoints always call `_transferredFrom`,
retaining spender semantics). It would screen an owner as their own spender on every plain transfer relayed
through `ITransferContext`, breaking `RuleSpenderWhitelist`'s documented contract and diverging from what CMTAT
produces for the same transfer. Consistency achieved at the price of the wrong answer.

*Do not* apply the normalisation inside `_detectTransferRestrictionFrom` / `_transferredFrom` themselves: those
are the generic 4-arg hooks CMTAT and the RuleEngine call, and rewriting `spender == from` there would silently
change every rule on the main integration path, not just the ERC-7943 surface.

**Resolution — `v0.6.0`.**

*The principle that fixed the scope.* The three interfaces signal a direct transfer **differently**, and that,
not the entrypoint count, is what decides the routing:

| Interface | Direct transfer arrives as | Delegated as |
|---|---|---|
| CMTAT 3-arg / 4-arg | the 3-arg overload, or `spender == address(0)` | `spender != address(0)` |
| ERC-7943 `tokenId` overloads | `spender == from` — the interface calls that parameter "the address performing the transfer (**owner**/operator)" | `spender != from` |
| `ITransferContext` | `sender == from` (the token's `msg.sender`), or `0` | `sender != from` |

The ERC-7943 and `ctx` interfaces share a convention; the CMTAT pair uses a different one that already
distinguishes the two cases. So the fix normalises the **adapter** entrypoints only, and deliberately leaves the
4-arg CMTAT path alone — which also means no change to the primary integration path, no restriction-code
relabelling for existing integrators, and one file touched instead of twelve.

*Changed:* `src/rules/validation/abstract/core/RuleNFTAdapter.sol` — added
`_isDelegated(spender, from) => spender != address(0) && spender != from`, replaced the duplicated predicate in
both `ctx` entrypoints with it, and routed the three ERC-7943 spender-aware overloads
(`transferred`, `detectTransferRestrictionFrom`, `canTransferFrom`) through it. Contract-level NatSpec records
the table above and warns against "aligning" the 4-arg path.

*Regression tests* in `test/TransferContext/OverloadParity.t.sol` — the suite already existed for exactly this
property but only ever tested two of the three input shapes (`sender == 0` and `sender != from`), which is why
the gap survived. Added `_assertSelfSpenderIsDirect`, run for every rule in the suite on both an allowed and a
blocked pair, plus two targeted tests: `test_NM6_SelfSpenderIsNotScreenedByTheSpenderWhitelist` (the outcome
that was wrong) and `test_NM6_CmtatFourArgPathKeepsScreeningASelfSpender` (pinning the deliberate asymmetry so
nobody removes it later). The suite's header comment, which asserted flat parity, now states the per-interface
conventions — the loose wording is what made the missing case invisible.

*Verified, not assumed.* Reverting the three routings fails **6 of 10** tests across **5 rules**, and the failure
messages are the impact analysis:

```
RuleBlacklist      [self-spender, blocked]: 38 != 36     ← blocked either way, code relabelled
RuleERC2980        [self-spender, blocked]: 62 != 60     ← blocked either way, code relabelled
RuleSanctionsList  [self-spender, blocked]: 32 != 30     ← blocked either way, code relabelled
RuleWhitelist      [self-spender, blocked]: 23 != 21     ← blocked either way, code relabelled
RuleSpenderWhitelist [self-spender]:        66 != 0      ← THE ONLY OUTCOME CHANGE
```

For the deny-lists the transfer was rejected before and after — only which leg reported it changed, because the
owner is screened as `from` instead of as `spender`. `RuleSpenderWhitelist` is the one rule where the answer was
actually wrong: an owner-initiated ERC-721 `transferFrom` was rejected with code 66 despite the rule documenting
that direct transfers are always allowed. A genuine delegated transfer by the same unlisted address is still
rejected — the screen was narrowed to what it always claimed to cover, not removed.

*Suites:* 835 tests pass on the default profile, 31 on `FOUNDRY_PROFILE=erc3643`. Coverage on `RuleNFTAdapter`:
**100% statements, 100% branches**.

*Also updated:* `RULE_SEMANTICS.md` §3, which previously described the parity as flat and is now the reference
for the per-interface conventions.

### NM-7 / NM-12 / NM-15 — Conditional-transfer approvals are not token-scoped

**Claim (Medium ×2, Low ×1).** `_transferHash(from, to, value)` has no token dimension, while `bindRuleEngine`
authorises an engine that may relay several tokens. An approval recorded for token A is consumable by an
identical transfer of token B, and `unbindToken` clears neither `approvalCounts` nor `ruleEngine`.

**Verdict — accepted as design; this is the documented reason the multi-token variant exists.** Verified at
`RuleConditionalTransferLightApprovalBase.sol:163-174` and `RuleConditionalTransferLightBase.sol:191-206`. The
`bindRuleEngine` NatSpec states the constraint in the scanner's own terms and then some:

> **bind ONLY an engine that serves this one token.** Approvals here are keyed `(from, to, value)` with **no
> token dimension**… If the engine serves several tokens, an approval recorded for one is consumable by ANY of
> them — approve 100 for token A, and a 100 transfer of token B consumes it. That is inherent to the single-token
> rule and is why `RuleConditionalTransferLightMultiToken` exists.

The stale-state half is covered by the `bindToken` WARNING plus `resetApproval` / `unbindRuleEngine` (v0.4.0
audit F-9). The scanner's closing point — "enforced solely by NatSpec warnings; nothing in the code prevents an
administrator from wiring a multi-tenant engine" — is correct and is the accepted position: the compliance
manager is a trusted role, and the alternative (a per-token approval key) is a different rule that already ships.

### NM-9 / NM-16 — Spender policy is unenforceable through spender-less hooks

**Claim (Medium + Low).** Spender screening lives exclusively on the 4-arg path.
`RuleSpenderWhitelistBase.transferred(address,address,uint256)` is a no-op and its 3-arg detector returns
`TRANSFER_OK`; the same context loss disables code 23 (unlisted spender), 38 (blacklisted), 32 (sanctioned) and
62 (frozen). A token routing `transferFrom` through the 3-arg path lets a restricted spender move tokens.

**Verdict — accepted as design; correct, and a topology requirement rather than a defect.** Verified at
`RuleSpenderWhitelistBase.sol:49`, `:91-93`, `:102-115`. A rule cannot screen an identity it is never given.
`RULE_SEMANTICS.md` §1 already scopes the whole spender column to "the 4-arg `transferred(spender, from, to,
value)` path… (CMTAT v3.3+)".

The scanner is nonetheless pointing at something worth stating more loudly, and it is the same root cause as
NM-11: **a real ERC-3643 / T-REX token calls `_tokenCompliance.transferred(_from, _to, _amount)` from
`transferFrom` — three arguments, no spender.** On that integration `RuleSpenderWhitelist` is *silently inert*
rather than merely unhelpful, and the spender branches of the blacklist / sanctions / ERC-2980 rules never fire.
Both supply-based cap rules now ship ERC-3643 variants (NM-11), and the per-interface conventions are written up
in `RULE_SEMANTICS.md` §5; the spender-inertness above remains a documentation matter, since no rule can screen
an identity it is never given.

### NM-10 — Future-dated PoR timestamps skip the freshness check — ✅ FIXED (`v0.6.0`)

**Claim (Medium).** `ChainlinkPoRFeedManager._maxBackedSupply` flags staleness only when
`block.timestamp > updatedAt`; it does not reject `updatedAt > block.timestamp`. A feed returning an old answer
with a future timestamp is treated as fresh until that timestamp plus the staleness window elapses.

**Verdict — informational; confirmed code behaviour, the cheapest hardening in the report.** The guard is exactly
as quoted (`ChainlinkPoRFeedManager.sol:215`):

```solidity
if (staleness != 0 && block.timestamp > updatedAt && block.timestamp - updatedAt > staleness) {
```

The `block.timestamp > updatedAt` term exists to keep the subtraction from underflowing on a MUST-NOT-revert
path, and it has the side effect of admitting any future timestamp. Reachability is narrow: a Chainlink
aggregator stamps `updatedAt` with `block.timestamp` at write time on the same chain, so a future value cannot
arise legitimately — it requires a faulty or compromised feed, and the report's own severity note concedes that
"a future timestamp alone does not increase mint headroom". A feed able to forge a timestamp can also simply
overstate `answer`, which the rule trusts by construction.

**Improvement — implemented in `v0.6.0`; one line, no new restriction code, no new storage.** Treat a future `updatedAt`
as a **malformed answer** rather than as a staleness question. `CODE_RESERVES_ANSWER_INVALID` (77) already means
"the feed responded but the answer cannot be used: a negative reserve, or an incomplete round", and a round
stamped in the future is the same class of defect. Fold it into that existing branch
(`ChainlinkPoRFeedManager.sol:209-217`):

```solidity
try feed.latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
    // A negative reserve is meaningless, `updatedAt == 0` marks a round that never completed, and a
    // round stamped in the future cannot have been written by an aggregator on this chain -- all three
    // are malformed answers, not stale ones.
    if (answer < 0 || updatedAt == 0 || updatedAt > block.timestamp) {
        return (CODE_RESERVES_ANSWER_INVALID, 0);
    }
    uint256 staleness = maxStalenessSeconds;
    // `updatedAt <= block.timestamp` is guaranteed above, so the subtraction cannot underflow and the
    // `block.timestamp > updatedAt` guard that used to carry it is no longer needed.
    if (staleness != 0 && block.timestamp - updatedAt > staleness) {
        return (CODE_RESERVES_FEED_STALE, 0);
    }
    ...
```

Why this framing beats a second staleness branch:

- **It resolves the `maxStalenessSeconds == 0` ambiguity instead of creating it.** Zero is documented as
  *disabling the staleness check*; a future-timestamp rejection gated on `staleness != 0` would be surprising,
  and one that ignores the gate would contradict the documented meaning of zero. As an answer-validity check it
  is correctly unconditional — a malformed round is malformed whether or not freshness is being policed.
- **No code-range or ABI change.** 77 already exists, is already returned by `canReturnTransferRestrictionCode`
  (`RuleChainlinkPoRBase.sol:62-66`), and already has a `messageForTransferRestriction` string. Adding a new code
  would touch the invariant storage, the message mapping, `canReturnTransferRestrictionCode`, `CLAUDE.md`'s code
  table and the docs, for no diagnostic gain.
- **It removes the underflow guard's side effect** rather than layering a second check on top of it, so the
  reason each comparison exists stays legible.
- **It cannot break the revert-free invariant**: the change is one comparison on values already in scope.

**Resolution — `v0.6.0`.**

*Changed:*

- `src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol` — `updatedAt > block.timestamp` folded into the
  malformed-answer branch, and the now-redundant `block.timestamp > updatedAt` term dropped from the staleness
  comparison (step 3 guarantees the subtraction cannot underflow). The comment states why a future stamp is not
  treated as staleness.
- `src/rules/validation/abstract/invariant/RuleChainlinkPoRInvariantStorage.sol` — the
  `CODE_RESERVES_ANSWER_INVALID` NatSpec now lists all three causes and records the `maxStalenessSeconds == 0`
  reasoning.

*Regression tests added* — 5 in `test/RuleChainlinkPoR/RuleChainlinkPoRUnit.t.sol`: a future-dated round yields
77 from `detectTransferRestriction` and `canTransfer`; it is still rejected with `maxStalenessSeconds == 0` (the
test that pins the design decision); `updatedAt == block.timestamp` still passes (the boundary a just-published
round sits on); `maxBackedSupply()` previews 77 without reverting; and the write hook reverts the mint.

*Verified, not assumed.* Reverting the source change fails 4 of the 5 with the predicted symptoms —
`assertion failed: 0 != 77` three times, and `next call did not revert as expected` for the enforcement test. The
fifth (the `updatedAt == block.timestamp` boundary) passes either way by construction, which is what makes it a
useful guard against over-correcting into `updatedAt >= block.timestamp`.

*Suites:* 833 tests pass on the default profile, 31 on `FOUNDRY_PROFILE=erc3643`. Coverage on
`ChainlinkPoRFeedManager`: **100% statements, 100% branches**; `RuleChainlinkPoRBase` 100% across the board.

*Also updated:* `doc/technical/contracts/RuleChainlinkPoR.md` — the restriction-code table, the numbered
evaluation order, the operator triage table, and the two rows of the Chainlink ACE comparison that described the
old underflow guard. The ACE comparison now records that this rule rejects a future-dated round where ACE
underflow-panics on it, and that the rejection is not gated on `maxStalenessSeconds`.

Still hardening rather than a fix in impact terms: reaching the branch needs an aggregator already misbehaving
badly enough to forge a timestamp, and such an aggregator can overstate `answer` directly. What it buys is that
the rule no longer has a state in which it treats an impossible timestamp as evidence of freshness.

### NM-11 — Caps double-count when the token notifies **after** moving the value — ✅ FIXED (`v0.6.0`, 2 of 3 rules)

**Claim (Medium).** `BalanceCapManager._capExceeded` and `TotalSupplyCapManager._capExceeded` compare the live
balance/supply against `value`. That is correct only if the token calls `transferred(...)` *before* mutating
state. ERC-3643 / T-REX tokens call it *after*, so `balanceOf(to)` already includes `value` and the effective cap
becomes `balance_before + 2 × value <= maxBalance`. The read path (`canTransfer`) answers pre-update and the
write path then reverts on the same parameters — legitimate transfers are blocked and the last chunk of headroom
is unreachable.

**Verdict — CONFIRMED.** Every step checks out:

- The assumption is real and already stated in-source (`RuleMaxBalanceBase.sol:21-23`): *"**Assumes the token
  calls this BEFORE moving the value**, so `balanceOf(to)` still excludes `value`. CMTAT does; a token notifying
  afterwards would halve the effective cap."* It is pinned by
  `testMintExactlyToTheCapProvesPreUpdateAccounting`, and `CLAUDE_ANALYSIS_MAXBALANCE.md` H-1 records the
  mutation test that proved the guard.
- The vendored T-REX token calls it afterwards. `lib/ERC-3643/contracts/token/Token.sol` — `transfer` (`:532-533`),
  `transferFrom` (`:312-313`) and `forcedTransfer` (`:557-558`) each run `_transfer(...)` **then**
  `_tokenCompliance.transferred(...)`; `mint` reports through `_tokenCompliance.created(_to, _amount)` (`:572`,
  after `_mint`), which `RuleEngineBase.created` forwards as the 3-arg `transferred(address(0), to, value)` — and
  both cap rules gate on `from == address(0)`, so the mint path is affected too.
- **This is a configuration the project supports and tests**, not a hypothetical: `test/ERC3643Real/
  ERC3643RealTokenRuleEngine.t.sol` wires `real ERC-3643 Token ── compliance slot ──▶ RuleEngine ──▶ Rule` and
  relies on the rule reverting inside the post-state-change notification as the enforcement mechanism
  (`testForcedTransfer_StillBlockedByTheRuleViaTransferred`). That suite exercises `RuleWhitelist`, which is
  order-independent; **no cap rule is covered there**, which is why this was not caught.

Direction of failure is **conservative** — over-restriction, never over-issuance. Nothing can be minted or
received above the cap; what breaks is that transfers and mints *within* the cap are rejected, and the pre-flight
view disagrees with enforcement. There is no exploit, and the CMTAT path is unaffected.

**Enabling structure landed in `v0.6.0` (the fix itself is still a deployment choice).** The three rules now
share [`CapAccounting`](../../../../../src/rules/validation/abstract/core/CapAccounting.sol) and each exposes
`_detectTransferRestrictionOnNotify`, the hook the **write** path enforces through. It defaults to the pre-flight
check — today's CMTAT behaviour, unchanged — and an ERC-3643 variant overrides one line:

```solidity
function _detectTransferRestrictionOnNotify(address from, address to, uint256)
    internal view override returns (uint8)
{
    return _detectTransferRestriction(from, to, 0);   // the observation already includes the value
}
```

Two design points that came out of building it, both now pinned by tests:

- **Only the write path may be re-phased.** A single "observation includes the value" flag applied to both paths
  was the first shape tried and is wrong: a pre-flight view always runs *before* the movement on either kind of
  token, so re-phasing it makes the pre-flight answer disagree with enforcement — the mirror image of this very
  finding. `testMaxTotalSupply_PreFlightViewStillCountsTheValue` pins that.
- **`_currentSupply` / `_balanceOf` are the second seam**, letting a rule serve the figure from its own storage
  instead of the token. Such a rule controls when it records, so it never has to answer the phase question at
  all. Verified feasible for *supply*; **not** for per-address balances, because how `Token.recoveryAddress`
  moves a balance changed across T-REX versions — up to 4.1 it routed through the public `forcedTransfer`, which
  notifies compliance, while the vendored 4.2.0-beta1 calls `_transfer` directly and notifies nobody. A shadow
  ledger would be correct on one minor version and permanently skewed on the next.

Worked variants of all three rules live in `src/mocks/harness/ERC3643CapHarnesses.sol`, and
`test/CapAccounting/ERC3643CapSeams.t.sol` reproduces this finding on the stock rules while showing the variants
are correct. `RULE_SEMANTICS.md` §5 is the write-up.

**Resolution — `v0.6.0`. Shipped for two of the three rules; the third is deliberately left.**

*The arithmetic, concretely.* Reserves 1000, supply 0, an agent mints 1000 on a real T-REX token:

| Step | `_currentSupply()` | Comparison | Result |
|---|---|---|---|
| 1. `canTransfer(0, to, 1000)` — **before** `_mint` | `0` | `_capExceededBy(0, 1000, 1000)` → `1000 > 1000-0`? no | allowed |
| 2. `_mint(to, 1000)` | — | supply becomes 1000 | — |
| 3a. `created` → **stock rule** | `1000` | `_capExceededBy(1000, 1000, 1000)` → `1000 > 0`? **yes** | **reverts** |
| 3b. `created` → **ERC-3643 variant** | `1000` | `_capExceededBy(1000, 1000, 0)` → `0 > 0`? no | allowed |

At step 3 the minted amount is already inside `currentSupply`; the stock rule adds the same amount again as
`value` and asks whether 2000 fits under 1000. Row 1 is why the read path must keep projecting `value`: the token
consults compliance on **both** sides of the state change inside one transaction.

*Contracts added.*

| Contract | For |
|---|---|
| `RuleChainlinkPoRERC3643` / `…Ownable2Step` | Reserve-backed mint cap on ERC-3643 |
| `RuleMaxTotalSupplyERC3643` / `…Ownable2Step` | Static supply cap on ERC-3643 |

Each is a subclass overriding `_detectTransferRestrictionOnNotify` and nothing else; reserve/cap logic,
restriction codes, configuration, roles and events are inherited unchanged, and the stock rules are untouched.

*Tests.* 49 added in total:

- `test/ERC3643Real/ERC3643RealTokenChainlinkPoR.t.sol` (12) and
  `test/ERC3643Real/ERC3643RealTokenMaxTotalSupply.t.sol` (10) drive the **genuine** vendored
  `lib/ERC-3643/` token, not a mock. Four of them pin the stock rules failing on that same token, so this
  finding stays executable rather than becoming prose.
- The supply-cap suite covers **both compositions with the PoR variant** — static cap binding and reserves
  binding — which is the pairing the documentation prescribes, since PoR has no margin parameter.
- Unit suites in the default profile for each variant (10 + 10), because `forge coverage` skips
  `test/ERC3643Real/**` and the deployables would otherwise report 0%.
- `test/CapAccounting/ERC3643CapSeams.t.sol` (7) covers the seams generically, including `RuleMaxBalance`.

*A second ERC-3643 hazard found while testing this one, and now pinned.* T-REX deploys the token and
initialises it in two steps, and an uninitialised `Token` reports `decimals() == 0`. `RuleChainlinkPoR`'s
constructor probes `decimals()` and accepts a matching `0`, so a rule built before `init` is configured for a
0-decimals token — and `init(..., 18, ...)` then makes it an 18-decimals token while the rule still believes 0.
Nothing reverts and no event marks it; reserves are scaled by `10 ** 18` too little and every mint is refused.
The same mistake reversed would authorise unbacked minting. The constructor probe cannot catch it — it genuinely
succeeded. The remedy is deployment order (build the rule after `init`, or re-sync with `setTokenMetadata`),
documented on the contract page and pinned by `testRuleBuiltBeforeInitCachesTheWrongDecimals`.

*Documentation.* New pages `doc/technical/contracts/RuleChainlinkPoRERC3643.md` and
`RuleMaxTotalSupplyERC3643.md`, each leading with the ERC-3643-only warning and a table of what breaks with the
wrong variant **in either direction** — neither mistake reverts at deployment. `RULE_SEMANTICS.md` §5 carries the
seam write-up; `CLAUDE.md` / `AGENTS.md` carry the gotcha; both READMEs list the variants.

**`RuleMaxBalance` deliberately has no ERC-3643 variant.** It is not the same one-line change, for three reasons
that need a policy decision rather than a hook override:

- `balanceOf(to)` is **per-address**, so the rule engages on every transfer rather than only on mints — a far
  larger interaction surface with T-REX's agent powers than the two supply rules have.
- **`forcedTransfer` does notify compliance**, so a post-update variant would *revert* an agent's forced transfer
  that pushes the recipient over the cap. On T-REX ≤ 4.1, where `recoveryAddress` routes through
  `forcedTransfer`, that **bricks wallet recovery** whenever the destination wallet already holds tokens.
- On the vendored 4.2.0-beta1 `recoveryAddress` notifies **nobody**, so a recovered wallet can silently sit above
  the cap. A token-reading rule self-heals — further receipts are blocked — but the invariant is violated in
  state with no event from the rule.

T-REX's own module library also already ships a `MaxBalanceModule`, so the marginal value is lowest of the three.
`RuleMaxBalance` is therefore documented as CMTAT-path-only until the forced-transfer exemption question is
settled.

### NM-14 / NM-22 — A reverting identity registry or sanctions oracle reverts the read path

**Claim (Low ×2).** `setIdentityRegistry` accepts any non-zero address without verifying `isVerified(address)` is
callable, and `RuleSanctionsListBase` calls `oracle.isSanctioned(...)` with no failure handling. A registry or
oracle that reverts, is codeless, or returns malformed data makes `detectTransferRestriction` / `canTransfer` —
which the project documents as never-reverting — revert, and halts every transfer, mint and burn on the bound
token.

**Verdict — accepted as design; already catalogued and dismissed in the v0.4.0 audit.** The code is as described
(`RuleIdentityRegistryBase.sol:101-105`, `:213`; `RuleSanctionsListBase.sol:161-167`, `:191`), and
`CLAUDE_AUDIT.md`'s "observations considered and dismissed" table carries the row verbatim: *"Reverting sanctions
oracle / identity registry bricks transfers — trusted external dependency; a revert bubbles up with no state
corruption."* Failure is **closed** (nothing is admitted), the state is intact, and recovery is a single
privileged `setSanctionListOracle` / `clearSanctionListOracle` / `setIdentityRegistry` call.

Fair caveat the scanner earns: the library's "the ERC-1404 views MUST NOT revert" invariant is enforced for the
*supply*, *balance* and *PoR feed* reads (guarded by `try/catch` plus configuration probes) but **not** for these
two. Closing the gap means choosing a fail direction for an unreadable list and minting new restriction codes for
"registry unavailable" / "oracle unavailable" — a deliberate, breaking addition to the code ranges. Recorded as an
open, intentional asymmetry rather than a silent one.

### NM-17 — `approveAndTransferIfAllowed` can leave a residual approval

**Claim (Low).** The helper records the approval *before* `safeTransferFrom` so the callback can consume it, and
never verifies afterwards that it was consumed. If the token does not call back — a plain ERC-20 bound for the
helper, or an engine never bound / since unbound — the transfer succeeds and the approval count stays
incremented, authorising one later unapproved transfer of the same `(from, to, value)`.

**Verdict — accepted as design; the inversion is deliberate, documented, and previously triaged.** Verified at
`RuleConditionalTransferLightBase.sol:113-129`; the NatSpec states both halves ("This function is only safe for
tokens that call back `transferred()` during transfer" and "CEI is intentionally inverted so the approval exists
for the callback"), and `CLAUDE_AUDIT.md` dismisses the CEI inversion as "deliberate and documented; the rule
custodies no value, and reentrancy could at most consume approvals the operator already granted for the same
tuple". Reaching the residual state requires the operator to run the helper against a binding they configured
incorrectly, and the leftover is visible via `approvedCount` and clearable via `resetApproval` /
`cancelTransferApproval`.

**Improvement — implementable, ~5 lines plus one error, in both variants.** The helper cannot check the callback
*happened*, but it can check the only thing that matters: that the approval it created was consumed. Snapshot the
count, and require it back afterwards.

```solidity
// RuleConditionalTransferLightBase.approveAndTransferIfAllowed
function approveAndTransferIfAllowed(address from, address to, uint256 value)
    public virtual onlyTransferApprover returns (bool)
{
    address token = getTokenBound();
    require(token != address(0), RuleConditionalTransferLight_TokenNotBound());

    uint256 approvalsBefore = approvedCount(from, to, value);
    approveTransfer(from, to, value);

    uint256 allowed = IERC20(token).allowance(from, address(this));
    require(allowed >= value, RuleConditionalTransferLight_InsufficientAllowance(token, from, allowed, value));

    IERC20(token).safeTransferFrom(from, to, value);

    // The approval above exists ONLY for the token's compliance callback to consume. If the count did
    // not come back down, no callback reached this rule -- the binding is wrong -- and leaving the
    // surplus would authorise a later, never-approved transfer of the same tuple.
    require(
        approvedCount(from, to, value) == approvalsBefore,
        RuleConditionalTransferLight_ApprovalNotConsumed(token, from, to, value)
    );
    return true;
}
```

with one addition to `RuleConditionalTransferLightInvariantStorage`:

```solidity
error RuleConditionalTransferLight_ApprovalNotConsumed(address token, address from, address to, uint256 value);
```

The multi-token variant needs the identical change in `RuleConditionalTransferLightMultiTokenBase`
(`:131`), using its token-keyed accessor `approvedCount(token, from, to, value)` (`:216`) and its own error
namespace.

Correctness of the post-condition:

- **Holds in both supported topologies.** `_transferred` decrements by exactly one and returns early only when an
  endpoint is `address(0)` — impossible here, since `safeTransferFrom` would have reverted on a zero `from` and
  the helper is not a mint/burn path. Direct binding: the token calls `transferred`. Engine binding: the engine
  relays it. Either way the count returns to `approvalsBefore`.
- **Fires exactly where the finding is.** A plain ERC-20 bound with `bindToken` but no callback, or an engine
  never bound / since unbound, now reverts the whole call — including the ERC-20 transfer — instead of completing
  it and leaving a spendable approval behind. That is a behaviour change worth calling out in the release notes:
  a deployment relying on the helper against a non-callback token stops working, which is the point.
- **Reentrancy-safe by construction.** It reads state *after* the external call, so a hostile token can only make
  the check fail, never pass spuriously. Any path that consumed more than one approval also fails, which is the
  desired direction.
- **Cost:** two warm `SLOAD`s (~200 gas) on an operator-only path.

Tests: extend the existing conditional-transfer suites with (a) a plain ERC-20 mock that does not call back —
assert the revert and that `approvedCount` is unchanged from before the call, and (b) a regression that the
normal direct-binding and engine-binding flows still succeed with the count back at its starting value.

Recommended: it converts a silent, operator-created compliance hole into an immediate, named failure at the exact
moment the misconfiguration is exercised.

### NM-18 — The wrapper can be bricked by a non-`IAddressList` child

**Claim (Low).** `RuleWhitelistWrapperBase._detectTransferRestrictionForTargets` casts every child to
`IAddressList` without checking. A rules manager can add a valid `IRule` that is not an address list (e.g.
`RuleMaxTotalSupply`); once it sits before a later whitelist child, any check that has not already resolved every
target reverts on the blind `areAddressesListed` call — read path *and* `transferred`.

**Verdict — informational; confirmed, and a known open item.** The unchecked cast is at
`RuleWhitelistWrapperBase.sol:237`, and `CLAUDE.md` lists it as a standing gotcha ("`RuleWhitelistWrapper` does
not ERC-165-check its child rules… a non-`IAddressList` child bricks the scan"). It is the still-open half of
v0.4.0 audit **F-5**, recorded there as "partially fixed — `IAddressList` now advertised; the wrapper guard
remains open". The scanner's detail about the short-circuit is accurate and matches the documented behaviour of
`_detectTransferRestrictionForTargets` (early exit once every target resolves), which is exactly why the failure
is *order-dependent* and can appear only for some address pairs.

**Improvement — implementable now; two complementary layers, and only the first is cheap.**

*Layer 1 — reject at configuration (recommended).* Override `_checkRule`, **not** `addRule`: it is
`internal view virtual` and both public entrypoints route through it (`addRule` → `_addRule` → `_checkRule`, and
`setRules` → `_addRule` → `_checkRule`), so one override covers every path and stays `view`. **`RuleEngineBase`
already does exactly this** for its own children (`RuleEngineBase.sol:228-233`), so the pattern is established
in the dependency the wrapper inherits from:

```solidity
// RuleWhitelistWrapperBase -- mirrors RuleEngineBase._checkRule
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

function _checkRule(address rule_) internal view virtual override {
    RulesManagementModule._checkRule(rule_); // zero-address and duplicate checks
    require(
        ERC165Checker.supportsInterface(rule_, AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID),
        RuleWhitelistWrapper_ChildIsNotAnAddressList(rule_)
    );
}
```

`ERC165Checker.supportsInterface` is itself non-reverting — it uses a bounded, gas-capped `staticcall` and
returns `false` for a codeless address, a missing selector or malformed return data — so a hostile candidate
cannot brick the setter it is being screened by. The four intended children already advertise the ID
(`0x5d10e182`): verified on `RuleWhitelistBase:62`, `RuleReceiverWhitelistBase:95`, `RuleSpenderWhitelistBase:79`
and `RuleBlacklistBase:100`, so no legitimate configuration is rejected.

What layer 1 buys and what it misses:

- ✅ Closes **NM-18** — the `RuleMaxTotalSupply`-as-child case is rejected at `addRule` instead of bricking
  transfers later.
- ✅ Closes **NM-19**'s failure mode — a nested wrapper is refused up front with a named error rather than
  bricking every transfer through the parent. It does not *enable* nesting: that needs the wrapper to implement
  and advertise `IAddressList`, which is NM-19's separate enhancement.
- ❌ Does **not** close **NM-20** — `RuleBlacklist` advertises the same interface ID, because `IAddressList`
  expresses *membership*, not *polarity*. Detecting that needs a separate marker interface (e.g. an `IAllowList`
  advertised only by the whitelist rules) or documentation; see NM-20.
- ❌ Does not help a child that is valid at add time and breaks later. EIP-6780 means a deployed child cannot
  become codeless, but a child behind a proxy can still be upgraded into something that reverts.

*Layer 2 — contain at read time (optional, and genuinely harder than it looks).* To stop an already-installed bad
child from reverting the MUST-NOT-revert views, the blind call at `:237` would have to tolerate failure and treat
the child as listing nobody — which is fail-closed for an OR-composition of whitelists. The obstacle is that
`areAddressesListed` returns a **dynamic `bool[]`**, and `abi.decode` of malformed return data reverts *in this
frame*, outside any `catch` — the same uncatchable-decode problem documented in `TokenSupplyReader` and raised by
NM-23. The workable technique is to push the decode into a callee frame so the failure becomes catchable:

```solidity
function decodeListed(bytes calldata data, uint256 n) external pure returns (bool[] memory listed) {
    listed = abi.decode(data, (bool[]));
    require(listed.length == n, ...);
}

// in the scan loop
(bool ok, bytes memory data) = rule(i).staticcall(
    abi.encodeCall(IAddressList.areAddressesListed, (targetAddress))
);
bool[] memory isListed = new bool[](targetsLength); // default: lists nobody
if (ok) {
    try this.decodeListed(data, targetsLength) returns (bool[] memory decoded) { isListed = decoded; }
    catch { /* keep the all-false default */ }
}
```

This adds a public helper to the ABI, an external self-call per child per check, and a silent-degradation path
where a broken child stops contributing without any signal. That is a real cost against a scenario layer 1
already prevents at configuration, so **layer 1 alone is the recommendation**; layer 2 only earns its place if
the wrapper is ever expected to hold children it does not control.

*Why it has stayed open.* `RulesManagementModule._checkRule`, which the wrapper inherits directly, tests only
non-zero and duplicate — but `RuleEngineBase` overrides it to add the `IRule` ERC-165 check, so the engine is
guarded and the wrapper is not. The wrapper is in fact the *more* demanding of the two: the engine calls children
through `IRule`, which every rule implements, while the wrapper calls them through `IAddressList`, which most do
not. Nothing about the dependency argues against the guard; it supplies the template. Ship it with the F-5
remediation, or on its own.

### NM-19 — The wrapper does not implement `IAddressList`, so wrappers cannot nest

**Claim (Low).** `RuleWhitelistWrapperBase` implements `IIdentityRegistryVerified` but omits `areAddressesListed`
/ `isAddressListed`. A wrapper therefore cannot be a child of another wrapper: the parent's blind
`areAddressesListed` STATICCALL hits a missing selector with no fallback and reverts every transfer.

**Verdict — informational; confirmed, an enhancement rather than a defect.** Verified: neither
`RuleWhitelistWrapperBase` nor `RuleWhitelistShared` declares `areAddressesListed` or `isAddressListed`, and
neither advertises `IADDRESS_LIST_INTERFACE_ID`. Nesting has never been documented as supported, so nothing
regresses; the failure mode is the same one as NM-18 and would be surfaced by the same ERC-165 guard rather than
silently bricking. The scanner is right that the internals already exist —
`_isListedInAnyChild` / `_detectTransferRestrictionForTargets` — so exposing `IAddressList` on the wrapper would
be a handful of lines and would make hierarchical OR-composition work. Recorded as a feature request for a
future release; not required for `v0.5.0`.

### NM-20 — The wrapper reads a `RuleBlacklist` child's membership as eligibility

**Claim (Low).** The wrapper ORs raw `areAddressesListed` answers and treats `true` as eligible. `RuleBlacklist`
is a valid `IRule` exposing the same interface with the *opposite* polarity, so adding one as a child makes
blacklisted addresses whitelisted, and `isVerified` returns `true` for them.

**Verdict — informational; confirmed, a trusted-role misconfiguration.** The polarity inversion is real — the
wrapper cannot distinguish an allow-list from a deny-list through `IAddressList`, and nothing in `addRule`
constrains child semantics. It requires the rules manager to add a blacklist to a *whitelist* wrapper, which is a
category error rather than an attack: the same role can already remove every whitelist child outright. Related to
the accepted v0.4.0 row "wrapper cross-rule OR (`from` in child A, `to` in child B) — documented design; the
wrapper's stated semantics are 'listed in **any** child'". Worth one explicit sentence in
`doc/technical/contracts/RuleWhitelistWrapper.md`: *children must be allow-lists; adding a deny-list rule inverts
its meaning.* Folded into the documentation pass alongside NM-11.

### NM-21 — `RuleMintAllowance` pre-flight views fail open

**Claim (Low).** `detectTransferRestriction` and `canTransfer` are hardcoded to "allowed" while enforcement
happens on the 4-arg path, so a token-level pre-flight reports success for a zero-quota minter and the mint then
reverts.

**Verdict — accepted as design; this is v0.4.0 audit finding F-7, closed as documented.** Verified at
`RuleMintAllowanceBase.sol:200-208` and `:227-235`. The 3-arg signature has no minter identity, so a truthful
answer is impossible; returning `TRANSFER_OK` and directing callers to the authoritative view is the documented
resolution. It is stated in the contract NatSpec ("use `detectTransferRestrictionFrom(minter, address(0), to,
amount)` to query allowance"), in `CLAUDE.md` ("`canTransfer` is **not** authoritative for this rule — use
`canTransferFrom(minter, address(0), to, value)`"), in `RULE_SEMANTICS.md` §2, and in the audit's disposition
table.

### NM-23 / NM-24 — Short successful return data escapes `try/catch`

**Claim (Low ×2).** `BalanceCapManager._balanceOf`, `TokenSupplyReader._currentSupply` and
`ChainlinkPoRFeedManager._maxBackedSupply` use high-level typed calls in `try/catch`. If a code-bearing
dependency later returns fewer bytes than the declared return type — e.g. after a proxy implementation change —
ABI decoding fails in the *caller's* frame, outside `catch`, so the read path reverts instead of returning codes
83 / 51 / 78 / 79.

**Verdict — accepted as design; correct Solidity semantics, already documented in the same files.** The claim is
right about the language: a `try` does not catch a decode failure of the return data. It is also already written
down at `TokenSupplyReader.sol:58-61`: *"A `try` call to a codeless address reverts uncatchably — the ABI decoder
fails in the caller's frame, outside `catch`'s reach — and this probe cannot contain it. **Note code alone is not
sufficient either: a contract that returns 0 bytes fails the same way.**"* The same reasoning appears in
`BalanceCapManager` and `ChainlinkPoRFeedManager`.

Reaching it requires a dependency that **passed** the configuration probe (`_probeTotalSupplyCallable`,
`balanceOf`, `decimals`) and later changed behaviour — the proxy-upgrade case, the same precondition already
documented for the code-length guards. Failure is closed and the state is intact.

**Improvement — fully implementable, and it retires a documented deployment precondition as a bonus.** Replace
the typed `try/catch` with a low-level `staticcall` plus an explicit length check, so decoding only happens on
data that is known to be long enough.

```solidity
// TokenSupplyReader
function _currentSupply() internal view virtual returns (bool available, uint256 supply) {
    (bool ok, bytes memory data) =
        address(_supplyToken()).staticcall(abi.encodeCall(ITotalSupply.totalSupply, ()));
    if (!ok || data.length < 32) {
        return (false, 0);
    }
    return (true, abi.decode(data, (uint256)));
}

// BalanceCapManager
function _balanceOf(address account) internal view virtual returns (bool available, uint256 balance) {
    (bool ok, bytes memory data) =
        address(balanceToken).staticcall(abi.encodeCall(IBalanceOf.balanceOf, (account)));
    if (!ok || data.length < 32) {
        return (false, 0);
    }
    return (true, abi.decode(data, (uint256)));
}
```

The same shape applies to `ChainlinkPoRFeedManager._maxBackedSupply`'s two feed reads: `decimals()` needs
`data.length >= 32` (a `uint8` is ABI-encoded as a full word), `latestRoundData()` needs `>= 160` for its five
return values. `_probeTotalSupplyCallable` should be converted too, or configuration would accept a token the
read path then rejects.

What this buys, beyond the finding itself:

- **A `staticcall` to a codeless address returns `ok == true` with empty data**, which the length check catches.
  That makes the read path safe without any code-length guarantee — so the **"assumes a Cancun-or-later chain"
  deployment precondition documented in `TokenSupplyReader`, `BalanceCapManager` and `ChainlinkPoRFeedManager`
  can be dropped**, and with it the reasoning about EIP-6780 that three contracts currently carry. That is a
  meaningful simplification of the invariant surface, not just a bug guard.
- Failure stays closed and keeps returning the documented codes (51 / 78 / 79 / 83) instead of reverting.
- Gas is a wash: `staticcall` + `abi.decode` costs about the same as the compiler's own `try` sequence.

Costs, stated honestly:

- **Loses the typed call.** `abi.encodeCall` keeps argument type-checking against the interface, but the return
  type is asserted by the `abi.decode`, not by the compiler — a signature change in `ITotalSupply` would no
  longer be caught at the call site. Keep the interfaces as the single source of truth and use `abi.encodeCall`
  (never a hand-written `abi.encodeWithSignature`) so the selector cannot drift.
- **Touches four files on the enforcement path of every cap rule**, so it needs the existing suites plus new
  cases: a mock returning 0 bytes, one returning 31 bytes, one reverting, and a codeless address (which should
  now yield the unavailable code rather than reverting — the assertion that pins the retired precondition).
- The three long `@dev` blocks explaining the uncatchable decode would have to be rewritten, not deleted: they
  become the explanation of *why* the reads are low-level.

Recommendation: worth doing, but as a deliberate change with its own review, not folded into an unrelated commit
— it rewrites the read path of every cap rule and the reason those contracts give for their own safety.

---

## Delta from previous analyses

This is the **first** Nethermind AuditAgent scan of this repository, so there is no previous AuditAgent run to
diff. Against the other `v0.5.0` analyses:

| Source | New findings this scan added | Overlap |
|---|---|---|
| Slither 0.11.5 / Aderyn 0.6.5 (`v0.5.0`) | All 24 — no pattern-based detector reached any of them | None |
| `CLAUDE_AUDIT.md` (`v0.4.0`) | NM-3, NM-6, NM-10, NM-11, NM-19, NM-20, NM-23/24 | NM-7/12/15 ≈ F-4; NM-21 ≈ F-7; NM-18 ≈ F-5; NM-14/22 = accepted-risk rows |
| `CLAUDE_ANALYSIS_MAXBALANCE.md` (`v0.5.0`) | NM-11's ERC-3643 consequence | NM-11's premise = H-1 (pre-update accounting) |

The scan reached a strictly different class of issue than the static analysers, which is the point of running
both: Slither and Aderyn match syntactic patterns, and every finding here is semantic — about who calls a hook,
in what order, and with which arguments.

## Executive triage

**Nothing found by this scan is exploitable, and none of the 13 Medium ratings survives verification at Medium.**
There is no path to unauthorised issuance, no way to move tokens past a rule, and no state corruption. The
failures the report describes are, without exception, either **fail-closed** (an over-restrictive cap, a
transfer blocked by a broken oracle) or **inert** (a rule that cannot screen an identity it is never given).

Every one of the 24 findings describes real code — there are no false positives — but 17 restate positions the
project had already reached and written down, and the 24 items collapse to about 11 distinct claims.

**One item is recommended for action: NM-11.** `RuleMaxBalance`, `RuleMaxTotalSupply` and `RuleChainlinkPoR`
assume the token calls the compliance hook *before* moving value; the vendored ERC-3643 / T-REX token calls it
*after*, and that integration is one this repository supports and tests. The consequence is over-restriction, not
over-issuance. **It has since been fixed** for the two supply-based cap rules, which now ship ERC-3643 variants
(`RuleChainlinkPoRERC3643`, `RuleMaxTotalSupplyERC3643`) verified against the genuine vendored T-REX token;
`RuleMaxBalance` is deliberately left as CMTAT-path-only, because a post-update variant would revert an agent's
forced transfer and, on T-REX <= 4.1, brick wallet recovery — a policy decision rather than a hook override.

**Eight improvements are specified**, each with its code, its cost and its limit. Four are done; the other four
are listed in rough order of value per unit of risk:

| Improvement | Where | Size | Status / verdict |
|---|---|---|---|
| ERC-3643 cap-rule variants (`CapAccounting` + the notify seam) | NM-11 | 2 rules × 2 variants | ✅ **Done in `v0.6.0`** — 49 tests, incl. suites against the genuine T-REX token; `RuleMaxBalance` deliberately excluded |
| Delegate instead of returning early | NM-3 | ~4 lines | ✅ **Done in `v0.6.0`** — behaviour-preserving, 8 regression tests, mutation-verified |
| Future-dated PoR answer → code 77 | NM-10 | 1 line | ✅ **Done in `v0.6.0`** — 5 regression tests, mutation-verified |
| Approval post-condition in `approveAndTransferIfAllowed` | NM-17 | ~5 lines + 1 error, ×2 variants | **Do it** — turns a silent operator-created hole into a named revert |
| ERC-165 guard on wrapper children | NM-18 | `_checkRule` override | **Do it** — the pattern already exists in `RuleEngineBase` |
| Normalise `spender == from` on the ERC-7943 overloads | NM-6 | 1 helper + 3 branches | ✅ **Done in `v0.6.0`** — 1 file, corrects one rule, changes no deny-list outcome |
| `staticcall` + length check on the cap reads | NM-23/24 | 4 files | Worth it, as its own reviewed change — also retires the Cancun precondition |
| Opt-in caller binding on the cap rules | NM-5 | 1 slot + setter, ×3 | **Partial only** — cannot isolate two tokens behind one engine; document and monitor instead for now |

**No contract was modified by this triage.** Any fix goes through the normal fix workflow, after which
`update-feedback-audit` maps the commits back into this file.
