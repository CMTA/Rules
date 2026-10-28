# Slither Report — `v0.7.0`, deployment scripts

```bash
forge clean && forge build --build-info --skip './test/**'
slither . --foundry-ignore-compile --checklist \
  --filter-paths "node_modules,lib,test,forge-std,mocks,src/" \
  > doc/security/audits/tools/v0.7.0/slither-report-script.md
```

Tool: **Slither 0.11.6** (run through `uvx --from slither-analyzer==0.11.6`) · Compiler: solc `0.8.38`, EVM `osaka` · Run date: **2026-10-28** (re-run after the scripts were changed to create the token with its final admin)
Scope: **`script/` only** — the 17 deployment scripts and `script/base/CMTATDeploymentBase.sol`. `src/` is filtered out (it has its own report, [`slither-report.md`](./slither-report.md)), as are mocks, tests and vendored code. 339 contracts compiled and analysed, 102 detectors, **0 results**.

**Why the custom build.** Slither's own Foundry build passes `--skip ./test/** ./script/**`, so the default command never analyses the scripts. Building `src/` and `script/` beforehand and running with `--foundry-ignore-compile` brings them into scope; `--foundry-compile-all` is not usable here, because it also compiles the tests and Slither crashes on one of them (`IndexError` in `convert_constant_types`). With `src/` left in scope instead, the run reports the same 47 results as the production report and none in `script/`, which confirms the scripts were analysed.

**Nothing to fix.**

Triage: [`script-report-feedback.md`](./script-report-feedback.md) · Overview: [`AUDIT_OVERVIEW.md`](../../AUDIT_OVERVIEW.md)

---

Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
--ignore-compile used, if something goes wrong, consider removing the ignore compile flag
'forge config --json' running
**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
