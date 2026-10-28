# Deployment scripts `v0.7.0` — static-analysis triage

Reports: [`slither-report-script.md`](./slither-report-script.md) · [`aderyn-report-script.md`](./aderyn-report-script.md). Scope: `script/` only, the 17 deployment scripts and `script/base/CMTATDeploymentBase.sol`. Run date **2026-10-28**, solc `0.8.38`, EVM `osaka`.

**Executive triage: one finding fixed, nothing left to fix.** Slither reports nothing. Aderyn's first run reported two Low categories; one was fixed and led to a real improvement, the other is by design.

## Summary

| Tool | Finding | Instances | Disposition |
|---|---|---|---|
| Slither | — | 0 | Nothing reported |
| Aderyn | L-1 Unspecific Solidity Pragma | 18 | **By design** — `^0.8.27` as in `src/`; `foundry.toml` pins solc `0.8.38` for every build |
| Aderyn | Large Numeric Literal | 5 → 0 | **Fixed**, see below |

## Large Numeric Literal: fixed, and a decimals bug behind it

The five literals were the default caps passed to `vm.envOr`: `1_000_000` for `CMTAT_MAX_SUPPLY` (in two scripts), `100_000` for `CMTAT_MAX_BALANCE`, `1_000_000` for `CMTAT_ISSUANCE_CAP`, and the mock reserves of the Chainlink PoR script.

The literal itself is cosmetic, but looking at it showed two real problems:

- **Duplication.** `CMTAT_MAX_SUPPLY` was read, with its own copy of the default, in two scripts.
- **Wrong scale for any non-zero `CMTAT_DECIMALS`.** The defaults were base units. With `CMTAT_DECIMALS=18`, the default supply cap was 0.000000000001 tokens, so every mint of the deployed token failed (code 50). It failed closed, but the script printed nothing and the deployment looked complete.

**Fix.** `CMTATDeploymentBase` now has one reader per cap, `_maxTotalSupply()`, `_maxBalance()` and `_issuanceCap()`, like the existing `_forwarder()`. Their defaults are named constants in **whole tokens** (`DEFAULT_MAX_TOTAL_SUPPLY_TOKENS = 1e6`, `DEFAULT_MAX_BALANCE_TOKENS = 1e5`, `DEFAULT_ISSUANCE_CAP_TOKENS = 1e6`) scaled by the token's decimals through `_wholeTokens()`. A value set in the environment is still read as base units, unchanged. The four scripts call the readers; the Chainlink PoR mock reserves became `1e6`, and its staleness default `1 days`.

- Behaviour at the default `CMTAT_DECIMALS = 0` is unchanged: the same 1 000 000 / 100 000 / 1 000 000.
- Pinned by `test/DeploymentScripts/CMTATDeploymentBase.t.sol` (defaults at 0 and at 18 decimals). The harness overrides the decimals instead of calling `vm.setEnv`, which is process-wide and would leak into the deployment tests running in parallel.
- All 17 scripts still dry-run with no environment.

## Tooling notes

- **Slither** never analyses `script/` with its default Foundry build, which skips `./script/**`. The command in the report builds `src/` and `script/` first.
- **Aderyn** does not accept `script/` as a source directory. The report was produced from a scratch copy, as described in its header.
- Both workarounds are worth keeping for future releases: without them, a clean production report says nothing about the scripts.
