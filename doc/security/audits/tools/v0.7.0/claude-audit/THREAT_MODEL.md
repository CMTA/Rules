# Threat model — CMTA Rules v0.7.0 (delta since v0.6.0)

> AI-assisted review. Not an audit by an audit company. Production source must not cite this file.

**Scope.** The code added or changed between tag `v0.6.0` and the `v0.7.0` working tree (122 files under `src/`,
+957 / −258 lines). The whole library was threat-modelled in v0.4.0 (`CLAUDE_AUDIT.md`, threat IDs `AC-*`, `CT-*`,
`MT-*`, …). Those threats are not re-derived here. This model covers:

| Area | Files |
|---|---|
| New rule `RuleIssuanceCap` | `src/rules/operation/RuleIssuanceCap*.sol`, `abstract/RuleIssuanceCapBase.sol`, `abstract/RuleIssuanceCapInvariantStorage.sol` |
| `RuleMaxTotalSupply` changes | `TotalSupplyCapManager.sol` (increase / decrease, `(previous, new)` event, token-contract hook), `RuleMaxTotalSupplyBase.sol` (non-`view` `transferred`, `_afterMintChecked`, `remainingMintable`), `RuleMaxTotalSupplyRolesStorage.sol` |
| Code 85 for unbound rules | `RuleBindingInvariantStorage.sol`; `_ruleNotBound()` in `RuleConditionalTransferLightBase`, `RuleMintAllowanceBase`, `RuleIssuanceCapBase` |
| Dependency migration | CMTAT v3.3.0-rc4, RuleEngine v3.0.0-rc7 (`IRule` no longer extends `IRuleEngine`; both `IRule` ids advertised), pragma `^0.8.27`, deployment scripts |
| Convention changes | 63 functions marked `virtual`, comment and citation changes (no runtime effect, sizes identical) |

## 1. Claude Skills Used

| Skill | Purpose / contribution |
|---|---|
| `project-analyse-quality` | Orchestration: this is step 3 of the quality pass |
| `sc-analyse-and-test-solidity` | Workflow: threat model, test plan, PoCs, result, judge |
| `rwa-token-audit` | Checks 1 (chokepoint equivalence), 2 (hook idempotency), 7 (view vs enforcement), 9 (engine trust boundary): IC-5, CH-1, CH-2 |
| `cmtat-audit` | Confirmed CMTAT bug classes (double hook invocation, spender propagation, §3 design choices) used to screen out non-findings: CH-2, V3-1 |
| `audit-cmtat` | Check 4 (RuleEngine integration, 3-arg vs 4-arg dispatch) and check 6 (roles): AC-1, AC-2, IF-1 |
| `audit-access-control` | Role map of the new setters and the binding hooks: AC-1 to AC-5 |
| Slither 0.11.6 printers (`function-summary`, `inheritance-graph`) | Reachability map in `slither-graph/`. Comprehension aid only |

## 2. Project overview (delta)

`RuleIssuanceCap` is a **non-replenishing** issuance cap: `totalIssued` rises on every accepted mint and never
falls on burn. It extends `RuleMaxTotalSupplyBase` through one hook (`_afterMintChecked`) and keeps the inherited
live-supply check against the same cap as a backstop. Because it writes storage on the write path, both
`transferred` overloads are `onlyBoundToken`, and only one caller can be bound at a time.

`RuleMaxTotalSupply` gains relative cap setters, a `(previous, new)` event, `remainingMintable()`, and a dedicated
`MAX_TOTAL_SUPPLY_ROLE` separate from the admin-only `setTokenContract`. Its `transferred` is no longer `view`
(so the subclass can record) but the stock rule still writes nothing.

The three stateful operation rules now report code **85** from every view while no caller is bound, matching the
write path, which reverts for every caller in that state.

## 3. Trust model and actors

