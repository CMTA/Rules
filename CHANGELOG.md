# CHANGELOG

Please follow [https://changelog.md/](https://changelog.md/) conventions.

## Semantic Version 2.0.0

Given a version number MAJOR.MINOR.PATCH, increment the:

1. MAJOR version when the new version makes:
   -  Incompatible proxy **storage** change internally or through the upgrade of an external library (OpenZeppelin)
   -  A significant change in external APIs (public/external functions) or in the internal architecture
2. MINOR version when the new version adds functionality in a backward compatible manner
3. PATCH version when the new version makes backward compatible bug fixes

See [https://semver.org](https://semver.org)

## Type of changes

- `Added` for new features.
- `Changed` for changes in existing functionality.
- `Deprecated` for soon-to-be removed features.
- `Removed` for now removed features.
- `Fixed` for any bug fixes.
- `Security` in case of vulnerabilities.

Reference: [keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/)

Custom changelog tag: `Dependencies`, `Documentation`, `Testing`

## Checklist

> Before a new release, perform the following tasks

- Code: Update the version name, variable VERSION
- Run formatter and linter

> forge fmt
> forge lint

- Documentation
  - Perform a code coverage and update the files in the corresponding directory [./doc/coverage](./doc/coverage)
  - Perform an audit with several audit tools (Mythril and Slither), update the report in the corresponding directory [./doc/security/audits/tools](./doc/security/audits/tools)
  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script)
  - Update changelog



## Unreleased — v0.6.0

### Fixed

- **NM-3 (Nethermind AuditAgent)** — `RuleIdentityRegistryBase._detectTransferRestrictionFrom` returned
  `TRANSFER_OK` outright when the identity registry was unset or the transfer was a burn, instead of delegating
  to `_detectTransferRestriction`. A subclass extending only that hook — the natural place to add a check —
  therefore applied to `transfer` but silently **not** to `transferFrom` or `burnFrom`. The guard now delegates,
  so the two entrypoints can no longer disagree. This is the same anti-pattern `RuleSanctionsListBase` was
  restructured to remove (`CLAUDE_ANALYSIS.md` F-2); the two sibling rules are now consistent.
  **Behaviour-preserving**: both early returns duplicated guards the delegate already performs, and the 21
  pre-existing `RuleIdentityRegistry` tests pass unmodified. Burn remains exempt from the opt-in `checkSpender`
  check.
- **NM-10 (Nethermind AuditAgent)** — `ChainlinkPoRFeedManager._maxBackedSupply` flagged a Proof-of-Reserve feed
  as stale only when `block.timestamp > updatedAt`. That term was an underflow guard, and its side effect was
  that **any** future-dated round counted as fresh: a feed frozen on an old reserve answer but stamped ahead of
  the block could keep authorising mints until that timestamp elapsed. A future `updatedAt` is now treated as a
  **malformed answer** (`CODE_RESERVES_ANSWER_INVALID`, 77) alongside a negative reserve and an incomplete round,
  and is rejected **regardless of `maxStalenessSeconds`** — zero disables *freshness* checking, and an operator
  who opts out of that must not thereby accept a timestamp no aggregator on this chain could have written. The
  now-redundant underflow guard was dropped from the staleness comparison.

- **NM-6 (Nethermind AuditAgent)** — `RuleNFTAdapter`'s ERC-7943 spender-aware overloads
  (`transferred`, `detectTransferRestrictionFrom`, `canTransferFrom`) called the delegated hook
  unconditionally, while the two `ITransferContext` entrypoints normalised `sender == from` to the direct hook.
  The two surfaces therefore gave different compliance answers for the same owner-initiated transfer. The three
  interfaces signal a direct transfer differently — ERC-7943 documents its `spender` as "the address performing
  the transfer (**owner**/operator)" and `ctx.sender` is the token's `msg.sender`, so on both an owner arrives as
  `spender == from`, whereas the CMTAT path uses the 3-arg overload or `spender == address(0)`. The adapter now
  routes every entrypoint through a shared `_isDelegated(spender, from)` predicate. **The 4-arg CMTAT path is
  deliberately left unchanged**, since its own convention already distinguishes the two cases — so the primary
  integration path, and every restriction code an existing integrator sees, are untouched.
  The one behavioural correction is `RuleSpenderWhitelist`: an owner-initiated ERC-721 `transferFrom` was
  rejected with code `66` despite the rule documenting that direct transfers are always allowed. The deny-list
  rules blocked such a transfer before and after; only which leg reported it changed.

### Added

- **`RuleMaxTotalSupplyERC3643` / `RuleMaxTotalSupplyERC3643Ownable2Step`** — static supply caps for
  **ERC-3643 tokens**, the same re-phasing as the Proof-of-Reserve variants below and for the same reason: the
  token mints first and reports through `created` afterwards, which `RuleEngine` forwards as the three-argument
  `transferred(address(0), to, value)`, so `totalSupply()` already includes the new tokens. Cap logic,
  restriction codes (50, 51), configuration, roles and events are inherited unchanged, and the read views are
  deliberately not re-phased. **Not interchangeable with the stock rule, and neither mistake reverts at
  deployment.** Designed to compose with `RuleChainlinkPoRERC3643`, which has no margin parameter: add both to
  one engine for a static ceiling alongside the reserve-backed one, remembering the engine reports the first
  non-zero code.

- **`RuleChainlinkPoRERC3643` / `RuleChainlinkPoRERC3643Ownable2Step`** — Proof-of-Reserve minting caps for
  **ERC-3643 tokens**, the first consumers of the seam above. ERC-3643 / T-REX calls compliance *after* it has
  moved the value: `mint` runs `_mint(_to, _amount)` and only then `_tokenCompliance.created(_to, _amount)`, which
  `RuleEngine` forwards to each rule as the three-argument `transferred(address(0), to, value)`. `totalSupply()`
  therefore already includes the new tokens, so the variant overrides `_detectTransferRestrictionOnNotify` to
  re-ask with nothing left to add. Reserve logic, restriction codes (75–79), configuration, roles and events are
  inherited unchanged. **The read views are deliberately not re-phased** — ERC-3643 calls
  `canTransfer(address(0), to, amount)` *before* `_mint`, so a pre-flight query must still project the amount;
  the two consultations then reduce to the same condition. **The variants are not interchangeable with the stock
  rule and neither mistake reverts at deployment**: the stock rule on ERC-3643 counts the amount twice and
  reverts fully backed mints, and the variant on CMTAT weakens enforcement.

- **`CapAccounting`** (`src/rules/validation/abstract/core/CapAccounting.sol`) — the cap comparison that
  `RuleMaxBalance`, `RuleMaxTotalSupply` and `RuleChainlinkPoR` each wrote out separately, now in one place.
  Stateless and constructor-free, so storage layouts are unchanged (verified byte-identical for all six
  deployables) and an upgradeable variant may adopt it. It deliberately carries no notion of pre- or post-update
  accounting: whether the observation already includes the moved value depends on which *path* is running, not on
  the rule.
- **`_detectTransferRestrictionOnNotify`** on all three cap rules — the seam an ERC-3643 variant overrides. The
  write hooks now route through it; it defaults to the pre-flight check, which is the CMTAT behaviour, so nothing
  changes by default. A token that notifies *after* moving the value (ERC-3643 / T-REX) needs one override:
  `return _detectTransferRestriction(from, to, 0)`. The read path is deliberately not routed through it — a
  pre-flight view always runs before the movement, so it must always project the value.
- Documented the second seam, **observation source** (`_currentSupply` / `_balanceOf`, both already
  `internal view virtual`), which lets a rule serve the figure from its own storage instead of calling the token.
  A rule that keeps its own running total controls when it updates it and so is immune to the accounting-phase
  question entirely.

- **NM-18 (Nethermind AuditAgent) / audit F-5** — `RuleWhitelistWrapper` now ERC-165-checks its child rules.
  `_checkRule` is overridden exactly as `RuleEngineBase` does it, so one override covers both `addRule` and
  `setRules`; a candidate that does not advertise the required interface is rejected with
  `RuleWhitelistWrapper_ChildIsNotAnAddressList(rule)`. Previously a valid `IRule` that was not an address list
  was accepted and then reverted the blind `areAddressesListed` call during a transfer — and the early exit in
  the child scan made that *input-dependent*, so the wrapper looked healthy until a pair needed the full scan.
  A nested wrapper is now refused for the same reason.
- **A purpose-built sub-interface, `IAddressListBatchQuery`**, split out of `IAddressList`. The wrapper calls
  exactly one of `IAddressList`'s eight functions, so the guard requires
  `IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID` (`0x20e8e17a`, the single `areAddressesListed(address[])` selector)
  rather than the full `IADDRESS_LIST_INTERFACE_ID` — demanding the other seven, four of them **writes**, would
  reject a read-only child that works perfectly. Factoring the selector into a parent left the flattened selector
  set unchanged, so `0x5d10e182` keeps its value; the four address-list rules advertise both ids. Unlike the full
  id, the sub-interface id is safe as a literal, because it inherits nothing and so has no omitted-parent trap.
  **The guard still cannot check polarity** — a `RuleBlacklist` advertises the same ids and passes it (NM-20).

- **NM-17 (Nethermind AuditAgent)** — `approveAndTransferIfAllowed` now asserts that the approval it created was
  consumed. Both variants invert checks-effects-interactions deliberately, recording the approval *before*
  `safeTransferFrom` so the token's compliance callback can consume it; nothing verified the callback arrived. A
  plain ERC-20 bound with `bindToken`, or a RuleEngine never bound or since unbound, therefore completed the
  transfer and left the approval standing — indistinguishable from an operator-created one, and enough to
  authorise a later never-approved transfer of exactly `(from, to, value)`. The helper now reverts with
  `RuleConditionalTransferLight_ApprovalNotConsumed` /
  `RuleConditionalTransferLightMultiToken_ApprovalNotConsumed`.
  **Behaviour change**: a deployment running the helper against a non-callback token now reverts instead of
  completing — that is the fix, not a side effect. The comparison is against the count *before* the helper ran,
  so an operator's own outstanding approvals for the same tuple survive; and the count is read *after* the
  external call on purpose, so a hostile token can only make the check fail, never pass. Cost: two warm `SLOAD`s
  on an operator-only path.

- **NM-20 (Nethermind AuditAgent)** — `RuleWhitelistWrapper` now **rejects** a child whose list has the wrong
  polarity, rather than only documenting the hazard. `IAddressList` describes *membership*, so a `RuleBlacklist`
  implements it identically to a whitelist and advertises the same ids; ERC-165 alone could not separate them,
  and adding one made its blacklisted addresses whitelisted with `isVerified` returning `true` for them.
  A new one-function marker interface **`IAddressListPolarity`** (`isAllowList()`, id `0xdc4efe10`) makes the
  distinction expressible, and `_checkRule` now requires it *and* a `true` answer on top of the
  `IAddressListBatchQuery` check. New errors: `RuleWhitelistWrapper_ChildDoesNotDeclarePolarity` and
  `RuleWhitelistWrapper_ChildIsNotAnAllowList`.
  **Absence of the declaration is a refusal, never an assumed allow-list** — the only fail-closed reading.
  `RuleWhitelist` / `RuleReceiverWhitelist` declare `true`, `RuleBlacklist` declares `false`, and
  **`RuleSpenderWhitelist` deliberately declines the interface** (documented in its NatSpec as a
  must-not-change): its set is permitted *spenders*, not *holders*, so an honest `true` would still let the
  wrapper read spenders as eligible participants. That closes a second wrong-child class with the same
  mechanism, one that had previously been prose only.

### Testing

- Added `IdentityRegistryExtraCheckHarness` (`src/mocks/harness/IdentityRegistryDelegationHarness.sol`) — a
  subclass overriding only `_detectTransferRestriction`, mirroring `SanctionsListDelegationHarness` — and
  `test/RuleIdentityRegistry/RuleIdentityRegistryDelegation.t.sol` (8 tests) pinning NM-3. Reverting the source
  change fails 3 of the 8 with exactly the predicted symptoms. Coverage on `RuleIdentityRegistryBase`: 100%
  statements, 100% branches.
- Added 5 tests to `test/RuleChainlinkPoR/RuleChainlinkPoRUnit.t.sol` pinning NM-10: a future-dated round yields
  code 77 from the views and reverts the mint through the write hook; it is still rejected with
  `maxStalenessSeconds == 0` (the test that pins the design decision); and `updatedAt == block.timestamp` still
  passes, guarding against over-correcting into `>=`. Reverting the source change fails 4 of the 5. Coverage on
  `ChainlinkPoRFeedManager`: 100% statements, 100% branches.

- Extended `test/TransferContext/OverloadParity.t.sol` for NM-6. The suite already existed to assert overload
  parity but only ever exercised two of the three input shapes (`sender == 0`, `sender != from`), which is why
  the gap survived. Added `_assertSelfSpenderIsDirect` — run for every rule on an allowed and a blocked pair —
  plus `test_NM6_SelfSpenderIsNotScreenedByTheSpenderWhitelist` and
  `test_NM6_CmtatFourArgPathKeepsScreeningASelfSpender`, the latter pinning the deliberate asymmetry so it is not
  "aligned" away later. Reverting the fix fails 6 of the suite's 10 tests across 5 rules. The suite's header
  comment, which described the parity as flat, now states the per-interface conventions. Coverage on
  `RuleNFTAdapter`: 100% statements, 100% branches.

- Added 5 tests for NM-17 across `RuleConditionalTransferLightApproveAndTransfer.t.sol` and
  `RuleConditionalTransferLightMultiToken.t.sol`. `MockERC20WithTransferContext` is a no-op notifier when no rule
  is set, so leaving `setRule` uncalled gives a token that moves value and tells nobody — the finding's exact
  shape, with no new mock. Removing the two post-conditions makes both silent-token tests fail and nothing else.
  Worth recording: the pre-existing 871 tests all passed unchanged when the post-condition landed, because every
  one of them uses a token that *does* call back — which is how the non-callback path came to have no coverage.

- The WW-2 threat-model PoC did what its convention promises: named `..._CurrentBehaviour` because it asserted
  the broken behaviour, it **failed** when NM-18 was fixed. Renamed
  `test_WW2_NonAddressListChildRuleIsRejectedAtAddRule` and rewritten to assert the rejection, plus two new tests
  beside it — a nested wrapper is refused, and `test_WW2_GuardCannotRejectAnInvertedPolarityChild_CurrentBehaviour`
  pins the guard's limit against NM-20. Four assertions added to `test/InterfaceId/AddressListInterfaceId.t.sol`
  for the sub-interface id and its advertisement. `RuleWhitelistWrapperBase`: 100% statements, branches,
  functions.

- Added `test/ERC3643Real/ERC3643RealTokenMaxTotalSupply.t.sol` (10 tests, `FOUNDRY_PROFILE=erc3643`) and
  `test/RuleMaxTotalSupply/RuleMaxTotalSupplyERC3643.t.sol` (10 tests, default profile). The real-token suite
  covers mints to the ceiling, rejection past it, incremental issuance, burns freeing headroom, a raised cap, and
  **both compositions with `RuleChainlinkPoRERC3643`** — static cap binding and reserves binding — plus two tests
  pinning the stock rule's failure on the same token. `test/Version.t.sol` extended to both new deployables.

- Added `test/ERC3643Real/ERC3643RealTokenChainlinkPoR.t.sol` (10 tests, `FOUNDRY_PROFILE=erc3643`) — drives the
  **genuine** vendored `lib/ERC-3643/` token (4.2.0-beta1), not a mock, through `RuleChainlinkPoRERC3643`: mints up
  to the reserves, rejection past them, incremental issuance against a shared ceiling, a raised feed answer
  raising the ceiling, transfers and burns staying open while reserves are zero, and a stale feed halting
  issuance without trapping holders. Two tests pin the **stock** rule's failure on the same real token — a fully
  backed mint reverting, and the largest single mint halving to `reserves / 2` — so the reason the variant exists
  stays executable. `test/Version.t.sol` extended to both new deployables, keeping it exhaustive.

- Added `test/CapAccounting/ERC3643CapSeams.t.sol` (7 tests) and
  `src/mocks/harness/ERC3643CapHarnesses.sol` — a worked ERC-3643 variant of each cap rule plus a tracked-supply
  rule. The tests reproduce NM-11 on the stock rules under post-update accounting, show the one-line override
  fixes it, assert the pre-flight view still projects the value, and confirm neither variant ever admits anything
  above the cap. Coverage after: **100% statements, branches and functions** on `CapAccounting`,
  `RuleMaxBalanceBase`, `RuleMaxTotalSupplyBase` and `RuleChainlinkPoRBase`.

### Documentation

- Added the **Nethermind AuditAgent** (AI automated scan) run for `v0.5.0` — report and per-finding triage in
  `doc/security/audits/tools/v0.5.0/` (Scan ID `10`, commit `01632da`, 0 High / 13 Medium / 11 Low). No false
  positives, nothing exploitable, no contract change required for the CMTAT path; 17 of the 24 findings restate
  positions already documented in the source and in `CLAUDE_AUDIT.md`. One documentation item is outstanding
  (**NM-11**): the balance and supply cap rules assume the token notifies *before* moving the value, which a real
  ERC-3643 / T-REX token does not, so the cap double-counts and over-restricts on that path.
  Seven findings (NM-3, NM-5, NM-6, NM-10, NM-17, NM-18, NM-23/24) carry an `Improvement` section specifying what
  could be implemented, with the code, its cost and its limit — including the two cases where a complete fix is
  not reachable at the rule level. **NM-3, NM-6 and NM-10 are implemented in this release** (see *Fixed* above);
  the other four remain specified but unapplied.
  `AUDIT_OVERVIEW.md`, `README.md` and `doc/README.md` updated with the run, its counts and the AI-tool caveat.

## v0.5.0 - 2026-08-14

Commit: `01632da0ae2cf701323e42644de29cbd951e204c`

### Summary

Four new contracts, one behavioural hardening with a migration note, a reviewed and repaired set of
deployment scripts, the first tests that run against a real ERC-3643 token, and updated dependencies
(CMTAT `v3.3.0-rc3`, RuleEngine `v3.0.0-rc5`, OpenZeppelin `v5.7.0`, solc `0.8.36`).

Every deployable contract reports `version()` → `"0.5.0"`, asserted exhaustively by `test/Version.t.sol`.

**New**
- **`RuleChainlinkPoR`** — caps total supply at the reserves reported by a Chainlink Proof of Reserve feed. Restriction codes `75`–`79`.
- **`RuleReceiverWhitelist`** — screens **only the receiver**, reproducing ERC-3643 eligibility as a CMTAT compliance rule. Restriction code `81`.
- **`IdentityRegistryWhitelist`** — a whitelist that fills an ERC-3643 token's *identity registry* slot, so a token can enforce investor eligibility with no ONCHAINID deployment. Not a rule: it implements no `IRule` and must never be added to a `RuleEngine`.
- **`RuleMaxBalance`** — caps how many tokens a **single address** may hold, with an operator-managed exemption list. Restriction codes `82`, `83`. **Bypassable by splitting a position across wallets**, so it must be paired with a rule admitting one address per investor.

**Deployment scripts.** All four scripts in `script/` were reviewed and fixed; see [`doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_SCRIPT.md`](doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_SCRIPT.md)
for the twelve findings. Three of them (`DeployCMTATWithBlacklist`, `DeployCMTATWithWhitelist`,
`DeployCMTATWithBlacklistAndSanctionsList`) reverted under `forge script` because they read
`address(this)` inside a broadcast, so they could not deploy anything; they now take the deployer as an
explicit parameter. `DeployCMTATWithWhitelist` also deployed with `allowMintBurn = false`, producing a
token that could not be issued at all (mint rejected with code `24` even to a whitelisted investor); it
now allows mint and burn. Shared token metadata moved to the new
`script/base/CMTATDeploymentBase.sol`, which also adds environment-variable configuration (`CMTAT_NAME`,
`CMTAT_SYMBOL`, `SANCTIONS_ORACLE`, `CMTAT_MAX_SUPPLY` and others, all with the previous constants as
defaults) and labelled address logging. The scripts are documented in the new
`doc/technical/guides/DEPLOYMENT_SCRIPTS.md`. CI now runs every script as a local dry run, which is the only
faithful harness: Foundry refuses to combine a prank with a broadcast, so no unit test can exercise
`run()`.

**Breaking behaviour: `RuleMaxTotalSupply`.** The constructor and `setTokenContract` now reject a
non-contract token and probe that `totalSupply()` is callable, and a token that later reverts yields
the new restriction code `51` instead of breaking the MUST-NOT-revert views. Deployments that passed
a placeholder address now fail at construction — see *Changed* for the migration note. This only
rejects configurations that could never have worked, which is why it is a MINOR rather than MAJOR
bump pre-1.0.

**ERC-3643 interoperability.** Both integration directions are now covered end to end: a `RuleEngine`
in the token's *compliance* slot enforcing `RuleWhitelist`, and `IdentityRegistryWhitelist` in the
*identity* slot. One suite runs against the genuine vendored `Token.sol` rather than a mock, which
requires a second Foundry profile — **`forge test` alone no longer runs everything**, see *Testing*.

**Code-quality pass.** A full review of `src/` for duplication, missing events, gas on the storage-read and
loop paths, `virtual` convention drift, and behaviour that is correct but at odds with the library's purpose.
Of twenty-eight findings, **twenty-four were implemented**, two were deliberately declined with the reasoning
recorded (`D-3`, `F-7c`), one is left open (`A-3`), and one needed no change (`A-1`). Three carry
corrections to the review itself: `B-1` and `B-4` overstated their gas saving — `B-1` was wrong for four of its
six sites — and `F-2`'s proposed remedy did not work and was replaced. Every gas figure quoted below was
**measured**, not estimated. Findings, dispositions and the commit for each are in
[`doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS.md`](./doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS.md).
No behavioural change reaches a token holder except where explicitly noted (`RuleSanctionsList` mint/burn
screening, F-1; `transferFrom` delegation, F-2).

### Added

- **`RuleMaxBalance`** — caps how many tokens a **single address** may hold. One cap applies to every holder, with an operator-managed exemption list. Restriction codes `82` (cap exceeded) and `83` (balance unavailable). Available as `RuleMaxBalance` (AccessControl, `MAX_BALANCE_ROLE`) and `RuleMaxBalanceOwnable2Step`.
  - **Screens the receiver only.** A transfer is rejected when `balanceOf(to) + value > maxBalance`. Mints are covered by the same check, since a mint raises a balance like any transfer. Burns are exempt, and the sender is never screened: sending tokens away can only lower a balance. The spender on `transferFrom` is irrelevant — the cap constrains who ends up holding, not who moved the tokens.
  - **⚠️ Bypassable in isolation, by design of what a compliance contract can see.** The cap counts tokens per *address*; an investor with two addresses holds twice the cap and no rule objects. It must be paired with a rule that admits one address per investor (`RuleWhitelist`, `RuleReceiverWhitelist` or `RuleIdentityRegistry`) **and** an onboarding policy of one admitted address per legal entity — a whitelist alone does not close it, since the operator can admit both wallets. The exposure is pinned end to end by `testSplitWalletsBypassTheCapEvenWithAWhitelist`, which shows a combined holding of twice the cap with a whitelist active.
  - **`maxBalance` has no magic value.** `0` forbids holding entirely; it does **not** disable the rule. A sentinel meaning "unlimited" would turn an operator's attempt to freeze holdings into its opposite. To lift the cap use `type(uint256).max` or remove the rule.
  - **Revert-free read path.** `balanceOf` is wrapped in `try/catch`, and a token that breaks after configuration yields code `83` rather than reverting the MUST-NOT-revert views. The token is validated at configuration (non-zero, has code, `balanceOf` callable). Burns and exempt receivers are decided before any balance is read, so they keep working even while the token is unreadable.
  - **Exemptions reuse `RuleAddressSetInternal`**, the same `EnumerableSet` machinery as `RuleWhitelist`, so batch semantics match the library: duplicates skipped and counted, `address(0)` rejected on every add path including batches (invariant I-12).
  - Documented in [`doc/technical/contracts/RuleMaxBalance.md`](./doc/technical/contracts/RuleMaxBalance.md); 55 tests across unit, `Ownable2Step` access control and a CMTAT + RuleEngine end-to-end suite.
- Code-quality review of the new rule in [`doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_MAXBALANCE.md`](./doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_MAXBALANCE.md). Two findings implemented: the exemption writes gained `_addExemptAddress` / `_removeExemptAddress` internals that own the guards and the event, matching the scalar setters; and the rule's dependence on the token notifying compliance **before** it moves value is now documented and pinned by a mutation-verified test (a token notifying afterwards would double-count and silently halve the cap). The check order was measured and deliberately **kept**: reordering saves 2 311 gas per ordinary transfer but costs 9 689 on every transfer to an exempt address, and exempt addresses are the custodial ones that receive most.
- **`IBalanceOf`** in `src/rules/interfaces/` — a one-function balance query, so the rule depends on exactly the token surface it calls, matching `ITotalSupply`.


- **`RuleChainlinkPoR`** — a validation rule that caps total supply at the reserves reported by a [Chainlink Proof of Reserve](https://docs.chain.link/data-feeds/proof-of-reserve) data feed. Before every mint it reads `latestRoundData()` from the configured `AggregatorV3Interface`, scales the answer from the feed's decimals to the token's, and rejects the mint when `totalSupply + value` would exceed it. Modelled on Chainlink's `SecureMintPolicy` from the ACE policy library, minus its configurable reserve margin. Restriction codes `75` (reserves exceeded), `76` (feed stale), `77` (a round was returned but is unusable — negative reserve or incomplete round), `78` (total supply unavailable), `79` (the feed could not be read at all). Available as `RuleChainlinkPoR` (AccessControl) and `RuleChainlinkPoROwnable2Step`.
  - **Limit = reserves, exactly** — no margin, buffer or headroom parameter. Compose with `RuleMaxTotalSupply` for a static cap, or report conservative reserves upstream for a cushion.
  - **Staleness threshold** — `maxStalenessSeconds` rejects mints when the feed has not been updated recently; `0` disables the check.
  - **Mints only** — transfers and burns always pass, including while the feed is stale or unavailable, so a lapsed feed never traps holders.
  - **Feed decimals read live, never cached** — the extra `STATICCALL` costs ~2,900 gas per mint (+2.6%), which buys immunity to an aggregator migration silently mis-scaling the reserves by `10 ** delta`. In the overstating direction a cached value would authorise unbacked minting with no on-chain signal. Rationale, measurements and residual risk are in the [rule doc](./doc/technical/contracts/RuleChainlinkPoR.md#why-the-decimals-are-read-live-and-what-it-costs).
  - **Feed failures are reported by kind, not lumped together.** `79` means no usable response could be obtained; `77` means a round came back and its contents are unusable. Both block the mint identically, but the restriction code is the only diagnostic channel a non-reverting view has, so the distinction is worth a code: `79` says check feed liveness, `77` says check that the configured address is really a Proof of Reserve feed.
  - **Revert-free read path** — one `code.length` check covers both feed calls (Solidity's extcodesize revert on a `try` to a codeless address is uncatchable), `decimals()` and `latestRoundData()` are both wrapped in `try/catch`, `MAX_FEED_DECIMALS` is re-checked at read time so the scaling exponent cannot overflow, decimal scaling saturates rather than overflows, and the supply comparison uses remaining headroom. The ERC-1404 / ERC-3643 views therefore return a code instead of reverting under every feed failure mode.
  - **Token validated at configuration** — a non-contract address is rejected explicitly (`RuleChainlinkPoR_TokenIsNotAContract`) and `totalSupply()` is probed (`RuleChainlinkPoR_TokenTotalSupplyUnavailable`), so a token that cannot serve the restriction check fails loudly at setup instead of silently bricking the read path. At run time a reverting or codeless token yields code `78` rather than a revert.
  - `maxBackedSupply()` previews the current limit without simulating a mint.
  - **ERC-20 only.** Like `RuleMaxTotalSupply`, the rule exposes no ERC-7943 `tokenId` overloads and no `ITransferContext` entrypoints — it inherits `RuleTransferValidation` rather than `RuleNFTAdapter` — and it requires an aggregate `totalSupply()`, which plain ERC-721 lacks and which is per-id for ERC-1155. Deliberate: a reserve cap on a fungible supply has no `tokenId` dimension. Recorded in the overload matrix in `RULE_SEMANTICS.md`.
  - **Documented:** one instance protects one token. The rule reads `totalSupply()` from its configured `tokenContract` rather than from the token that triggered the check, and has no binding to enforce the pairing — sharing an instance across RuleEngines silently evaluates both tokens against the first one's supply and feed. Same exposure as `RuleMaxTotalSupply`; see [One instance per protected token](./doc/technical/contracts/RuleChainlinkPoR.md#one-instance-per-protected-token).
- **`RuleReceiverWhitelist`** — a whitelist that screens **only the receiver**, reproducing ERC-3643's eligibility rule as a CMTAT compliance rule. It fills the gap between `RuleWhitelist` (both parties) and `RuleSpenderWhitelist` (spender only). Restriction code `81`. Available as `RuleReceiverWhitelist` (AccessControl) and `RuleReceiverWhitelistOwnable2Step`.
  - The sender and the spender are **never** screened. That is the point, not an omission: screening the sender traps de-listed holders, and ERC-3643 checks only the receiver precisely so a lapsed investor can still exit their position.
  - Mint is screened on the receiver like any other transfer — no `allowMint`/`allowBurn` flags, since ERC-3643 gates minting on receiver eligibility alone. Compose with `RuleMaxTotalSupply` or `RuleChainlinkPoR` to cap issuance.
  - Burn (`to == address(0)`) is exempt explicitly, because the zero address can never be listed and every burn would otherwise be rejected.
  - Equivalence with the standard is pinned against the **real vendored ERC-3643 token** in `test/ERC3643Real/ERC3643ReceiverWhitelistParity.t.sol`: the rule runs in the token's compliance slot over the same address set the identity registry holds, and must never change the outcome.
- `AggregatorV3Interface` and `IDecimals` in `src/rules/interfaces/`, so the library reads Chainlink feeds without taking a dependency on the Chainlink contracts package.
- **`IdentityRegistryWhitelist`** — a whitelist that plugs into an **ERC-3643 token's identity registry slot** (`token.setIdentityRegistry(...)`), so a token can enforce investor eligibility without deploying ONCHAINID contracts. `registerIdentity` whitelists, `deleteIdentity` removes, `isVerified` answers the token's per-transfer check. Only the subset of `IIdentityRegistry` that `Token.sol` actually calls is implemented. This is **not** a compliance rule: no `IRule` surface, and it must not be added to a `RuleEngine`.
  - Implements **no** ERC-734 surface. `recoveryAddress` must be given a real ONCHAINID as `_investorOnchainID`; the registry only supplies `isVerified`, `registerIdentity`, `deleteIdentity` and `investorCountry`. Consequently `registerIdentity` rejects duplicates exactly like the reference registry, and the replacement wallet is registered by the token during recovery rather than beforehand — no behavioural divergence from stock ERC-3643 remains.
  - The ERC-3643 token must hold `IDENTITY_REGISTRAR_ROLE`, because `recoveryAddress` makes the token call `registerIdentity` and `deleteIdentity`.
  - Reuses `RuleAddressSetInternal` — the same `EnumerableSet` machinery as `RuleWhitelist` / `RuleBlacklist` — for storage, the zero-address guard and the revert errors, so no whitelist contract is deployed and none is re-implemented. Only the internal layer is inherited, so the registry exposes one write API rather than two overlapping ones.
  - **No identity data is kept.** The `_identity` and `_country` arguments exist so the ERC-3643 signature matches, then are discarded; `investorCountry` is a constant `0`. The contract is a wrapper that adapts the token's registry calls onto a plain whitelist. `Token.sol` reads the country in exactly one place (`recoveryAddress`, a pass-through it hands straight back), so the token is unaffected; the exposure is a *custom* compliance module reading `investorCountry`, which would see every investor as country 0.
  - Implements `IERC3643Version` via `VersionModule`, like the rules: it is a deployable production contract wired into a token's identity slot, so its release must be identifiable on-chain.
  - `isVerified(address(0))` is always `false`; the zero address can never be registered.

### Changed

- **`ADDRESS_LIST_ADD_ROLE` / `ADDRESS_LIST_REMOVE_ROLE` moved** from `RuleAddressSetInvariantStorage` into a new `RuleAddressSetRolesStorage`, inherited by `RuleAddressSet` — the public layer that actually enforces them. No rule's ABI changes: `RuleWhitelist`, `RuleReceiverWhitelist`, `RuleBlacklist` and `RuleSpenderWhitelist` still expose both. The effect is on `IdentityRegistryWhitelist`, which reuses only the internal layer and was publishing both roles while gating registration on `IDENTITY_REGISTRAR_ROLE` — an operator could grant one, receive no privilege, and get no signal that the grant was inert. They are now absent from its ABI, pinned by `testDoesNotExposeInertAddressListRoles`.

- **`RuleMaxTotalSupply` now validates its token contract and guards the supply read** (same hardening as `RuleChainlinkPoR`, threat `EXT-4`). The constructor and `setTokenContract` reject a non-contract address (`RuleMaxTotalSupply_TokenIsNotAContract`) and probe that `totalSupply()` is callable (`RuleMaxTotalSupply_TokenTotalSupplyUnavailable`). At run time a token whose `totalSupply()` reverts yields the new restriction code `51` (`CODE_SUPPLY_ORACLE_UNAVAILABLE`) instead of reverting the ERC-1404 / ERC-3643 views, which MUST NOT revert. Codeless targets are excluded by construction rather than by a runtime check: the setters require code and EIP-6780 (Cancun) makes that permanent, recorded as a deployment precondition in each rule doc.
  - **Migration:** deployments that passed a placeholder or non-contract address as `tokenContract` now revert at construction. This only rejects configurations that could never have worked — the previous behaviour was to accept them and then revert on every restriction check. Integrators switching on restriction codes should handle `51`, which can only appear where the view previously threw.

- **Batch events now report what changed, not just what was submitted** (`CLAUDE_ANALYSIS.md` C-4). Every batch add/remove loop already computed `added` / `removed` and `skipped`, and every caller discarded them, emitting only the input array — so a batch of 100 new members and a batch of 100 no-ops produced byte-identical events. The counters are now carried by the event; `added + skipped` always equals the input length.
  - **Breaking change to the event ABI.** Six signatures gain two `uint256` fields — `AddAddresses` / `RemoveAddresses` on `IAddressList`, and the four `RuleERC2980` whitelist/frozenlist equivalents — so their `topic0` changes: `AddAddresses(address[])` was `0xc81f47d2…`, `AddAddresses(address[],uint256,uint256)` is `0x986167d3…`. An indexer filtering on the old topic stops matching. Landing it in v0.5.0, before release, is deliberate: after release this would be a major-version discussion.
  - Costs **+572 gas per batch call** — two extra 32-byte log words, **constant rather than per element**: 0.06% of a 20-address add (dominated by cold `SSTORE`s), 1.0% of the cheaper remove. Nothing new is spent in the loop, since the counters were already being computed.
- **`VersionModule.version()` is now `pure` instead of `view`** (`CLAUDE_ANALYSIS.md` F-7b). It returns a compile-time constant and reads no state, so `pure` is the accurate mutability; Solidity permits an override to tighten it, and `AggregatorV3Mock.version()` already used the same `pure`-over-`view` pattern. **This changes the ABI's `stateMutability` field** for `version()` on every deployable contract — the selector is unchanged, no other ABI entry differs, and both mutabilities are read-only, so callers are unaffected; only a release-to-release ABI diff will show it.
- **Removed an empty `INTERNAL FUNCTIONS` banner** from `IdentityRegistryWhitelistBase` (`CLAUDE_ANALYSIS.md` F-7a). The contract's only internal member sits under the `ACCESS CONTROL` banner; the empty section invited the next internal function to be filed in the wrong place.
- **Address-set writes no longer look the entry up twice** (`CLAUDE_ANALYSIS.md` B-4). `addAddress`, `removeAddress`, the four `RuleERC2980` list writes and `registerIdentity` / `deleteIdentity` each tested membership with `contains()` and then called `add()` / `remove()`, which performs the same test internally and returned a result that was discarded. The six internal helpers now forward `EnumerableSet`'s result and the callers `require` on it, so the guard and the mutation are the same lookup and cannot disagree.
  - Behaviour and error identity are unchanged: `add` returns `false` for a duplicate without touching storage, and the zero-address guard still runs first, so `address(0)` still yields `ZeroAddressNotAllowed` rather than the duplicate error.
  - Saves **~288 gas** per call, measured across all five affected entrypoints (0.4% of an add, which is dominated by the cold `SSTORE`; ~7% of a remove).
- **The `checkSpender` setter machinery lives in `RuleWhitelistShared` instead of being duplicated in both whitelist bases** (`CLAUDE_ANALYSIS.md` D-4). `setCheckSpender`, `_setCheckSpender`, `_authorizeCheckSpenderManager` and the `onlyCheckSpenderManager` modifier were verbatim identical in `RuleWhitelistBase` and `RuleWhitelistWrapperBase`, although the `checkSpender` flag itself already lived in their shared parent. Each now sits beside its `allowMint`/`allowBurn` counterpart, which was already organised this way.
  - **No ABI change anywhere.** Hoisting a public function into a shared parent adds it to every inheriting contract, so this was verified rather than assumed: the function-level ABI is byte-identical for `RuleWhitelist`, `RuleWhitelistOwnable2Step`, `RuleWhitelistWrapper`, `RuleWhitelistWrapperOwnable2Step`, `RuleReceiverWhitelist`, `RuleSpenderWhitelist` and `RuleBlacklist`. The receiver- and spender-whitelist rules build on `RuleNFTAdapter` directly and did not gain `setCheckSpender` — which would have been wrong for `RuleReceiverWhitelist`, whose whole design is to screen only the receiver. Storage layout unchanged.
  - `RuleIdentityRegistry.setCheckSpender` is untouched and stays separate: a different flag, a different manager role, a different event, and a different meaning ("also require the spender to be identity-verified").
  - Line coverage of both bases rose to 100% — the previously-uncovered lines were the duplicated abstract declarations.
- **`RuleWhitelistWrapper.isVerified` delegates to `_isListedInAnyChild` instead of repeating its body** (`CLAUDE_ANALYSIS.md` D-5). The two functions were identical, 90 lines apart. Behaviour unchanged, and the ERC-3643 eligibility view now resolves an address through the same helper the mint and burn branches of `_detectTransferRestriction` use — so the view and the transfer check cannot disagree by construction rather than by coincidence. Runtime bytecode drops **124 bytes** (~24,800 gas at deployment); each `isVerified` call costs 27 gas more for the internal call.
- **`RuleMaxTotalSupplyBase` and `RuleMaxBalanceBase` are split the same way**, completing the pattern started with `ChainlinkPoRFeedManager`. New `TotalSupplyCapManager` and `BalanceCapManager` in `abstract/core/` hold the observed token, the cap, the exemption list (for the balance rule), the setters and the revert-free read; each base keeps its constructor, the ERC-1404 / ERC-3643 surface and the logic that turns a breached cap into a restriction code.
  - **Neither manager declares a constructor or depends on ERC-1404.** They answer in booleans (`_capExceeded`) and token units (`_remainingCapacity`); the rule owns the code mapping. So *when* configuration happens is the inheritor's choice — a constructor today, an initializer in an upgradeable variant — and a contract wanting only a revert-free view of remaining headroom can inherit one without implementing a restriction-code surface.
  - **Storage layout and ABI are unchanged**, verified per-slot from the compiled artifacts for all four deployable contracts (`RuleMaxTotalSupply`, `RuleMaxTotalSupplyOwnable2Step`, `RuleMaxBalance`, `RuleMaxBalanceOwnable2Step`). `RuleMaxBalance.remainingCapacity` keeps its public `(uint8 restrictionCode, uint256 headroom)` signature: the manager's version is `internal` and code-free, and the rule wraps it, so no ABI entry moved.
  - The two bases drop to 83 and 88 code lines. All 820 + 31 tests pass unchanged; the style checker is clean.
- **`RuleChainlinkPoRBase` is split in two.** Proof-of-Reserve feed management moved to a new `ChainlinkPoRFeedManager` in `abstract/core/`, which `RuleChainlinkPoRBase` now inherits. The manager holds the feed, the protected token, `tokenDecimals`, `maxStalenessSeconds`, their setters, and the revert-free reserve read; the base keeps the constructor, the ERC-1404 / ERC-3643 surface and the restriction logic.
  - **It declares no constructor and no ERC-1404 dependency**, which is the reason for the split: *when* configuration happens is left to the inheritor (a constructor today, an initializer in an upgradeable variant), and a contract that only wants a revert-free view of reserve-backed supply can inherit it without acquiring a restriction-code surface it would have to implement.
  - **Storage layout and ABI are unchanged**, verified per-slot from the compiled artifacts for both `RuleChainlinkPoR` and `RuleChainlinkPoROwnable2Step` — the six slots and all 35 / 31 ABI functions are identical. Behaviour, gas and coverage are unchanged; all 763 + 31 tests pass.
- **`RuleMaxTotalSupply` and `RuleChainlinkPoR` share their supply-reading mechanics** (`CLAUDE_ANALYSIS.md` D-2). New `TokenSupplyReader` holds the revert-free `totalSupply()` read that both rules implemented byte-identically, plus the `try/catch` probe their configuration validators use. Behaviour unchanged; **storage layout identical**, verified per-slot from the compiled artifacts for both rules and both Ownable2Step variants.
  - **The base declares no storage.** Each rule keeps its own `tokenContract` and implements a `_supplyToken()` hook — the template-method pattern already used for `_authorize*`. Declaring the variable in the base would have reordered `RuleChainlinkPoR`'s slots, moving `tokenContract` ahead of `reservesFeed`, for no benefit.
  - **Configuration validation stays per-rule.** Both rules check non-zero / has-code / `totalSupply()`-callable, but each raises its own named error for each failure. Only the probe moved, returning a `bool` the rule turns into its own error; collapsing the three `require`s into one helper would trade three named operator-facing diagnostics for a few saved lines.
  - Marginally **faster**: 12 gas less on both mint read paths (`RuleChainlinkPoR` 5,966 → 5,954, `RuleMaxTotalSupply` 2,460 → 2,448), because the hook inlines and removes an intermediate stack shuffle.
- **The batch add/remove loops are shared instead of written three times** (`CLAUDE_ANALYSIS.md` D-1). New `AddressSetBatchLib` holds the two loops that `RuleAddressSetInternal` and `RuleERC2980Internal` (once for its whitelist, once for its frozenlist) each carried their own copy of. Behaviour is unchanged and **storage layout is identical**, verified per-slot from the compiled artifacts across `RuleWhitelist`, `RuleERC2980`, `RuleBlacklist`, `RuleReceiverWhitelist`, `RuleSpenderWhitelist` and `IdentityRegistryWhitelist`.
  - Only the loops moved. Single-address `add` / `remove` / `contains` / `length` stay as one-line delegations to `EnumerableSet`, where a library would add indirection without removing duplication.
  - **Each rule keeps its own zero-address error.** `RuleAddressSet_ZeroAddressNotAllowed` and `RuleERC2980_ZeroAddressNotAllowed` are distinct per the one-error-namespace-per-rule convention, which a shared loop cannot name. The guard is therefore passed to `addBatch` as an `internal pure` function pointer: a required parameter, so it cannot be forgotten, while the revert data each rule produces is unchanged.
  - Costs ~34 gas per entry on a batch add and ~4 on a batch remove, from the indirect jump — 0.07% of a 20-address batch, which is dominated by cold `SSTORE`s, and an operator path rather than a per-transfer holder path. `RuleERC2980`'s runtime bytecode shrinks 200 bytes; `RuleWhitelist`'s grows 62.
- **`RuleWhitelistWrapper`: the child-rule scan's early exit is now O(1) instead of a full rescan** (`CLAUDE_ANALYSIS.md` A-2). `_detectTransferRestrictionForTargets` used to re-derive "have all targets been resolved?" by walking the whole `result` array after every child rule; it now maintains a counter of unresolved targets and breaks when it reaches zero. Behaviour is identical — including the documented consequence that a pair already resolved by an earlier child never reaches a later, broken child (documented wrapper behaviour WW-2). Saves ~85 gas per child scanned (~1% of the ~8.8k per-child cost, which is dominated by the external `STATICCALL`); ~850 gas on a rejected transfer through a 10-child wrapper, paid by the transferring user.
  - The resolved-counter form needs a `!result[j]` guard so an address listed in several children is counted once. Without it the counter would reach zero early and break out of the scan before a later child could resolve a *different* target, rejecting a valid transfer. Pinned by `testDetectTransferRestrictionOkWhenAddressListedInSeveralChildRules`, which covers both the 2-target and the `checkSpender` 3-target paths.

- **Conditional-transfer rules: the approval counter is no longer re-read from storage to populate `TransferApproved`** (`CLAUDE_ANALYSIS.md` B-1). `approveTransfer` (`RuleConditionalTransferLightApprovalBase`) and `_approveTransfer` (`RuleConditionalTransferLightMultiTokenBase`) computed `approvalCounts[hash] += 1` and then read the slot back for the event; they now keep the new value in a local. Event data is byte-identical. Saves ~109 gas per approval, measured with the variants isolated in single-function contracts so dispatch cost is held constant.
  - The four `= count - 1` sites named in the same finding were deliberately **left as they are**. Measurement showed the optimizer already forwards the stored value to the subsequent load there, so the re-read is free and adding an explicit local costs ~12 gas. Changing all six gave back roughly two thirds of the saving: on `test_CTL2_EngineKeyedApprovalIsSharedAcrossTokens` the blanket change saved 906 gas against baseline, the increment-only change saves 2,899.

- **`RuleSanctionsList`: the oracle address is read from storage once per check instead of up to five times** (`CLAUDE_ANALYSIS.md` B-2). `_detectTransferRestriction` and `_detectTransferRestrictionFrom` re-read `sanctionsList` for the zero-address guard and again for each `isSanctioned` call; they now cache it in a local. Behaviour is unchanged and the caching is provably safe: both functions are `view`, so the oracle is reached by `STATICCALL` and cannot write this contract's storage. Measured saving on the paths a compliant transfer takes: **219 gas** on `detectTransferRestriction` and **320 gas** on `detectTransferRestrictionFrom` (~98 gas per avoided warm `SLOAD`); 98 gas on the early-return sanctioned paths, 7 gas when no oracle is configured.
  - The reload inside the `transferFrom` → direct-check delegation was left in place on purpose. A private `_screen(oracle, from, to)` helper would remove another ~100 gas, but `_detectTransferRestrictionFrom` calling `_detectTransferRestriction` is how every rule in the library composes its two checks; bypassing it would mean an override of the direct hook no longer applied to `transferFrom`.

- **All `internal` functions are now `virtual`, as the project convention requires** (`CLAUDE_ANALYSIS.md` E-1). Sixteen were not: `_authorizeTransferExecution` (`RuleConditionalTransferLightBase`), the batch set helpers in `RuleAddressSetInternal` and `RuleERC2980Internal`, and the `_detectTransferRestriction` / `_detectTransferRestrictionFrom` pair on `RuleBlacklist`, `RuleIdentityRegistry`, `RuleMaxTotalSupply`, `RuleChainlinkPoR` and `RuleSanctionsList` (direct hook only). A re-scan reports zero remaining. No ABI change and **no gas change** — Solidity resolves `internal virtual` calls statically through the C3 linearization, verified by three `ThreatModel` tests reporting gas identical to the last digit before and after.
  - `_authorizeTransferExecution` is the one that mattered most: it is the hook the conventions single out as required to be `internal view virtual`, and without it no subclass could change who may consume an approved transfer.
  - The `_detectTransferRestriction*` hooks were previously `virtual` on the whitelist family and not on the blacklist and oracle-backed rules, with `RuleSanctionsListBase` declaring the direct hook non-`virtual` and its `From` sibling `virtual` 28 lines apart. That split is now gone.

- **Both `canTransfer` overloads on the core rule bases are now `virtual`** (`CLAUDE_ANALYSIS.md` E-2). `RuleTransferValidation.canTransfer(from, to, amount)` and its ERC-7943 twin `RuleNFTAdapter.canTransfer(from, to, tokenId, amount)` were each the only non-`virtual` function in their contract — every neighbouring view (`detectTransferRestriction`, `detectTransferRestrictionFrom`, `canTransferFrom`, `supportsInterface`, the `transferred` overloads) was already `virtual` — so no rule could override the view integrators reach for first. No ABI change, no gas change.
  - This does **not** cover the roughly 55 other non-`virtual` public views across the library (`messageForTransferRestriction`, `canReturnTransferRestrictionCode`, the `RuleERC2980` getters, the `RuleAddressSet` read surface, the conditional-transfer read surface, and others). Those break no local pattern and are a codebase-wide sweep to be decided alongside the public mutating functions.

- **The 27 public mutating functions that were not `virtual` now are** (`CLAUDE_ANALYSIS.md` E-3): the four `RuleAddressSet` write functions, the eight `RuleERC2980Base` list functions, `setMaxTotalSupply` / `setTokenContract`, `setIdentityRegistry` / `clearIdentityRegistry`, and the approval, binding, `approveAndTransferIfAllowed` and `transferred` entrypoints on both conditional-transfer rules. A re-scan returns zero remaining. No ABI change and no gas change.
  - This removes three inconsistencies the finding called out: `RuleMaxTotalSupply`'s setters were non-`virtual` while `RuleChainlinkPoR`'s equivalents were `virtual`; `resetApproval` was `virtual` while `approveTransfer` and `cancelTransferApproval` beside it were not; and the four token-facing `transferred` hooks — the functions a token calls on every transfer — were the least overridable in the library.
  - **`IdentityRegistryWhitelist` is deliberately not refactored.** `CLAUDE.md` justifies its inheriting only `RuleAddressSetInternal` partly on `addAddress`/`removeAddress` not being `virtual`, which is no longer true, but the independent reason recorded in its technical doc — exposing exactly one write API rather than two overlapping ones — still holds. The agent-guide wording is now stale and should be corrected separately.

- **`RuleSanctionsList`: the `transferFrom` path now always consults the direct restriction check** (`CLAUDE_ANALYSIS.md` F-2). `_detectTransferRestrictionFrom` nested its delegation to `_detectTransferRestriction` inside the `oracle != address(0)` branch, so with no oracle configured it returned `TRANSFER_OK` without ever calling the hook. The oracle guard now scopes only the spender check and the delegation is the unconditional last statement, matching `RuleBlacklist`, `RuleWhitelist` and `RuleIdentityRegistry`.
  - Behaviour is unchanged for the rule as shipped, but the defect was reachable: the `_detectTransferRestriction` hook became `virtual` in this release, so a subclass adding an oracle-independent check would have had it applied to `transfer` and silently **not** to `transferFrom` whenever no oracle was set — a rule screening one entrypoint but not the other.
  - Costs **221 gas** on the `transferFrom` path when no oracle is configured (1,547 → 1,768), since that path now re-reads the oracle slot inside the delegated hook rather than returning early. Paths that actually screen are unchanged within noise, and a plain `transfer` is identical.
- **`RuleSanctionsList` no longer asks the oracle whether `address(0)` is sanctioned** (`CLAUDE_ANALYSIS.md` F-1). The zero address is the ERC-20 mint/burn sentinel, not a wallet: `from` is now skipped on a mint and `to` on a burn, matching how every other rule in the library treats it. Previously the sentinel was forwarded to the oracle on every issuance and redemption, so an oracle that answered `true` for `address(0)` — a degenerate input it is free to answer either way — would have blocked **all minting and all burning** on every token using this rule, reporting a "sanctioned sender" that is not an address. Chainalysis returns `false` today; the rule no longer depends on that.
  - **Screening of real participants is unchanged.** A mint to a sanctioned recipient is still rejected with code `31`, a burn from a sanctioned holder with code `30`, and the **minter is still screened as the `spender`** on the 4-argument mint path.
  - Side effect: a mint or burn now makes one oracle call instead of two, saving **2,830 gas** per issuance and redemption (5,308 → 2,478). The saving exceeds one call's nominal cost because the removed call read `address(0)`'s slot in the oracle, which nothing else ever touches and is therefore **cold on every mint**. A plain transfer pays **+96 gas** for the two new guards, on a path where they are always true.

- **`RuleIdentityRegistry`: removed a dead `to != address(0)` term from the spender check** (`CLAUDE_ANALYSIS.md` F-3). The burn guard six lines above already returns when `to` is the zero address, so the term could never be false. Behaviour is identical. The comment above it was wrong in the same way — it read *"Mint (from == 0) and burn (to == 0) are exempt"*, crediting this condition with a burn exemption the early return actually provides; it now states where burn is really handled and warns against re-adding the test. Saves **49 gas** on a `transferFrom` with both opt-in flags enabled and 20 gas on the receiver-only default; the burn path is unchanged to the gas, which is itself evidence that burn never reaches this condition. Already pinned by `testBurnBypassesAllChecks`, so no new test.
- **`RuleIdentityRegistry`: the registry address is read from storage once per check instead of up to five times** (`CLAUDE_ANALYSIS.md` B-3), the same treatment as `RuleSanctionsList` above and safe for the same reason — both functions are `view`, so `isVerified` is reached by `STATICCALL` and cannot write `identityRegistry`. Behaviour unchanged. Measured: **113 gas** saved on a receiver-only transfer (the ERC-3643 default) and on a mint, **219** with `checkSender` enabled, **320** on a `transferFrom` with both flags on.
  - The path where no registry is configured is **5 gas more expensive** — loading the slot into a typed local before comparing costs a couple of stack operations. Accepted: that is the path where the rule is switched off and does nothing, against 108–320 gas saved wherever it actually screens.
  - The duplicated null-registry and burn guards between `_detectTransferRestrictionFrom` and `_detectTransferRestriction` were deliberately left in place, as with `RuleSanctionsList`: collapsing them needs a helper that takes the registry as a parameter, which would stop a subclass's override of the direct hook from applying to `transferFrom`.

- **Deployment-time configuration is now announced by every rule** (`CLAUDE_ANALYSIS.md` C-1, C-2, C-3). Three constructors assigned configuration silently, so a rule set up once at deployment and never reconfigured had no on-chain event trail for those values — an indexer saw the setting appear from nowhere at the first later change, or never at all.
  - **`RuleMaxTotalSupply`** emitted neither `TokenContractUpdated` nor `MaxTotalSupplyUpdated` at construction, although both setters did and its sibling `RuleChainlinkPoR` announced all three of its values. The constructor now routes through new internal `_setTokenContract` / `_setMaxTotalSupply` helpers that the public setters also use, matching the `RuleChainlinkPoR` pattern.
  - **`RuleWhitelist` and `RuleWhitelistWrapper`** emitted `AllowMintUpdated` and `AllowBurnUpdated` at construction but not `CheckSpenderUpdated`, on adjacent lines. The emit moved from the public setter into `_setCheckSpender`, which the constructors now call — so the flag is announced on every assignment, exactly like `_setAllowMintBurn`. The public setter still emits precisely once.
  - **`RuleIdentityRegistry`** emitted both check flags at construction but not `IdentityRegistryUpdated` for the registry address the rule is parameterised by. It now does, **only when a registry is actually assigned**: a zero argument leaves the default untouched, and an `IdentityRegistryUpdated(0)` there would be indistinguishable from a deliberate `clearIdentityRegistry()`. This matches `RuleSanctionsListBase`, which already emitted only when an oracle was supplied.
  - No ABI change; the rule for the whole library is now "every value actually assigned is announced".

- **Style-guide pass over the new code.** `_authorizeMaxBalanceManager` moved below the internal setters in `RuleMaxBalanceBase`, so the `view`-last ordering matches `ChainlinkPoRFeedManager` and every other rule; `BalanceOfMock` gained NatSpec on its storage and replaced its string revert with a `BalanceOfMock_Reverting()` custom error. Behaviour-preserving: one member block relocated with its NatSpec, one comment added, one revert reason swapped for an equivalent error nothing asserts on.

### Changed — dependencies

- **Solidity toolchain updated to `0.8.36`** (from `0.8.34`), in both `foundry.toml` and `hardhat.config.js`. Builds clean and all three suites pass unchanged: 763 Foundry tests, 31 on the ERC-3643 profile, and the Hardhat smoke test.
  - **`[profile.erc3643]` deliberately stays on `0.8.30`**, and must. The vendored ERC-3643 `Token.sol` pins `pragma solidity 0.8.30` *exactly*, so it cannot share a compilation unit with the default profile at any other version. Verified after the bump: the default profile compiles with Solc 0.8.36, the ERC-3643 profile with Solc 0.8.30.
  - Source pragmas are untouched. Contracts stay on `^0.8.20` so integrators pin their own compiler; only this repository's own builds move.
  - The v0.5.0 Slither and Aderyn reports were produced at `0.8.34` and record that in their headers. They were not re-run for a patch-level compiler bump; their findings are source-level (pragma, PUSH0, centralization, empty blocks) and do not depend on the codegen version.

- **RuleEngine bumped to `v3.0.0-rc5` and OpenZeppelin to `v5.7.0`** (from `v3.0.0-rc4` and `v5.6.1`, both `openzeppelin-contracts` and `-upgradeable`). **These two are coupled and must move together**: rc5 changed `ERC3643ComplianceModule.getTokenBound()` from `_boundTokens.at(0)` to `_boundTokens.pos(0)`, and `pos` does not exist before OpenZeppelin `v5.7.0`. Building rc5 against `v5.6.1` fails with `Member "pos" not found ... in struct EnumerableSet.AddressSet`.
  - **No behaviour change.** OpenZeppelin documents `pos` as "Replacement of the deprecated `at` function", so `getTokenBound()` returns what it always did. No interface this library implements changed: the diff across RuleEngine's `src/` is comments, NatSpec and library constants.
  - `at` is now deprecated in `EnumerableSet` but still present. This library never calls it — the address-set machinery uses `add` / `remove` / `contains` / `length` / `values` — so nothing here needs migrating.
  - All suites pass unchanged on the new pins: 763 Foundry tests, 31 on the ERC-3643 profile, the Hardhat smoke test, and all four deployment scripts under `forge script`.

- **CMTAT submodule bumped to `v3.3.0-rc3`** (from `v3.3.0-rc1`). Builds clean and both test profiles pass unchanged (763 + 31). No interface this library imports changed shape: `ICMTATConstructor`, `IRuleEngine` and `draft-IERC1643CMTAT` differ only in the pragma and NatSpec, and the validation modules changed in comments only.
  - `IRuleEngine` gains a **normative requirement** in its NatSpec: zero-value calls are permissionless, because ERC-20 treats a `0` transfer as a normal transfer and `_spendAllowance` consumes no allowance, so anyone can reach `transferred(spender, from, to, 0)` for an arbitrary `from`. Implementations "MUST therefore treat `value == 0` as carrying no economic meaning: any stateful rule ... MUST be a no-op for a zero value". **The stateful rules in this library do not yet satisfy this, and that is a recorded decision for `v0.5.0` rather than an oversight** — the fix is a behaviour change to shipped compliance logic (a zero-value transfer would stop reverting) and was deferred rather than applied late in the release. The scope was established by measurement, not by reading the requirement: `RuleConditionalTransferLight` and `…MultiToken` consume an approval for a caller never approved, and `RuleMaxBalance` rejects a receiver already over the cap — both would change. `RuleMintAllowance` needs **no** change (debiting `0` is already a no-op and the mint path is not permissionlessly reachable), and the address-screening rules are deliberately **out** of scope, since they screen *who* rather than *how much* and a blanket zero-value exemption would weaken every deny-list. Documented in `doc/technical/contracts/RuleConditionalTransferLight.md` and `doc/technical/contracts/RuleMaxBalance.md`.

### Fixed

- **CI now runs the ERC-3643 test suite.** `.github/workflows/test.yml` ran only `forge test`, which uses the default profile — and `test/ERC3643Real/**` is in that profile's `skip` list. The 18 tests built by `[profile.erc3643]`, including the parity suite that runs against the real vendored `Token.sol`, were therefore never executed in CI, despite `AGENTS.md` / `CLAUDE.md` stating that both commands are required. Added a `Run Forge tests (ERC-3643 profile)` step with a step-level `FOUNDRY_PROFILE: erc3643`, which overrides the workflow-level `ci` for that step only.
- **CI: `npx hardhat test` no longer fails on the ERC-3643 remapping.** The context-scoped remapping `lib/ERC-3643/:@onchain-id/solidity/contracts/=test/utils/onchainid/` moved out of `remappings.txt` and into `remappings = [...]` under `[profile.erc3643]` in `foundry.toml`. `forge remappings` prints `remappings.txt` for every profile, and `hardhat-foundry` runs exactly that command and rejects any line containing a `:` — `HardhatFoundryError: Invalid remapping ..., remapping contexts are not allowed` — which aborted the workflow's last step. Declared as profile config the remapping applies only when that profile is selected, so the default and `ci` profiles Hardhat sees are context-free while `FOUNDRY_PROFILE=erc3643` still resolves the ONCHAINID stubs. No Solidity changed and no build output moved; `forge test` (691) and `FOUNDRY_PROFILE=erc3643 forge test` (18) are unaffected.

### Documentation

- **NatSpec length ceiling, and a pass to meet it.** `CLAUDE.md` / `AGENTS.md` gain a convention capping a NatSpec block at 20 lines, with the rationale that a comment past that has stopped being a comment and become a document, and that the more claims a block makes the more of them go stale unnoticed. The ceiling was set from the measured distribution over `src/` rather than picked: median 4 lines, 90th percentile 8. Fifteen blocks exceeded it and were rewritten to keep the safety preconditions, footguns and non-obvious design constraints while cutting code restatement, refactor narration and benefit lists — the distribution now runs median 4 / p90 8 / **max 19** across 1003 blocks, with none at or over the ceiling. Comment-only: filtering the whole diff for non-comment lines yields nothing, so no behaviour, ABI or storage change is possible; 820 + 31 tests pass unchanged. The `analyse-code-quality` skill gained the corresponding check.
  - One block was damaged by the trimming and repaired in a follow-up: `BalanceCapManager`'s header lost the middle of its first `@dev`, leaving `Declares **no constructor**` with no verb or period glued to an unrelated sentence. Found by inspecting the compiled `devdoc` rather than the source. **The line-count check cannot catch this** — it measures length, not whether a trimmed sentence still parses as English — so the other fourteen rewrites were re-read by hand and are clean.
  - Worth knowing for anyone editing these blocks: **solc merges repeated `@dev` tags into one `details` string with no separator**, so `…the cap.` followed by a new `@dev` renders as `…the cap.{_balanceOf} must never revert`. Within a single tag, lines join with a space and blank lines collapse. Multiple `@dev` is valid and loses no content — 15 blocks in `src/` use it — but paragraph structure survives only in the source, not in `forge doc` or Etherscan output.
- New [`doc/technical/contracts/RuleReceiverWhitelist.md`](./doc/technical/contracts/RuleReceiverWhitelist.md), including why receiver-only screening is the conformant choice and how the parity suite tests it.
- New [`doc/technical/contracts/IdentityRegistryWhitelist.md`](./doc/technical/contracts/IdentityRegistryWhitelist.md), including a table of which ERC-3643 token functions call the registry and how, the `recoveryAddress` call sequence, and five documented limitations.
- New [`doc/technical/contracts/RuleChainlinkPoR.md`](./doc/technical/contracts/RuleChainlinkPoR.md), including a point-by-point comparison against Chainlink's `SecureMintPolicy 1.2.0` (vendored at `lib/chainlink-ace/`) and a *Token compatibility: ERC-20 only* section; `RULE_SEMANTICS.md` and `README.md` updated with the new rule.
- **README ERC-721/ERC-1155 section corrected.** It listed only `RuleConditionalTransferLight` and `RuleMaxTotalSupply` as ERC-20 only, and described `IERC7943NonFungibleCompliance*` as "implemented by validation rules only" — a category claim that `RuleChainlinkPoR`, itself a validation rule, does not satisfy, so the README implied the opposite of the truth for the new rule. The exclusions are now named individually and the missing `totalSupply()` requirement is stated. The `ITransferContext` paragraph had the same defect and claimed `RuleMaxTotalSupply` exposes the fungible variant, which it does not — it exposes neither, as do `RuleChainlinkPoR` and `RuleMintAllowance`. `RULE_SEMANTICS.md` already had the correct matrix row for all of them; the README sections now link to it.

- **`RuleMintAllowance`'s non-authoritative views are documented one level up** (`CLAUDE_ANALYSIS.md` F-6). `canTransfer` / `detectTransferRestriction` are hardcoded to "allowed" because the 3-argument signature carries no minter identity — already documented for the rule itself (`CLAUDE_AUDIT.md` F-7). What was missing is that the answer **propagates**: `RuleEngineBase` aggregates by calling each rule's 3-argument view, and CMTAT's `ValidationModuleERC1404` forwards the token's ERC-1404 views to the engine, so `ruleEngine.canTransfer` and `cmtat.canTransfer` report a mint as allowed that then reverts. The token is the address integrators actually call, so the audience most likely to be misled was the one furthest from the existing warnings.
  - `doc/technical/contracts/RuleMintAllowance.md` gains a per-entrypoint table covering the engine and token levels, and a callout naming `cmtat.detectTransferRestrictionFrom(minter, address(0), to, value)` as the authoritative pre-flight for anyone holding only the token address.
  - `README.md` gains a *Views that are not authoritative* section covering `RuleMintAllowance` and `RuleConditionalTransferLightMultiToken` together, with the propagation mechanism and why returning a restriction code instead would be worse — ERC-1404 has no "cannot answer" value, so the token would report every mint as forbidden, including those that will succeed.
  - **Behaviour unchanged; no Solidity modified.**
- **The approval-key preimage is documented, and the comment that described it wrongly is fixed** (`CLAUDE_ANALYSIS.md` F-4). `_transferHash` hashes a project-specific encoding — 32-byte words with each address **left**-aligned and right-padded — which is neither `abi.encodePacked` (72 bytes, unpadded) nor `abi.encode` (96 bytes, right-aligned). The inline comment said "hash packed values", pointing anyone reimplementing the key off-chain at the wrong encoding; because the result is a mapping key the mistake is **silent**, reading `0` and looking exactly like "no approval exists".
  - NatSpec on both rules now gives the word-by-word layout, the warning, and two formulations that reproduce the key: `keccak256(abi.encodePacked(from, bytes12(0), to, bytes12(0), value))` and `keccak256(abi.encode(bytes32(bytes20(from)), bytes32(bytes20(to)), value))`. The multi-token variant is the same shape with `token` prepended (128 bytes).
  - It also points readers at `approvedCount`, which resolves `(from, to, value)` directly — the hash is only needed to derive the storage slot for `eth_getStorageAt`, a state proof, or an indexer reading storage rather than events.
  - **The assembly is unchanged.** It is on the transfer write path and ~109 gas cheaper per call than `abi.encodePacked` (1,032 vs 1,141, measured with each variant in its own single-function contract), its injectivity is verified in `CLAUDE_AUDIT.md` F-12, and switching encodings would change every storage key — orphaning outstanding approvals in any deployed instance.
- **The batch-operation convention is documented accurately** (`CLAUDE_ANALYSIS.md` F-5). Every add path in the library rejects `address(0)`, batch included, but the documentation said the opposite in three places: `CLAUDE.md` / `AGENTS.md` invariant I-12 claimed "single adds revert, batch adds skip it"; the Conventions list claimed "batch add/remove operations are non-reverting" without qualification; and `README.md` repeated that in the ERC-2980 section — while contradicting itself in the static-analysis triage table, which already recorded that batch adds revert on the sentinel on purpose. The NatSpec on all six batch-add functions documented only the duplicate-skipping half. All corrected; **no Solidity behaviour changed** — the code is deliberate and its inline reasoning was already right.
  - New `README.md` section *Zero address in batch operations*: a single-vs-batch behaviour table, why the sentinel is rejected rather than skipped (the batch event echoes the input array, so skipping would name a non-member as a member), and the operational consequence — a batch containing one zero entry is rejected whole rather than partially applied.
- **Contract code no longer references the technical documentation.** Four NatSpec comments in `src/` cited a `doc/technical/` page; the substance of each was written into the comment and the pointer removed (`RuleMaxBalance`, `RuleMaxBalanceOwnable2Step`, `RuleMaxBalanceBase`, `TokenSupplyReader`). The rule is now a project convention in `CLAUDE.md` / `AGENTS.md`: documentation paths move — the split above rewrote those same four comments the day after they were written — and a stale pointer inside a deployed contract's verified source cannot be fixed by editing the docs. `src/mocks/` is exempt, and audit reports remain citable by bare filename, being immutable records whose finding IDs carry context a comment cannot restate.

- **`doc/technical/` is split in two.** Per-contract pages moved to [`doc/technical/contracts/`](./doc/technical/contracts/) (16 files) and the cross-cutting material to [`doc/technical/guides/`](./doc/technical/guides/) (`RULE_SEMANTICS.md`, `INVARIANT_TESTS.md`, `DEPLOYMENT_SCRIPTS.md`). The directory had grown to 19 files with no signal about which were per-contract reference and which spanned the whole library. **Every link into it changes**: 67 links inside the moved pages and 86 inbound references across the READMEs, CHANGELOG, agent guides, audit reports and source comments were rewritten, and all resolve.
  - `RuleConditionalTransfer.md` was **orphaned** — nothing linked to it, including the doc index, so it was reachable only by browsing. It documents a rule maintained in a separate repository and is now listed in the index with that caveat rather than left unreferenced.

- **The README is split in two.** `README.md` at the repository root is now a short summary — purpose, compatibility, architecture, the rule table, quick start, ERC-3643 integration, security tooling — and the full reference moved to [`doc/README.md`](./doc/README.md), unchanged in content. **Any deep link into the old root README's anchors now resolves against `doc/README.md` instead.** Rationale: the root file had grown to ~1 950 lines, which is a reference manual rather than a front page. `doc/script/convert_links_for_pdf.sh` was repointed at `doc/README.md` accordingly.
- **The architecture diagrams are PlantUML, with sources committed.** The root README's ASCII topology block and `doc/README.md`'s two drawio images (`Rule-RuleEngine.drawio.png`, `Rule-Rule.drawio.png`) are replaced by rendered diagrams whose `.puml` sources live in [`doc/schema/`](./doc/schema/), so they can be regenerated and diffed. Each now carries a written description of the call sequence.
  - **One of them was wrong.** The old direct-binding image showed an ERC-3643 token calling a bare rule, which the surrounding text already contradicted: a validation rule implements no `created` / `destroyed`, so it cannot back an ERC-3643 token. The replacement marks that path as unsupported and points to the RuleEngine topology.
  - Both topology diagrams now show **both `transferred` overloads** — the 3-argument form for a plain `transfer()` and the 4-argument spender form for `transferFrom`, mint and burn — rather than only the 4-argument one.
  - New ERC-3643 section in **both** READMEs covering the two pluggable slots. The identity material is organised by **what the token has** rather than by preference: an ERC-3643 token takes `IdentityRegistryWhitelist` directly in its identity slot, while CMTAT has no such slot, which is why `RuleIdentityRegistry` behind a RuleEngine is the only route there rather than one option among several. The corollary is stated explicitly — on ERC-3643, adding the rule on top of a registry the token already consults screens the same wallets twice and adds no restriction.
  - `doc/technical/contracts/RuleIdentityRegistry.md` and `doc/technical/contracts/IdentityRegistryWhitelist.md` each gain a *when this applies* callout for the same reason: both described what the contract **is**, neither said which token standard it suits.
- `CLAUDE.md` / `AGENTS.md`: the toolchain section now records **where** the ONCHAINID remapping is declared and why it must not go back into `remappings.txt`.
- `doc/technical/contracts/RuleWhitelistWrapper.md`: the scan snippet in *Gas cost of the child-rule scan* now matches the implementation, with a note that the published cost table is a marginally conservative upper bound after the change.

### Testing

- New `test/ERC3643Real/ERC3643RealTokenRuleEngine.t.sol` — the same **ERC-3643 token → RuleEngine → RuleWhitelist** wiring, but against the **real vendored `Token.sol`** rather than a mock, so nothing in it is transcribed. 12 tests covering mint, transfer, transferFrom, forcedTransfer and burn, asserting the token's own `ComplianceNotFollowed` / `TransferNotPossible` errors and the rule's `RuleWhitelist_InvalidTransfer` codes.
  - Requires its own Foundry profile: `Token.sol` pins `pragma solidity 0.8.30` exactly, which cannot share a compilation unit with the project's 0.8.36. `test/ERC3643Real/**` is skipped by the default profile and built by `[profile.erc3643]`. **CI must run both `forge test` and `FOUNDRY_PROFILE=erc3643 forge test`.**
  - The `lib/ERC-3643` submodule moves from 4.1.3 to **4.2.0-beta1**; 4.1.3 pins `0.8.17`, which cannot compile alongside our `^0.8.20` contracts at all. Nothing in `src/` imports ERC-3643, so the bump affects tests only.
  - Adds minimal `IIdentity` / `IClaimIssuer` stubs under `test/utils/onchainid/`, wired by a context-scoped remapping, because ONCHAINID is an npm dependency rather than a submodule.
- New `test/ERC3643Compliance/ERC3643RuleEngineWhitelist.t.sol` — an ERC-3643 token wired to a `RuleEngine` as its **compliance** contract (`setCompliance`), enforcing `RuleWhitelist`: **ERC-3643 token → RuleEngine → RuleWhitelist**. Covers `mint`, `transfer`, `transferFrom`, `forcedTransfer` and `burn`, and pins that the compliance slot and the identity-registry slot block independently — an address verified by the registry but absent from the rule is rejected, and vice versa. Exercises the `setTokenSelfBindingApproval` path that exists in `ERC3643ComplianceExtendedModule` for ERC-3643 self-binding.
- `ERC3643TokenMock` gained an optional compliance slot, with `canTransfer` / `transferred` / `created` / `destroyed` / `bindToken` call sites transcribed from `Token.sol`. Optional so the identity-registry suites keep running without an engine.

- 79 new tests across unit, decimal-scaling, Ownable2Step access-control, and CMTAT + RuleEngine end-to-end suites, including a full-domain fuzz asserting the read path never reverts. 100% line coverage on both deployment variants.
- Decimal-scaling suite covering token decimals 0 / 6 / 18 against feed decimals 0 / 8 / 18 / 36, the truncation behaviour at `tokenDecimals == 0`, and a fuzz cross-checking `_scaleReserve` against `answer * 10**tokenDecimals / 10**feedDecimals` computed with full-precision `mulDiv`.

- New `test/RuleConditionalTransferLight/Ownable/ConditionalTransferOwnable2StepBindingAuthorization.t.sol` (7 tests) — owner-only authorization on both `Ownable2Step` conditional-transfer variants, which had **no access-control coverage at all**: the only test naming `RuleConditionalTransferLightMultiTokenOwnable2Step` was an ERC-165 support check. Three concrete overrides were unexercised (`_authorizeComplianceBindingChange` on the single-token variant, `_onlyComplianceManager` and `_authorizeTransferApproval` on the multi-token one); both contracts are now at 100% lines, statements and functions. Note which entrypoint reaches which hook: `RuleConditionalTransferLightBase` overrides `bindToken` with its own `onlyComplianceManager`, so on the single-token rule the only route to `_authorizeComplianceBindingChange` is the inherited `unbindToken`.
- New `test/RuleMaxBalance/Ownable/RuleMaxBalanceOwnable2Step.t.sol` (10 tests) and two gap-filling unit tests, bringing `RuleMaxBalanceBase` to **100% statements and 100% branches** and both deployment variants to 100% across the board. The two gaps were a token with code whose `balanceOf` reverts (the `catch` in `_setBalanceToken`, unreachable from the mock's default state) and the second operand of `supportsInterface`, which a query for `IERC165` short-circuits past — it needs `IRULE_INTERFACE_ID`, which only `RuleTransferValidation` answers. The single remaining uncovered line is the abstract `_authorizeMaxBalanceManager` declaration, which no test can execute because only the override runs.
- New `test/RuleConditionalTransferLight/Ownable/ConditionalTransferOwnable2StepBindingAuthorization.t.sol` (7 tests) — owner-only authorization on both `Ownable2Step` conditional-transfer variants, which had **no access-control coverage at all**. Note which entrypoint reaches which hook: `RuleConditionalTransferLightBase` overrides `bindToken` with its own `onlyComplianceManager`, so on the single-token rule the only route to `_authorizeComplianceBindingChange` is the inherited `unbindToken`.
- `test/Version.t.sol` extended to the two new deployable contracts, keeping it exhaustive per the project convention.
- New `test/Events/BatchEventEffect.t.sol` (9 tests) for the batch-event counters, pinning the case the input array could never express — a batch that is partly or wholly a no-op — for both the shared `RuleAddressSet` machinery and `RuleERC2980`'s separate copy of the same loops, plus a fuzz case asserting `added + skipped == input.length`.
- **Three assertions in `test/RuleWhitelist/RuleWhitelistRemove.t.sol` were not assertions.** They contained bare `emit IAddressList.AddAddresses(...)` statements with no preceding `vm.expectEmit`, so they emitted an event from the test contract and checked nothing; the arity change surfaced them. They now use `vm.expectEmit`, and the most useful of them checks a 3-address removal where only 2 were present — `(removed = 2, skipped = 1)`.
- New `script/DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply.s.sol` — a CMTAT behind a RuleEngine enforcing three rules: `RuleBlacklist`, `RuleSanctionsList` and `RuleMaxTotalSupply`. Documents the two constraints this combination introduces that the two-rule script does not: `RuleMaxTotalSupply` validates its token at construction, so it must be deployed **after** the token; and one instance protects one token, so it must not be shared across RuleEngines.
  - **Takes the acting `deployer` as an explicit parameter instead of reading `address(this)`.** The two execution contexts disagree about who makes the wiring calls — the broadcaster under `forge script`, the script contract under test — and Foundry rejects `address(this)` inside a broadcast outright ("script contracts are ephemeral"). The three pre-existing deployment scripts all read `address(this)` and therefore **revert under `forge script`**, passing their tests only because those call `deploy()` directly; they are unchanged here and still need that fix.
- New `test/DeploymentScripts/DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply.t.sol` (19 tests) covering wiring, the admin hand-over (including that the deployer retains nothing), each rule enforcing alone, and the behaviour only the three together produce: which restriction code is reported when several rules object, an address rule blocking a mint the cap would have allowed, the cap leaving ordinary transfers untouched, and burning freeing headroom for a new mint.
- New `test/ERC3643Real/RuleIdentityRegistryWithRealERC3643Registry.t.sol` (13 tests) — `RuleIdentityRegistry` consulting the **genuine ERC-3643 `IdentityRegistry`** vendored in `lib/ERC-3643`, with its real `IdentityRegistryStorage`, `ClaimTopicsRegistry` and `TrustedIssuersRegistry` behind it. Nothing in the repo built the reference registry before: the existing `ERC3643Real` suites plug `IdentityRegistryWhitelist` into `Token.sol`'s identity slot precisely to avoid ONCHAINID. Covers both regimes `isVerified` takes a different path through — no required claim topics (registered ⇒ verified, ONCHAINID never touched) and one required topic (topic iteration, trusted-issuer resolution, claim read, issuer validation) — plus claim revocation, an untrusted issuer, `deleteIdentity`, the receiver-only default, both opt-in flags, and mint/burn sentinel handling.
  - Required extending the ONCHAINID stubs under `test/utils/onchainid/`: the reference `IdentityRegistry` does not compile against them, because `isVerified` calls `getClaim` on the investor's identity and `isClaimValid` on the issuer, and the stubs declared only `keyHasPurpose`. Both members are now declared, keeping the "only the slice genuinely used" doctrine those files were written under.
  - New `test/ERC3643Real/utils/OnchainIdClaimMocks.sol`. **Limitation, stated in the file:** the mocks implement `getClaim` and `isClaimValid` only — the *registry's* logic runs for real, ONCHAINID's does not. No signature verification, key management or revocation.
- New `test/IdentityRegistryWhitelist/CMTATRuleIdentityRegistryComposition.t.sol` (13 tests) — the two halves of the identity story working together: `RuleIdentityRegistry` *consults* a registry, `IdentityRegistryWhitelist` *is* one, so the chain `CMTAT -> RuleEngine -> RuleIdentityRegistry -> IdentityRegistryWhitelist` is now covered end to end. Until now each half was tested only against the other side's stand-in — the rule against `IdentityRegistryMock`, the registry inside an **ERC-3643** token's identity slot. **CMTAT has no `setIdentityRegistry` slot**, so this chain is the only way a CMTAT token can use `IdentityRegistryWhitelist` at all. Covers mint / transfer / transferFrom / burn, the unregistered-recipient rejections, that an unregistered *minter* may still mint (ERC-3643), that a de-listed holder can still exit but not receive (invariant I-1), that `isVerified(address(0))` stays false without breaking mint or burn (I-12), and both `checkSender` / `checkSpender` opt-ins against a real registry rather than a mock.
- New `test/RuleConditionalTransferLight/TransferHashPreimage.t.sol` (4 tests) pinning the documented approval-key preimage for both conditional-transfer rules. They assert the documented formulations against the contract's own public `approvalCounts(bytes32)` getter — the real storage key — rather than against a reimplementation of the assembly, so the NatSpec and the code cannot drift apart. Two of them assert the negative case: the two standard encodings must **not** produce the key.
- New `test/Events/ConstructorEvents.t.sol` (7 tests) for the three changes above, matching on `topic0` rather than `vm.expectEmit` so a wrong *number* of emissions is caught as well as a missing one. Four of the seven fail against the previous implementation — verified by reverting each change and re-running. It also pins `RuleChainlinkPoR`, which was already correct and is the rule the others were made to match, so the convention cannot regress from the other direction.
- New `test_MA1_EngineAndTokenInheritTheHardcodedAllowedView_CurrentBehaviour` in `test/ThreatModel/ThreatModelTests.t.sol`, wiring `RuleMintAllowance` into a real `RuleEngine` inside a real CMTAT and asserting the hardcoded "allowed" at both the engine and token levels, the real answer from the 4-argument chain at both levels, and that the mint then reverts. Per the `_CurrentBehaviour` convention it asserts behaviour the audit considers wrong: closing the gap must make it fail. Verified as a genuine guard by temporarily returning a restriction code from the 3-argument view, which fails it with `70 != 0`.
- New `testBatchAddRejectsZeroAddressAndAppliesNothing` and `testBatchAddStillSkipsDuplicates` in `test/RuleERC2980/RuleERC2980.t.sol`. The batch zero-address revert was covered only for `RuleAddressSetInternal`; `RuleERC2980` keeps its own copy of that guard, so its two batch adders had no coverage. The first test also pins that the batch is atomic — valid entries either side of the sentinel are not applied.
- New `test/RuleSanctionsList/RuleSanctionsListDelegation.t.sol` (6 tests) and `src/mocks/harness/SanctionsListDelegationHarness.sol` for the `transferFrom` delegation fix. The harness is a subclass adding an oracle-independent check — the shape that exposes the defect. Two tests fail against the previous structure; the other four pin that the spender check still short-circuits ahead of the delegation and that base screening is untouched.
- New `test/RuleSanctionsList/RuleSanctionsListMintBurnSentinel.t.sol` (8 tests) for the change above. The oracle in it deliberately sanctions `address(0)`; four of the tests fail against the previous implementation (mint blocked with code `30`, burn with `31`, and the write path reverting), while the four asserting unchanged behaviour pass either way — verified by reverting the guards and re-running.
- New `test/VirtualHooks/VirtualHookOverride.t.sol` and `src/mocks/harness/VirtualHookOverrideHarnesses.sol`, guarding the `virtual` convention above. The harnesses override the previously-unoverridable hooks, so removing `virtual` fails the build with *"Trying to override non-virtual function"*; the tests then assert the overrides are actually reached — a custom executor policy authorizes a caller the base policy rejects, `super` still returns the base blacklist code, and both overridden `canTransfer` overloads answer `false` while the underlying restriction hook still says `TRANSFER_OK`. For E-3 the coverage is **representative, not exhaustive** — one override per family (address-set write, ERC-2980 list write, configuration setter, approval write, `transferred` hook), each asserted to run and to still reach `super`. `virtual` is applied per function, so 21 of the 27 have no compile-time guard; exhaustive harnesses were judged bulk without signal.
- New `testDetectTransferRestrictionOkWhenAddressListedInSeveralChildRules` in `test/RuleWhitelist/WhitelistWrapper.t.sol`. Branch coverage of `RuleWhitelistWrapperBase.sol` stays at 100% (19/19) with the added condition.
- New `testApproveTransfer_EmitsPostIncrementCount` (`test/RuleConditionalTransferLight/RuleConditionalTransferLightUnit.t.sol`) and `test_ApproveTransferEmitsPostIncrementCount` (`test/RuleConditionalTransferLightMultiToken/MultiTokenSurface.t.sol`). The approval-counter change is pure codegen with identical event data, but **no test asserted the `TransferApproved` payload at all** — the suites only checked `approvedCount()`. Both new tests approve the same transfer twice and require the event to report 1 then 2, so a pre-increment or uninitialised value would now fail.

## v0.4.0 - 2026-07-14

Commit: `44cec0ebc7d9eba7644f9f4d1c52e832e2791369`

### Summary

Two new rule families, two standards-conformance fixes, and hardening from an internal review.

**New rules**
- **`RuleMintAllowance`** — a per-minter mint quota. The operator sets an absolute quota (or increments/decrements it) and each mint debits the minter's allowance. It is the only rule keyed on the mint `spender`, so it requires the spender-aware CMTAT/RuleEngine callback path. Restriction code `70`.
- **`RuleConditionalTransferLightMultiToken`** — conditional transfers with approvals keyed by `(token, from, to, value)`. **Direct-binding only:** it must not be added to a `RuleEngine`.

**Breaking: two standards-conformance fixes.** Both change default behaviour and require deployer action — see *Changed* for the migration steps.
- **`RuleIdentityRegistry` now follows ERC-3643 and verifies only the RECEIVER.** It previously screened the sender, the spender and the minter. The sender check was the damaging one: it *trapped de-listed holders*, who could neither receive nor send, when the spec checks only the receiver precisely so a lapsed investor can still exit their position. Stricter screening survives as opt-in `checkSender` / `checkSpender` flags, both defaulting to `false`.
- **Mint/burn permission is now an explicit `allowMint` / `allowBurn` flag**, not membership of `address(0)`. Enabling mint/burn by whitelisting the zero address made mandatory getters lie — `isVerified(address(0))` and `RuleERC2980.whitelist(address(0))` both returned `true` — and made `removeAddress(address(0))` silently halt all issuance. The zero address can no longer enter any list. New codes `24`/`25` and `64`/`65` say "minting is not allowed" instead of the misleading "sender is not whitelisted".

**Usability and operations**
- `RuleConditionalTransferLight` **works behind a `RuleEngine`**: `bindToken` (the ERC-20 target) and the new `bindRuleEngine` (the authorized caller) are now separate roles, which fixes `approveAndTransferIfAllowed`.
- Caller-explicit pre-flight views (`detectTransferRestrictionForToken` / `canTransferForToken`) so a wallet or explorer gets a truthful answer from the multi-token rule.
- Stale-state cleanup after rebinding: `resetApproval(...)` and `clearMintAllowances(...)`.
- Overflow-safe supply-cap views — they return code `50` instead of reverting with an arithmetic panic.

**Internal review.** An AI-assisted, test-backed review of `src/` reported 0 Critical/High/Medium, 2 Low and 8 Informational findings; see [`CLAUDE_AUDIT.md`](./doc/security/audits/tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md). This is **not** a formal third-party audit, and the project has not had one. Test suite grew 425 → **511 tests** (97.8% line, 97.3% branch coverage) and now includes a stateful, mutation-verified invariant suite.

### Added

- `RuleConditionalTransferLight`: **split the binding into two independent roles**, so the rule works fully behind a `RuleEngine`. New `bindRuleEngine(address)` / `unbindRuleEngine()` (compliance-manager gated, emitting `RuleEngineBound` / `RuleEngineUnbound`) authorise a RuleEngine to call the transfer execution hooks, while `bindToken` continues to designate the **ERC-20 token** the rule acts on. `transferred` now accepts a call from either the bound token or the bound RuleEngine (new `isTransferExecutor(address)` view). This fixes `approveAndTransferIfAllowed`, which was previously unusable behind a RuleEngine: the single binding slot had to be *both* the ERC-20 target and the authorised caller, and behind an engine those are different addresses — binding the engine broke the helper (an engine is not an ERC-20) while binding the token left the engine unauthorised and reverted every transfer and mint. Backward compatible: existing direct-binding deployments are unaffected, and a deployment that binds the engine via `bindToken` keeps working as before (though it should migrate to use both bindings). See finding F-3.
- `RuleConditionalTransferLightMultiToken`: new caller-explicit pre-flight views `detectTransferRestrictionForToken(token, from, to, value)` and `canTransferForToken(token, from, to, value)`. The standardized ERC-1404 / ERC-3643 views (`detectTransferRestriction`, `canTransfer`) derive the token key from `msg.sender`, so an off-chain `eth_call` from a wallet or explorer always read "not approved" even for an approved transfer; the new views take the token explicitly and give every caller the real answer. Additive — the standardized signatures are unchanged, and both paths are backed by the same internal helper so they can never disagree for the bound token.
- ERC-165: `RuleWhitelist`, `RuleBlacklist`, `RuleSpenderWhitelist` (and their `Ownable2Step` variants) now advertise the `IAddressList` interface (`0x5d10e182`). Purely additive — no call is rejected. This is the prerequisite for `RuleWhitelistWrapper` to interface-check its child rules (improvement I-4, finding F-5). Adds `AddressListInterfaceId` (pre-computed constant) and `IAddressListInterfaceIdHelper` (flattened interface used to derive it): `type(IAddressList).interfaceId` cannot be used, because it omits `contains(address)` inherited from `IIdentityRegistryContains`. `RuleWhitelistWrapper` deliberately does **not** advertise it — it exposes no address set of its own, so a wrapper cannot be nested inside another wrapper.
- `RuleConditionalTransferLight` / `RuleConditionalTransferLightMultiToken`: new `resetApproval(...)` operator function that discards **every** outstanding approval for a transfer key in one call (returns the cleared count, emits `TransferApprovalReset`). It deliberately does **not** require a bound token, so it can clean up approvals that survived an `unbindToken` — and, for the multi-token rule, approvals stranded under a key that can never be consumed.
- `RuleMintAllowance`: new `clearMintAllowances(address[] calldata minters)` operator function that zeroes the listed minters' quotas (non-reverting batch), for discarding stale quotas before rebinding.
- `RuleConditionalTransferLightMultiToken` and `RuleConditionalTransferLightMultiTokenOwnable2Step` — multi-token conditional transfer rules with token-scoped approvals keyed by `(token, from, to, value)`.
- `RuleMintAllowance` and `RuleMintAllowanceOwnable2Step` — operation rule enforcing a per-minter mint quota managed by an operator. Each mint reduces the minter's allowance; the operator can set an absolute quota or increment/decrement it. Regular transfers and burns are not restricted. Restriction code 70 (`CODE_MINTER_ALLOWANCE_EXCEEDED`).

### Fixed

- `RuleMaxTotalSupply`: `detectTransferRestriction` / `canTransfer` / `detectTransferRestrictionFrom` no longer revert with an arithmetic panic when `currentSupply + value` would overflow `uint256`. The mint check now compares against the remaining headroom (`value > maxTotalSupply - currentSupply`), so these ERC-1404 / ERC-3643 views always return a restriction code as required. Enforcement (`transferred`) is unchanged.

### Changed

- **BREAKING — `RuleIdentityRegistry` is now ERC-3643 conformant: only the RECEIVER is verified.** The rule previously screened the sender, the spender **and** the minter. The specification mandates none of those — *"The receiver MUST be whitelisted on the Identity Registry and verified"*; *"`transferFrom` works the same way"*; *"`mint` and `forcedTransfer` only require the receiver"*; *"The `burn` function bypasses all checks on eligibility"*.
  - **The sender check was the most damaging.** ERC-3643 screens only the receiver precisely so that an investor whose identity lapses (expired claim, revoked identity) can still **exit their position** by sending to a verified counterparty. Screening the sender trapped de-listed holders: they could neither receive nor send.
  - It also fixes finding **F-1**: an unverified minter can now mint to a verified recipient, as the spec requires (previously reverted with `CODE_ADDRESS_SPENDER_NOT_VERIFIED`).
  - Stricter screening remains available as an **explicit opt-in**: new `checkSender` / `checkSpender` flags (constructor parameters, plus `setCheckSender(bool)` / `setCheckSpender(bool)`, emitting `IdentityCheckSenderUpdated` / `IdentityCheckSpenderUpdated`). Both default to `false` — the conformant behaviour. Mint and burn stay exempt from the spender check even when `checkSpender` is on.
  - **Constructor:** `RuleIdentityRegistry(admin, identityRegistry, checkSender, checkSpender)` — pass `false, false` for the ERC-3643 default.
  - **Deployer migration:** a deployment relying on the old (stricter) behaviour must pass `true, true` to preserve it. No restriction codes changed.
- **BREAKING — `RuleWhitelist`, `RuleWhitelistWrapper`, `RuleERC2980`: mint/burn permission is now an explicit flag, not membership of `address(0)`.** Previously these rules enabled mint/burn by *whitelisting the zero address*, which made the standardized identity getters assert falsehoods: `isVerified(address(0))` returned `true` (ERC-3643 defines `isVerified` as "is this wallet a valid investor holding the required claims" — the zero address is not a wallet), and `RuleERC2980.whitelist(address(0))` returned `true` (a **mandatory** ERC-2980 getter). It also meant `removeAddress(address(0))` silently disabled all minting and burning.
  - New state: `allowMint` / `allowBurn`, with `setAllowMint(bool)` / `setAllowBurn(bool)` (admin/owner gated, emitting `AllowMintUpdated` / `AllowBurnUpdated`), so issuance can still be permanently closed at runtime while redemptions stay open.
  - New restriction codes: `RuleWhitelist` / `RuleWhitelistWrapper` → `24` (`CODE_MINT_NOT_ALLOWED`) and `25` (`CODE_BURN_NOT_ALLOWED`); `RuleERC2980` → `64` / `65`. A blocked mint now reports "minting is not allowed" instead of the misleading "sender is not whitelisted".
  - The zero address can no longer enter any list: both single **and batch** adds revert (`RuleAddressSet_ZeroAddressNotAllowed` / `RuleERC2980_ZeroAddressNotAllowed`). This is the one input a batch does not skip — see the batch note below.
  - **Constructors:** `RuleWhitelist(admin, forwarder, checkSpender, allowMintBurn)` keeps its shape — `allowMintBurn` now sets *both* flags instead of whitelisting `address(0)`. `RuleWhitelistWrapper` gains an `allowMintBurn` parameter (it holds no addresses of its own and must decide mint/burn itself). `RuleERC2980`'s third parameter is renamed `allowBurn` → `allowMintBurn` and now governs both operations.
  - **Deployer migration:** a deployment that enabled mint/burn by whitelisting `address(0)` must instead pass `allowMintBurn = true` (or call the setters). Permission semantics are otherwise unchanged: a permitted mint still requires a whitelisted **recipient**, and a permitted burn still requires a whitelisted **sender**.
  - **Batch adds reject `address(0)` rather than skipping it.** The batch convention still skips *duplicates* (an idempotent no-op the emitted event describes truthfully), but silently dropping the sentinel would make `AddAddresses` / `AddWhitelistAddresses` / `AddFrozenlistAddresses` report a member that is not in the set — re-polluting, off-chain, the very view this change cleans up on-chain.
  - **Removed capability (`RuleBlacklist` / `RuleSpenderWhitelist`):** these rules inherit the same address set, so blacklisting `address(0)` — which previously acted as an undocumented "halt all issuance" kill switch, since a mint has `from == address(0)` — is no longer possible. They did **not** receive `allowMint` / `allowBurn` flags: a deny-list has no legitimate reason to list the sentinel, and issuance is better halted at the token (CMTAT pause/deactivate) or with an allow-list rule. If you relied on that idiom, migrate before upgrading.
- Access-control hooks: **all `_authorize*()` / `_only*()` hooks are now `internal view virtual`**, both the abstract declarations and every override. An authorization hook checks and reverts; `view` makes "authorization never mutates state" a compiler-enforced invariant rather than a convention. Compile-time only — `view` on an `internal` function has no gas or runtime impact. Normalised `RuleWhitelistWrapperBase._authorizeCheckSpenderManager` (declaration), the three `RuleWhitelistWrapper` overrides (which disagreed with their own `Ownable2Step` twin), and the six `_onlyComplianceManager` overrides across the operation rules. The convention is now recorded in `CLAUDE.md`/`AGENTS.md`. One documented exception remains: `RuleConditionalTransferLightMultiTokenBase._authorizeComplianceBindingChange` delegates to `_onlyComplianceManager()`, which `lib/RuleEngine` declares non-`view`, and Solidity checks mutability against a virtual's declared type — it can only become `view` once that is changed upstream.
- `RuleSpenderWhitelist` / `RuleSpenderWhitelistOwnable2Step`: remove a dead `RuleTransferValidation` import. The symbol was referenced nowhere in either file (not in the inheritance list, an `override(...)` specifier, or a body). Cosmetic — no bytecode or behavioural change. Surfaced by Aderyn 0.6.5 (`Unused Import`) in the post-remediation re-run.
- `RuleERC2980`: split the shared list-management errors into per-list errors so a revert identifies which list rejected. `RuleERC2980_AddressAlreadyListed` becomes `RuleERC2980_AddressAlreadyWhitelisted` / `RuleERC2980_AddressAlreadyFrozen`, and `RuleERC2980_AddressNotFound` becomes `RuleERC2980_AddressNotWhitelisted` / `RuleERC2980_AddressNotFrozen`. **Breaking (ABI):** the removed errors' 4-byte selectors no longer exist; off-chain tooling matching on them must update.
- Update contract version in `VersionModule` to `0.4.0`.
- Ownable2Step rule deployments now explicitly advertise ERC-165 `IERC165` (`0x01ffc9a7`), ERC-173 (`0x7f5828d0`), and Ownable2Step (`0x9ab669ef`) interface IDs.
- `RuleMintAllowance` now enforces single-target binding like `RuleConditionalTransferLight`: a second `bindToken` call reverts with `RuleMintAllowance_TokenAlreadyBound` until the current RuleEngine/token is unbound.
- `RuleMintAllowance` no longer advertises the full ERC-3643 `ICompliance` interface through ERC-165 because its mint quota requires spender-aware callbacks.

### Dependencies

- Update RuleEngine to `v3.0.0-rc4`. Role constants were isolated into dedicated storage contracts (`RulesManagementModuleRolesStorage`, `ERC3643ComplianceRolesStorage`); concrete rules that reference `RULES_MANAGEMENT_ROLE` / `COMPLIANCE_MANAGER_ROLE` now inherit the corresponding storage contract.

### Documentation

- `RuleConditionalTransferLightMultiToken`: document that the rule is **direct-binding-only** and **must not be added to a `RuleEngine`**. Approvals are recorded under the `token` argument but consumed under `msg.sender`, so behind an engine every wiring either reverts or silently loses per-token isolation. Added a "Deployment topology" section with the exhaustive case analysis to `doc/technical/contracts/RuleConditionalTransferLightMultiToken.md`, documented the caller-dependent `detectTransferRestriction`, and propagated the constraint to the README binding-model table, `RULE_SEMANTICS.md` and the project guide.
- `RuleWhitelistWrapper`: document the child-rule scan cost model and publish operator guidance. The wrapper makes one external `STATICCALL` per child (**~8.8k gas each**) and the scan runs during transfer *execution*, so it is paid by the transferring user on every transfer — not only in views. At the default `maxRules = 10` the worst case is ~90k gas per transfer (~121k with `checkSpender`). Two amplifiers are documented: a transfer that will be *rejected* never early-exits and therefore always scans all children, and `checkSpender = true` adds a third target address that must also be resolved. The scan is linear (marginal cost measured flat at ~8.8k gas/child from 25 to 200 children). Guidance: keep the child list at or below the default cap, order children by expected hit rate, and treat raising `maxRules` as a permanent per-transfer cost on every holder (a cap of 100 ⇒ ~884k gas/transfer, measured). This is a cost problem rather than a liveness one — transfers still fit in a block until roughly 3,400 children. The list size remains the **operator's responsibility**; no lower cap is hard-coded.
- Add `doc/technical/guides/INVARIANT_TESTS.md` — documents the stateful invariant suite: handler architecture and ghost variables, each of the four invariants and what it proves, the mutation-testing negative controls, the coverage map against the threat-model invariants, and how to add a new invariant. Linked from a new "Invariant testing" section in the README.
- Add `doc/technical/guides/RULE_SEMANTICS.md` — a per-rule comparison table (who each rule screens for `from` / `to` / spender on `transferFrom` / mint / burn, behaviour when the oracle/registry is unset, stateful?, and which pre-flight view is authoritative), with a highlights summary and link added to the README.
- `RuleMintAllowance`: document that `canTransfer` / `detectTransferRestriction` are **not authoritative** (hardcoded to "allowed" because the 3-arg path has no minter identity) and that a mint pre-flight must use the spender-aware `canTransferFrom(minter, address(0), to, value)` / `detectTransferRestrictionFrom`. Added a bold callout and an eligibility-views table to `doc/technical/contracts/RuleMintAllowance.md` and a warning to the README rule section.
- Add [`CLAUDE_AUDIT.md`](./doc/security/audits/tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md) — the published AI-assisted security audit report for `v0.4.0` (0 Critical/High/Medium, 2 Low, 8 Info), with invariant verification, access-control verification, the remediation record and the open improvement backlog. Backed by internal working deliverables (threat model, findings, test-gap analysis) plus Slither call-graph / inheritance / function-summary comprehension artifacts.
- Add a "Manual Threat Model & Review" section to `README.md`.
- `CLAUDE.md` / `AGENTS.md`: correct the version string to `0.4.0`, document the two integration topologies and the CMTAT v3.3+ mint `spender` convention, and add the missing `RuleMintAllowance`, `RuleConditionalTransferLightMultiToken`, `RuleNFTAdapter` and restriction code `70` entries.
- Added technical documentation: `doc/technical/contracts/RuleConditionalTransferLightMultiToken.md`.
- Updated README operation-rule sections and tables to include `RuleConditionalTransferLightMultiToken`.
- Added technical documentation: `doc/technical/contracts/RuleMintAllowance.md`.
- Updated restriction code table, rule index, role summary, and Ownable2Step list in README.
- Documented that `RuleMintAllowance` does not work with pure ERC-3643 3-arg mint callbacks; it requires the spender-aware CMTAT/RuleEngine path.

### Testing

- Add `test/TransferContext/OverloadParity.t.sol` — asserts overload parity across all 7 rules that inherit `RuleNFTAdapter`: every ERC-7943 `tokenId` overload returns exactly what its fungible counterpart returns (`tokenId` is ignored by design), the write overloads accept/reject identically, and the `ITransferContext` struct entrypoints dispatch to the same internal hooks. Closes the per-rule gap for `RuleBlacklist`, `RuleSanctionsList`, `RuleERC2980` and `RuleIdentityRegistry`, and pins threat `AC-5` (the `ctx` entrypoints are unguarded but view-only on validation rules, so they mutate nothing).
- Add `test/invariant/` — the project's first stateful invariant suite (`StdInvariant`, `fail_on_revert = true`). Handler-driven fuzzing over the two stateful rules: `RuleConditionalTransferLight` (approval conservation, `INV-5`) and `RuleMintAllowance` (exact quota accounting via a ghost mirror, `INV-7`). 4 invariants × 8 192 calls each, 0 reverts. The handlers also prove mint/burn never consume an approval and that non-mint transfers never touch a quota. Both invariants were mutation-verified (injecting an approval double-spend and an off-by-one quota deduction makes them fail). Adds an `[invariant]` section to `foundry.toml`.
- Add `test/ThreatModel/ThreatModelTests.t.sol` — 18 threat-model proof-of-concept tests (15 unit/integration, 3 fuzz) covering the identity-registry mint path, `RuleMaxTotalSupply` view overflow, the multi-token approval-key divergence, `approveAndTransferIfAllowed` under a `RuleEngine`, residual state after `unbindToken`, `_transferHash` injectivity, mint-quota accounting, and `RuleWhitelistWrapper` child-rule composition. Tests suffixed `_CurrentBehaviour` assert behaviour the audit considers wrong: fixing the underlying issue must make them fail.
- Add `test/MintBurnFlags/MintBurnFlags.t.sol` and `test/RuleConditionalTransferLightMultiToken/MultiTokenSurface.t.sol` — cover the new `allowMint` / `allowBurn` setters, their access control and events, the dedicated mint/burn restriction codes, and the multi-token pre-flight surface. Also `test/InterfaceId/AddressListInterfaceId.t.sol`, `test/StaleState/StaleStateHygiene.t.sol`, `test/RuleConditionalTransferLight/RuleConditionalTransferLightBindRuleEngine.t.sol`.
- Close the last reachable coverage gaps introduced by this release: the `messageForTransferRestriction` lookups for the new mint/burn codes (`24`/`25` on the whitelist family, `64`/`65` on ERC-2980) and the wrapper's degenerate `from == 0 && to == 0` branch — the anti-drift guard that keeps `RuleWhitelistWrapper` and `RuleWhitelistBase` agreeing — were all reachable but unexecuted. 5 tests added; **every uncovered line in `src/` is now an abstract declaration with no body.**
- Regenerate the coverage report in `doc/coverage` (`forge coverage --report lcov` + `genhtml`).
- **Full suite: 511 tests across 78 suites — 97.8% line coverage (1 082/1 106), 97.3% branch coverage (220/226)** (up from 425 tests / 94.91% lines).
- Added `RuleConditionalTransferLightMultiToken` tests proving approvals are token-scoped and cannot be consumed cross-token.
- Added explicit RuleEngine integration tests for `RuleConditionalTransferLightMultiToken` documenting caller-context behavior in shared RuleEngine topology.
- Added `Ownable2StepERC165Support` test covering all Ownable2Step rule deployments.
- Extended `Ownable2StepERC165Support` with negative assertions to ensure Ownable2Step rule deployments do not advertise unrelated interfaces (`IAccessControl`, `0xdeadbeef`).
- Added unit tests (`test/RuleMintAllowance/RuleMintAllowance.t.sol`, `test/RuleMintAllowance/RuleMintAllowanceOwnable2Step.t.sol`) and CMTAT integration test (`test/RuleMintAllowance/CMTATIntegration.t.sol`) — 54 tests, including batch mint rollback and ERC-165 advertised-interface coverage, >98% line coverage on `RuleMintAllowanceBase`.

## v0.3.0 - 2026-04-16

Commit: `91c21c1191e84ff938892267ec443b0d1bb9efb0`

### Security

- **H1 fix** — `RuleConditionalTransferLight`: enforced single-token binding by overriding `bindToken` to revert with `RuleConditionalTransferLight_TokenAlreadyBound` if a token is already bound. Eliminates cross-token approval replay and approval-draining attacks. Use `unbindToken` first to migrate to a new token.
- **M1 fix** — Added `IERC7551Compliance` (`0x7157797f`), `IERC3643IComplianceContract` (validation rules), and the full ERC-3643 `ICompliance` ID via flat mock `IERC3643ComplianceFull` (`0x3144991c`) to all `supportsInterface` implementations. Silent `false` on ERC-165 introspection no longer occurs for compliant callers.

### Added

- `RuleConditionalTransferLightApprovalBase` — new abstract contract holding the pure approval state machine (approval counts, `approveTransfer`, `cancelTransferApproval`, `approvedCount`, and the `transferred` callback). No ERC-3643 / IRule knowledge.
- `IERC3643ComplianceFull` (`src/mocks/IERC3643ComplianceFull.sol`) — flat mock interface redeclaring all eight ERC-3643 `ICompliance` functions; used to compute the correct ERC-165 ID (`0x3144991c`) since `type(IERC3643Compliance).interfaceId` only XORs directly-defined selectors.

### Changed

- `RuleConditionalTransferLightBase` refactored into two layers: `RuleConditionalTransferLightApprovalBase` (state machine) + `RuleConditionalTransferLightBase` (ERC-3643 / IRule compliance integration). Eliminates code duplication between the AccessControl and Ownable2Step variants.
- `RuleConditionalTransferLightOwnable2Step` now inherits `ERC3643ComplianceModule` via the base (consistent with the AccessControl variant); `_authorizeTransferExecution` consolidated into the base and checks `isTokenBound(_msgSender())`.
- `approveAndTransferIfAllowed` no longer takes a `token` parameter — bound token is retrieved directly via `getTokenBound()`.
- `RuleConditionalTransferLightBase.approveAndTransferIfAllowed` now uses OpenZeppelin `SafeERC20.safeTransferFrom` to handle non-standard ERC-20 return behavior safely.
- Removed unused custom error `RuleConditionalTransferLight_TransferFailed` from `RuleConditionalTransferLightInvariantStorage`.
- Custom error `RuleConditionalTransferLight_TokenAddressZeroNotAllowed` renamed to `RuleConditionalTransferLight_TokenNotBound` for clarity.
- `RuleERC2980` and `RuleERC2980Ownable2Step` constructors now include `allowBurn` and whitelist `address(0)` at deployment when enabled.
- `RuleWhitelist` and `RuleWhitelistOwnable2Step` constructors now include `allowMintBurn`; when enabled, `address(0)` is pre-listed at deployment.
- Solidity style guide ordering (type declarations → state variables → events → errors → modifiers → functions; constructor → external → public → internal → private) enforced across all `src/` contracts.
- `supportsInterface` in `RuleConditionalTransferLight` and `RuleConditionalTransferLightOwnable2Step` now advertises `IERC7551Compliance` and the full ERC-3643 `ICompliance` interface ID instead of the narrow `IERC3643IComplianceContract`.
- `supportsInterface` in `RuleTransferValidation` (cascades to all validation rules) now also advertises `IERC7551Compliance` and `IERC3643IComplianceContract`.
- Update contract version to `0.3.0`

### Dependencies

- Update RuleEngine to `v3.0.0-rc2`.
- Update OpenZeppelin Contracts to `v5.6.1`.
- Update OpenZeppelin Contracts Upgradeable to `v5.6.1`.

### Documentation

- Wake Arena (Ackee Blockchain Security) AI-assisted static analysis report and project feedback added to `doc/security/audits/tools/v0.2.0/`.
- README Security section updated with Wake Arena findings summary table.
- README Access Control section updated to document intentional `DEFAULT_ADMIN_ROLE` implicit-role behaviour, `grantRole` no-op semantics, and off-chain monitoring guidance (I2).
- `RuleERC2980` documentation updated to clarify that a frozen address acting as `transferFrom` spender is also blocked (code 62) (I1).
- `RuleERC2980` documentation and README updated to document burn/redemption behavior and the new constructor `allowBurn` option.
- `RuleWhitelist` documentation and README updated to document constructor `allowMintBurn` and zero-address mint/burn handling.
- README updated to document Hardhat support for optional compilation and smoke testing alongside Foundry-first workflows.
- `CLAUDE.md` / `AGENTS.md` convention added: always use pre-computed library constants for ERC-165 IDs; use a flat mock interface when no constant exists.

### Testing

- Added `RuleERC2980` constructor tests covering default burn-blocked behavior and `allowBurn=true` zero-address whitelisting.
- Added `RuleWhitelist` constructor tests covering `allowMintBurn=true` zero-address pre-listing.
- Added a Hardhat smoke test (`test/hardhat/smoke.test.js`) and npm scripts for Hardhat compile/smoke execution.
- Updated `RuleConditionalTransferLightApproveAndTransfer` transfer-failure test to assert OpenZeppelin `SafeERC20` revert semantics.
- Removed now-unused `RuleConditionalTransferLight_TransferFailed` declaration; no behavior change.

## v0.2.0 - 2026-03-10

Commit: [`d72a98a`](https://github.com/CMTA/Rules/commit/d72a98abbba29cd82a7056b59104e82ac65389e7) 

### Added

- `RuleSpenderWhitelist` — validation rule that blocks `transferFrom` when spender is not listed; direct transfers are always allowed. Restriction code 66.
- `RuleSpenderWhitelistOwnable2Step` — Ownable2Step variant of `RuleSpenderWhitelist`.
- Technical documentation file `doc/technical/contracts/RuleSpenderWhitelist.md`.
- Transfer-context mocks in `src/mocks`: `MockERC20WithTransferContext` and `MockERC721WithTransferContext`.
- Transfer-context mocks in `src/mocks` now inherit OpenZeppelin `ERC20` / `ERC721` and emit rule callbacks through `ITransferContext`.
- Transfer-context tests for ERC-20/ERC-721 mock integration in `test/TransferContext/TransferContextMocks.t.sol`.
- `RuleERC2980` — ERC-2980 Swiss Compliant rule combining a whitelist (recipient-only) and a frozenlist (blocks sender, recipient, and spender); frozenlist takes priority. Restriction codes 60–63.
- `RuleERC2980Ownable2Step` — Ownable2Step variant of `RuleERC2980`.
- `IERC2980` interface with NatSpec documenting the deviation from the ERC example interfaces (single-item functions revert on invalid input rather than returning `bool`).
- `isVerified(address)` to `RuleERC2980Base` and `RuleWhitelistWrapperBase`, implementing `IIdentityRegistryVerified`; for ERC-2980 it reflects whitelist membership only (frozen status is excluded).
- `VersionModule` — abstract module implementing `IERC3643Version`; all rules now expose `version()` returning `"0.2.0"`.
- New deployable rules: `RuleIdentityRegistry`, `RuleMaxTotalSupply`, `RuleConditionalTransferLight`.
- Ownable2Step variants for all rules: `RuleWhitelistOwnable2Step`, `RuleBlacklistOwnable2Step`, `RuleSanctionsListOwnable2Step`, `RuleMaxTotalSupplyOwnable2Step`, `RuleIdentityRegistryOwnable2Step`, `RuleWhitelistWrapperOwnable2Step`, `RuleConditionalTransferLightOwnable2Step`.
- Transfer-context struct API: `MultiTokenTransferContext` / `FungibleTransferContext` with an extra `data` field.
- Explicit sanctions oracle clearing via `clearSanctionListOracle()`.
- CMTAT deployment scripts for whitelist and blacklist configurations.
- `DeployCMTATWithBlacklistAndSanctionsList` deployment script — deploys a CMTAT token wired to a `RuleEngine` configured with both `RuleBlacklist` and `RuleSanctionsList`.
- Technical documentation for all rules in `doc/technical/`: added `RuleMaxTotalSupply.md`, `RuleIdentityRegistry.md`, `RuleERC2980.md`, `RuleConditionalTransferLight.md`; updated `RuleWhitelist.md`, `RuleBlacklist.md`, `RuleSanctionList.md`, `RuleWhitelistWrapper.md`.

### Changed

- RBAC variants now use `AccessControlEnumerable` (replacing plain `AccessControl`); role members can be enumerated with `getRoleMember` / `getRoleMemberCount`.
- Default admin implicitly holds all roles via a `hasRole` override; may not appear in role member enumerations unless explicitly granted.
- Authorization hooks (`_authorize*()`) now use `onlyRole(ROLE)` modifier instead of direct `_checkRole` calls.
- All `internal` functions marked `virtual` to allow downstream overriding.
- Validation flow refactored to internal hooks (no `this.` calls) via `RuleTransferValidation` and `RuleNFTAdapter`.
- `RuleConditionalTransferLight` and `RuleMaxTotalSupply` are ERC-20 only; ERC-721/1155 compliance interfaces are limited to validation rules.
- Address list batch updates emit only add/remove events (no summary events).
- Reorganized validation contracts into `abstract/base`, `abstract/core`, `abstract/invariant`, and `deployment` folders.
- Rule transfer-context dispatch now treats `sender == from` as direct transfer (non-spender path) in `RuleNFTAdapter`.
- Concrete utilities and harness contracts used by tests were moved from `test/` into `src/mocks` and `src/mocks/harness`.

### Dependencies

- Updated Solidity toolchain to 0.8.34.
- Update OpenZeppelin to 5.6.0
- Update CMTAT to v3.2.0
- Update RuleEngine to v3.0.0-rc1

### Documentation

- Access-control role table with keccak256 hashes.
- Rule-engine flow diagrams, API accuracy, directory layout notes.
- Static analysis reports (Aderyn, Slither) with project feedback in `doc/security/audits/tools/v0.2.0/`.
- Gas benchmarks in `doc/GAS.md` and `.gas-snapshot`.

## v0.1.0 - 2025-12-03

Commit: `09376412269d2397fa7db6562e63bc65376d12b9`

First release !

- Update Rules to CMTAT v3.0.0 and latest RuleEngine version

- Use [EnumerableSet](https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet) from OpenZeppelin to store address status for blacklist and whitelist rules.
- Add function `canTransferFrom`, `detectTransferRestrictionFrom` which takes the spender argument
- Add functions `canTransfer`, `canTransferFrom`, `detectTransferRestriction`,`detectTransferRestrictionFrom` which takes the `tokenId` argument.
- Add support of [ERC-165](https://eips.ethereum.org/EIPS/eip-165) in each rule.
