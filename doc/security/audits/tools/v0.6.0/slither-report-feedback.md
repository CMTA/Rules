# Slither `v0.6.0` — triage

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.6.0/slither-report.md
```

Tool: **Slither 0.11.5** · Compiler: solc `0.8.36` · Run date: **2026-08-18**
Scope: production contracts only. Mocks excluded via the `mocks` filter, vendored dependencies via `lib`.
221 contracts, 101 detectors, **46 results**.

**Executive triage: nothing to fix.** No finding is exploitable. Both High-impact results are the same
false positive dismissed in `v0.4.0` and `v0.5.0`, on a permissioned path. The two results new since `v0.5.0`
were each opened against the source and dismissed; one of them is worth reading, because the natural reaction to
it would be to delete working code.

### Scope check

Both assertions pass — the filter matched, so nothing outside the project is in scope:

```
grep -c 'lib/\|node_modules/' slither-report.md   → 0
grep -c 'test/\|src/mocks/'   slither-report.md   → 0
```

The filter list must name **`lib`**: this is a Foundry project, and an entry that matches nothing fails open,
pulling the whole vendored dependency tree in. A previous run with a generic `submodules` filter returned 170
results, 351 of them citing `lib/openzeppelin-contracts/`.

## Summary

| Detector | Impact | Instances | Disposition |
|---|---|---|---|
| `arbitrary-send-erc20` | High | 2 | **False positive** |
| `uninitialized-local` | Medium | 2 | False positive |
| `unused-return` | Medium | 9 | False positive |
| `calls-loop` | Low | 17 | By design |
| `timestamp` | Low | 1 | By design |
| `assembly` | Informational | 2 | By design |
| `dead-code` | Informational | 3 | False positive |
| `naming-convention` | Informational | 6 | By design |
| `unused-state` | Informational | 4 | Cosmetic |

## Delta from `v0.5.0`

**44 → 46 results (+2).** Every other detector is unchanged, instance for instance.

| Detector | v0.5.0 | v0.6.0 | Δ |
|---|---|---|---|
| `calls-loop` | 16 | 17 | **+1** |
| `dead-code` | 2 | 3 | **+1** |
| *(all others)* | 42 | 42 | — |

A delta this small on a release that added five production contracts is the expected shape. Both new results
are in code added for the Nethermind AuditAgent fixes.

### +1 `calls-loop` — `RuleWhitelistWrapperBase._checkRule`

> `_checkRule(address)` has external calls inside a loop: `require(IAddressListPolarity(rule_).isAllowList(), …)`

**By design.** This is the NM-20 polarity guard. Slither reaches it through `setRules`, which loops over the
submitted array calling `_addRule` → `_checkRule`, so each candidate costs two `ERC165Checker` staticcalls plus
one `isAllowList()`. That is:

- **bounded** — `maxRules` defaults to 10 and `setRules` rejects an array longer than it;
- **configuration-time only** — `RULES_MANAGEMENT_ROLE`, never a transfer path, so no holder pays for it;
- **the point of the guard** — checking a child's interface and polarity requires calling the child.

The alternative (validating outside the loop) would mean not validating each candidate, which is the finding
NM-18 and NM-20 exist to close.

### +1 `dead-code` — `RuleChainlinkPoRBase._detectTransferRestrictionOnNotify`

> `_detectTransferRestrictionOnNotify(address,address,uint256)` is never used and should be removed

**False positive, and acting on it would break the ERC-3643 Proof-of-Reserve variant.** The function is the
notification-phase seam added for NM-11; `RuleChainlinkPoRERC3643` exists solely to override it. Three
independent confirmations that it is live:

1. **It is called twice in the same file** — `RuleChainlinkPoRBase.sol:202` and `:217`, from `_transferred` and
   `_transferredFrom`.
2. **Coverage is 100% of functions** on `RuleChainlinkPoRBase` (10/10). An unreachable function cannot be
   executed by the test suite.
3. **`testStockRuleRevertsAFullyBackedMint` and `testMintUpToTheReservesSucceeds`** (real-T-REX suite) differ
   *only* by which override of this hook is installed. If the seam were dead, both would behave identically and
   the pair would fail.

Slither's `dead-code` is unreliable for `internal virtual` functions reached through inheritance: the same
detector already produced the two pre-existing hits below, both dismissed on the same grounds. Note also its
inconsistency — `RuleMaxTotalSupplyBase` has the byte-identical seam, overridden by
`RuleMaxTotalSupplyERC3643`, and is **not** flagged.

The two pre-existing instances are unchanged: `RuleERC2980Internal._requireNotZeroAddress` and
`RuleAddressSetInternal._requireNotZeroAddress`, both internal guards reached from the public layer.

## Findings carried over from `v0.5.0`

Unchanged in count and disposition; verified again against the source this run.

- **`arbitrary-send-erc20` (High, 2)** — `approveAndTransferIfAllowed` in the light and multi-token conditional
  rules. Gated by `onlyTransferApprover`, a recorded approval, an explicit allowance check and a bound token.
  This release **tightened** the path further (NM-17: the helper now reverts unless the approval it created was
  consumed), so the detector's premise is weaker than before, not stronger.
- **`uninitialized-local` (Medium, 2)** — variables assigned inside a `try` whose `catch` returns or reverts.
- **`unused-return` (Medium, 9)** — `EnumerableSet` add/remove return values deliberately discarded by the batch
  helpers, and the configuration probes (`totalSupply()`, `balanceOf()`, `decimals()`) whose discarded value is
  precisely the point: the call is made to learn whether it reverts.
- **`calls-loop` (Low, 16 of 17)** — the wrapper's child scan. Bounded by `maxRules`, measured at ~8.8k gas per
  child, and documented with operator guidance.
- **`timestamp` (Low, 1)** — the Proof-of-Reserve staleness comparison. The feature is a freshness check; it
  cannot be written without reading `block.timestamp`.
- **`assembly` (Informational, 2)** — the `_transferHash` preimage, whose exact layout is documented and pinned
  by `testDocumentedPreimageMatchesTheStorageKey`.
- **`naming-convention` (Informational, 6)** — parameter names matching the ERC text they implement.
- **`unused-state` (Informational, 4)** — the four `TRANSFERRED_SELECTOR_*` constants in `RuleNFTAdapter`. Still
  genuinely unreferenced, as corrected in the `v0.5.0` triage (they had previously been dismissed as a false
  positive, wrongly). Impact is nil — `internal constant`, so no storage and nothing emitted into bytecode — so
  the disposition stays cosmetic rather than a fix.

## What a clean report does and does not mean

Slither's pattern set matched nothing actionable. That is not evidence of correctness: every substantive issue
addressed in this release came from the Nethermind AuditAgent scan and from manual review, and **not one of the
seven fixed findings was reachable by either static analyser** — they are semantic (who calls a hook, in what
order, with which arguments), and Slither and Aderyn match syntax.
