# Test improvement — CMTA Rules v0.7.0 (delta since v0.6.0)

> AI-assisted review. Threat IDs refer to [`THREAT_MODEL.md`](./THREAT_MODEL.md).

## 1. Claude Skills Used

| Skill | Contribution |
|---|---|
| `sc-analyse-and-test-solidity` | Test-plan structure |
| `rwa-token-audit` | View-vs-enforcement equivalence (IC-5), chokepoint and idempotency checks (CH-1, CH-2) |
| `cmtat-audit` | Which CMTAT behaviours are design choices and need no test |
| `audit-access-control` | Role-boundary and binding tests (AC-1 to AC-5) |

## 2. Current coverage

`forge coverage` reports 100% of `src/` (lines, statements, branches, functions) before this audit. What already
pins the delta:

| Area | Existing tests |
|---|---|
| `RuleIssuanceCap` unit behaviour, re-phased write path, events, broken token | `test/RuleIssuanceCap/RuleIssuanceCapUnit.t.sol` |
| Real CMTAT v3.3, Topology A and B, burn does not restore | `test/RuleIssuanceCap/RuleIssuanceCapCMTATIntegration.t.sol` |
| Real CMTAT v3.0.0, Standard and Debt, direct and engine; `burnAndMint`, `crosschainMint`, detach / re-attach | `test/CMTATv3.0.0/RuleIssuanceCapV300.t.sol` |
| Cap invariants with mutation controls (counter never decreases, issuance ≥ supply, mints fail only with the rule error) | `test/invariant/RuleInvariants.t.sol` (`IssuanceCapInvariants`, `MaxTotalSupplyInvariants`) |
| Code 85 on every view of the three stateful rules | `test/Binding/UnboundRuleViews.t.sol` |
| Both `IRule` ids advertised by every rule | `test/InterfaceId/RuleInterfaceIdCompatibility.t.sol` |
| Stock `RuleMaxTotalSupply` writes nothing on `transferred` | `testTransferredNeverWritesStorage` |

### Gaps

Line coverage is complete. The missing tests are about **deployment shapes and extension**, which coverage cannot see:

- a RuleEngine serving **two** tokens with one `RuleIssuanceCap` (IC-1);
- a binding that does not match `tokenContract` (IC-2);
- issuance between deployment and attachment (IC-3);
- the read path and the write path compared over random state, not at chosen points (IC-5);
- a subclass of `RuleMaxTotalSupplyBase` that uses the hook without gating `transferred` (AC-5);
- role separation between the cap role and `setTokenContract` from the cap manager's side (AC-1);
- the full range of `increaseMaxTotalSupply` / `decreaseMaxTotalSupply` inputs (MTS-2);
- code 85 as an integrator sees it through a RuleEngine (B85-1).

## 3. Missing test cases

| Test | Threat | Type |
|---|---|---|
| Token B's mint is recorded in the counter of token A's cap behind a shared engine | IC-1 | Integration (CMTAT v3.3 + RuleEngine) |
| Token B is blocked by token A's history; token B's supply is never read | IC-1 | Integration |
| Binding an unrelated address is accepted; the token's mint reverts while the view reports OK | IC-2 | Integration |
| Mint and burn before attachment are not counted | IC-3 | Integration |
| Live-supply leg blocks minting after a detached over-mint | IC-3 | Integration (control) |
| No caller except the bound one moves the counter, through either overload or `created` | AC-2, INV-IC-4 | Fuzz |
| Second `bindToken` reverts; counter survives unbind / re-bind | AC-3, INV-IC-5 | Unit |
| `setTokenContract` reverts for the admin | AC-4 | Unit |
| View code == 0 iff the bound write succeeds, for random counter / supply / cap / amount; 3-arg and 4-arg views agree | IC-5, IC-10, INV-IC-3 | Fuzz |
| Zero-value mint refused on both paths once the cap is below the counter | IC-5 | Unit |
| Stock `transferred` callable by anyone and writes nothing | AC-5, INV-MTS-1 | Unit |
| A naive subclass recording in `_afterMintChecked` is drivable by anyone | AC-5 | Unit |
| Cap role cannot call `setTokenContract` | AC-1 | Unit |
| Increase / decrease never wrap; named errors on out-of-range amounts | MTS-2, INV-MTS-2 | Fuzz |
| Raising an issuance cap re-opens minting after burns | IC-6 | Integration |
| Through a RuleEngine, an unbound `RuleIssuanceCap` reports 85 for transfers and mints, and the mint reverts | B85-1, INV-B85 | Integration |

## 4. Implementation priority

| Priority | Group | Threats | Type |
|---|---|---|---|
| P1 | Multi-tenant engine and mis-binding | IC-1, IC-2 | Integration |
| P1 | View / enforcement equivalence | IC-5, IC-10 | Fuzz |
| P1 | Write-path gating, including the subclass hazard | AC-2, AC-5 | Fuzz, unit |
| P2 | Issuance outside the attachment window | IC-3 | Integration |
| P2 | Setter arithmetic and role separation | MTS-2, AC-1, IC-6 | Fuzz, unit |
| P3 | Code 85 through the engine | B85-1 | Integration |

All of the above are implemented in `test/ThreatModel/ThreatModelV070Tests.t.sol` (16 tests, 4 of them fuzz at 256
runs).