| Actor | Trust | Capabilities in scope |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` / owner | Fully trusted | Holds every role implicitly; `setTokenContract` on `RuleMaxTotalSupply` |
| `MAX_TOTAL_SUPPLY_ROLE` | Trusted | `setMaxTotalSupply`, `increaseMaxTotalSupply`, `decreaseMaxTotalSupply`, on both `RuleMaxTotalSupply` and `RuleIssuanceCap` |
| `COMPLIANCE_MANAGER_ROLE` | Trusted | `bindToken` / `unbindToken` on `RuleIssuanceCap` (and the other operation rules) |
| Bound caller (token, or RuleEngine) | Trusted to report real movements | The only account that can drive `transferred` / `created` / `destroyed` on a stateful rule |
| Token minter (`MINTER_ROLE` on CMTAT) | Semi-trusted | Mints, which the cap must bound |
| Token holder / any EOA | Untrusted | Calls every public function; transfers, burns of own balance |
| Observed token (`tokenContract`) | Trusted to report `totalSupply()` honestly; not trusted to stay callable | Read in try/catch |

## 4. Attack surface analysis

Every row gets a disposition in `RESULT.md`.

### 4.1 Access control

| ID | Threat | Component |
|---|---|---|
| AC-1 | `MAX_TOTAL_SUPPLY_ROLE` can repoint the observed token, or an unprivileged account can change the cap | `TotalSupplyCapManager` setters, both deployables |
| AC-2 | A non-bound caller drives `RuleIssuanceCap.transferred` / `created` and inflates or burns the issuance budget | `RuleIssuanceCapBase` |
| AC-3 | A second caller is bound through a path other than the overridden `bindToken` (batch, self-binding) | Binding modules inherited from RuleEngine rc7 |
| AC-4 | `setTokenContract` re-points `RuleIssuanceCap` at another token, decoupling the counter from the supply it describes | `_authorizeTokenContractManager` override |
| AC-5 | `RuleMaxTotalSupplyBase.transferred` is public and ungated; any subclass that records in `_afterMintChecked` inherits an open write path | `RuleMaxTotalSupplyBase` |

### 4.2 Issuance-cap accounting

| ID | Threat | Component |
|---|---|---|
| IC-1 | One instance bound to a RuleEngine that serves several tokens: every token's mints feed one counter, checked against one token's supply | `RuleIssuanceCapBase` + RuleEngine multi-tenancy |
| IC-2 | The bound caller is not tied to `tokenContract`: a mis-binding blocks every operation while the views report OK | `bindToken` |
| IC-3 | Mints made before binding, or while the rule is detached, are not counted, so cumulative issuance can exceed the cap | `RuleIssuanceCapBase` |
| IC-5 | Read path and write path disagree (view says OK, mint reverts, or the reverse), including the re-phased path | `_detectTransferRestriction`, `_afterMintChecked` |
| IC-6 | The cap role raises the cap, undoing non-replenishment | `increaseMaxTotalSupply` |
| IC-7 | `crosschainMint` round trips and `burnAndMint` consume issuance | Token mint paths |
| IC-8 | On an ERC-3643 token the live leg double-counts the post-update supply | `RuleIssuanceCap` on T-REX |
| IC-9 | `initialIssued` below the supply at deployment makes the counter smaller than reality | Constructor |
| IC-10 | Arithmetic overflow of `totalIssued + value` on the write path, or of `issued + value` in views | `_afterMintChecked`, `CapAccounting` |

### 4.3 Supply-cap setters

| ID | Threat | Component |
|---|---|---|
| MTS-2 | `increaseMaxTotalSupply` wraps on overflow / `decreaseMaxTotalSupply` underflows | `TotalSupplyCapManager` |
| MTS-3 | `MaxTotalSupplyUpdated(previous, new)` reports a wrong `previous` | `_setMaxTotalSupply` |

### 4.4 Code 85

| ID | Threat | Component |
|---|---|---|
| B85-1 | Code 85 is shared by three rules: behind a RuleEngine the code does not say which rule is unbound | `RuleBindingInvariantStorage` |
| B85-2 | Code 85 collides with another rule's or CMTAT's code | Restriction-code space |
| B85-3 | `RuleMintAllowance.canTransfer` now returns `false` while unbound; an integrator relying on the previous constant `true` breaks | `RuleMintAllowanceBase` |

### 4.5 Dependency migration and integration

| ID | Threat | Component |
|---|---|---|
| IF-1 | Advertising the legacy `IRule` id (`0x2497d6cb`) claims functions a rule does not implement, so an rc6 engine calls a missing selector | `RuleTransferValidation.supportsInterface` and the operation bases |
| IF-2 | Deployment scripts pass a forwarder to the plain `RuleEngine` (which has none) or bind the wrong token | `script/` |
| CH-1 | A mint path (`batchMint`, `crosschainMint`, `burnAndMint`) skips the rule, so the cap is bypassed | CMTAT v3.3 / v3.0.0 mint paths |
| CH-2 | The compliance hook fires twice per mint, double-counting `totalIssued` | CMTAT `_mintOverride` chain, RuleEngine fan-out |
| V3-1 | On CMTAT v3.0.0 the cap rules lose a leg | 3-arg path |

## 5. Critical findings summary

No Critical, High, Medium or Low threat was confirmed. See `RESULT.md` for the ranked list (5 Info; F-1 downgraded from Low by the judge).

## 6. Data flows

Derived from the Slither function summary (`slither-graph/slither-function-summary.txt`, the six in-scope
deployables). Externally reachable writers on `RuleIssuanceCap`: `transferred` ×2, `created`, `destroyed`
(all `onlyBoundToken`); `bindToken` / `unbindToken` (`onlyTokenBindingManager`); the three cap setters
(`onlyMaxTotalSupplyManager`); `setTokenContract` (always reverts). There are no `RuleNFTAdapter` entry points:
`RuleMaxTotalSupplyBase` inherits `RuleTransferValidation` only.

```
Mint, Topology B (rule set directly on the token)
  minter ── CMTAT.mint(to, v) ──▶ _mintOverride ──▶ rule.transferred(minter, 0, to, v)   [v3.3: 4-arg]
                                                     │ onlyBoundToken (msg.sender == token)
                                                     ├─ _detectTransferRestrictionOnNotify(0, to, v)
                                                     │    ├─ 85 if unbound (unreachable here)
                                                     │    ├─ 71 if totalIssued + v > cap
                                                     │    └─ 50/51 from token.totalSupply() (try/catch)
                                                     ├─ revert unless 0
                                                     └─ _afterMintChecked(v): re-check, totalIssued += v
                                   then _mint(to, v)      (balance changes after the notification)

