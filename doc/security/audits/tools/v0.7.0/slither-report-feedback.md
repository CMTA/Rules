# Slither `v0.7.0` — triage

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.7.0/slither-report.md
```

Tool: **Slither 0.11.6**, the latest release, run through `uvx --from slither-analyzer==0.11.6` · Compiler: solc `0.8.36` · Run date: **2026-10-26** Scope: production contracts only. Mocks excluded via the `mocks` filter, vendored dependencies via `lib`. 229 contracts, 102 detectors, **46 results**.

A second run with **Slither 0.11.5**, the version of the `v0.4.0`–`v0.6.0` reports, is kept as [`slither-report-0.11.5.md`](./slither-report-0.11.5.md). It separates what changed in the code from what changed in the tool: see [Two runs, two questions](#two-runs-two-questions).

**Executive triage: nothing to fix.** No finding is exploitable. Both High-impact results are the same false positive dismissed since `v0.4.0`, on a permissioned path. Every `dead-code` result, including the new one on `RuleIssuanceCapBase._afterMintChecked`, is reachable through virtual dispatch.

One **analysis blind spot**, present in both versions and in earlier releases without being recorded, is documented [below](#blind-spot-functions-slither-cannot-analyse). It does not hide a defect, but it limits what this report covers.

### Scope check

```
grep -c 'lib/\|node_modules/' slither-report.md   → 0 findings (one hit: Slither's echo of `forge build --skip ./test/**`)
grep -c 'test/\|src/mocks/'   slither-report.md   → 0 findings (same echo line)
```

`lib/CMTATv3.0.0`, added this release for tests, sits under `lib/` and is excluded.

## Summary

| Detector | Impact | Instances | Disposition |
|---|---|---|---|
| `arbitrary-send-erc20` | High | 2 | **False positive** |
| `uninitialized-local` | Medium | 2 | False positive |
| `unused-return` | Medium | 3 | False positive |
| `calls-loop` | Low | 17 | By design |
| `timestamp` | Low | 1 | By design |
| `assembly` | Informational | 2 | By design |
| `dead-code` | Informational | 9 | False positive |
| `naming-convention` | Informational | 6 | By design |
| `unused-state` | Informational | 4 | Cosmetic |

NOTE: Slither 0.11.6 leaves `arbitrary-send-erc20` out of the checklist's summary list at the top of the raw output, which therefore adds up to 44. Both results are in the body and on stderr. 46 is the correct count.

- **`arbitrary-send-erc20` (2)** — `approveAndTransferIfAllowed` in both conditional-transfer bases. `from` is caller-chosen, but the function is gated by `onlyTransferApprover`, consumes a recorded approval, checks the allowance and transfers only on the bound token.
- **`uninitialized-local` (2)** — `ChainlinkPoRFeedManager` locals assigned inside `try`, whose `catch` returns or reverts before any read.
- **`unused-return` (3)** — `BalanceCapManager._setBalanceToken` and `TokenSupplyReader._probeTotalSupplyCallable`, configuration probes whose only purpose is to learn whether the call reverts; and `ChainlinkPoRFeedManager._maxBackedSupply`, which uses two of the five `latestRoundData()` fields by design.
- **`calls-loop` (17)** — the `RuleWhitelistWrapper` child scan and its `_checkRule` interface and polarity guard: bounded by `maxRules`, configuration-time only.
- **`timestamp` (1)** — the Proof-of-Reserve staleness check, which is the feature.
- **`dead-code` (9)** — all reachable:
  - `_contextSuffixLength()` in `RuleWhitelist`, `RuleBlacklist`, `RuleERC2980` and their Ownable2Step variants (6): the override that resolves the `ERC2771Context` / `Context` diamond. OpenZeppelin's `ERC2771Context._msgSender()` and `_msgData()` call it (`ERC2771Context.sol:57, :74`) on every relayed call.
  - `RuleIssuanceCapBase._afterMintChecked` (1, **new this release**): the counter. `RuleMaxTotalSupplyBase._transferred` / `_transferredFrom` call it on every accepted mint. Coverage of `RuleIssuanceCapBase` is 100%, and deleting its write fails four invariants (mutation M4 in `INVARIANT_TESTS.md`). Acting on this finding would turn the rule back into a replenishing cap.
  - `RuleERC2980Internal._requireNotZeroAddress` and `RuleAddressSetInternal._requireNotZeroAddress` (2): passed as a function pointer to `AddressSetBatchLib.addBatch`, which Slither does not follow.
- **`naming-convention` (6)** — spec-aligned parameter names.
- **`unused-state` (4)** — the `TRANSFERRED_SELECTOR_*` constants in `RuleNFTAdapter`. Unreferenced anywhere, `internal constant`, nil impact. Kept rather than removed because they are `internal` API of a library meant to be subclassed.

## Two runs, two questions

| Question | Run | Answer |
|---|---|---|
| Did **this release's code** add findings? | 0.11.5 on `v0.7.0` vs 0.11.5 on `v0.6.0` | **No.** 46 → 46, every result identical once line numbers are ignored |
| Did **the tool upgrade** change findings? | 0.11.6 vs 0.11.5, same `v0.7.0` code | **Yes, redistributed, same total (46)** |

Changing the code and the tool at the same time would make a delta unreadable, hence the second run.

### What changed between Slither 0.11.5 and 0.11.6 (same code)

| Detector | 0.11.5 | 0.11.6 | Δ | What moved |
|---|---|---|---|---|
| `unused-return` | 9 | 3 | **−6** | 0.11.6 no longer flags the discarded return values of `AddressSetBatchLib.addBatch` / `removeBatch` in `RuleAddressSetInternal` (2) and `RuleERC2980Internal` (4). The other three are reported by both versions |
| `dead-code` | 3 | 9 | **+6** | New: the six `_contextSuffixLength` overrides and `RuleIssuanceCapBase._afterMintChecked`. No longer flagged: `RuleChainlinkPoRBase._detectTransferRestrictionOnNotify` |
| all others | 34 | 34 | — | |

Every result 0.11.6 adds is a false positive of the same kind, an internal function called only through virtual dispatch or a function pointer. 0.11.6 is no more precise on this codebase than 0.11.5, just differently imprecise.

### Delta of this release's code (0.11.5 on both)

**46 → 46 results, 0 changed**, although this release added `RuleIssuanceCap` (four files, a stateful counter, caller binding), made `RuleMaxTotalSupplyBase.transferred` non-`view` with a new hook, and migrated to RuleEngine `v3.0.0-rc7` / CMTAT `v3.3.0-rc4`. Contract count 225 → 229, the four new files.

## Blind spot: functions Slither cannot analyse

Both versions log `Impossible to generate IR … 'NoneType' object has no attribute 'parameters'` for six functions:

| Contract | Functions |
|---|---|
| `RuleMaxBalance` | `_addAddresses`, `_removeAddresses` |
| `IdentityRegistryWhitelist` | `_addAddresses`, `_removeAddresses` |
| `ERC3643MaxBalanceHarness` (mock, out of scope) | `_addAddresses`, `_removeAddresses` |

Each passes the internal function `_requireNotZeroAddress` as a function pointer to `AddressSetBatchLib`. Without IR, **no detector runs on those function bodies in those contracts**, and the run still reports success.

The same errors appear in the 0.11.5 log, and the code has not changed since `v0.6.0`. The `v0.6.0` run therefore very likely had the same gap; it was not recorded then.

**Why it does not hide a defect here:**
- The source is `RuleAddressSetInternal`, inherited unchanged. Slither does analyse it in the contracts where IR generation succeeds: the 0.11.5 run reports findings on `RuleAddressSetInternal._addAddresses` itself.
- The functions are covered by the batch-operation unit tests of both contracts, including the zero-address rejection the pointer implements (I-12).

**Recommendation:** treat it as a coverage limit of the tool, not a finding, and check the stderr log of every future run for `Impossible to generate IR`. A run that reports success can still have skipped functions.

## Tooling note

The system-wide `slither` launcher in this environment is broken (its Python package is missing), so both runs used `uvx` with an exact pinned version. That keeps each run reproducible. Re-run with `uvx --from slither-analyzer==0.11.6 slither …`.

## What a clean report does and does not mean

Slither matched nothing actionable. That is not evidence of correctness: the properties that make `RuleIssuanceCap` safe are semantic. Burns must not restore room, the counter must be enforced with the real amount even on a re-phased write path, and only the bound caller may record a mint. These are established by the unit, CMTAT v3.0.0 and invariant suites, with mutation controls, not by static analysis.