Mint, Topology A
  minter ── CMTAT.mint ──▶ RuleEngine.transferred ──▶ for each rule: rule.transferred(...)
                                                     onlyBoundToken (msg.sender == engine)
  Any token bound to that engine reaches the same rule instance (IC-1).

Burn
  holder/burner ── CMTAT.burn ──▶ rule.transferred(burner, from, 0, v)  ─▶ OK, counter unchanged
```

## 7. External dependencies and trust assumptions

| Dependency | Version | Assumption |
|---|---|---|
| CMTAT | v3.3.0-rc4 (and v3.0.0 for tests) | Notifies the engine **before** moving the value, exactly once per operation |
| RuleEngine | v3.0.0-rc7 | The rule inherits the base `ERC3643ComplianceModule` (only `bindToken` / `unbindToken`); `_checkBoundToken` compares raw `msg.sender`; the engine itself may bind **several** tokens |
| OpenZeppelin | v5.7.0 | `AccessControlEnumerable`, `EnumerableSet` |
| solc | 0.8.38 (default profile), 0.8.30 (erc3643 profile) | Checked arithmetic; Cancun-or-later target |

## 8. Invariants

| ID | Invariant |
|---|---|
| INV-IC-1 | `totalIssued` never decreases |
| INV-IC-2 | While the rule is bound and attached from deployment, `totalIssued >= tokenContract.totalSupply()` |
| INV-IC-3 | A mint is accepted on the write path iff the view reports 0 for the same `(from, to, value)` and state |
| INV-IC-4 | Only the bound caller changes `totalIssued` |
| INV-IC-5 | At most one caller is bound |
| INV-MTS-1 | The stock `RuleMaxTotalSupply.transferred` writes no storage |
| INV-MTS-2 | `maxTotalSupply` changes only through the three setters, and never wraps |
| INV-B85 | While unbound, every view of a stateful rule reports 85 and every `transferred` reverts |

## 9. Threat disposition rule

Every threat ID above appears in `RESULT.md` as a numbered finding or as `NOT-A-FINDING` with a reason.
