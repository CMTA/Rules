# Analysis — what `RuleMaxTotalSupply` already covers in CMTA/Rules#16

> Companion to [`ISSUE_16_RULE_ISSUANCE_CAP.md`](./ISSUE_16_RULE_ISSUANCE_CAP.md).
>
> - **Question:** which requirements of [CMTA/Rules#16](https://github.com/CMTA/Rules/issues/16) does the existing `RuleMaxTotalSupply` already meet, and what is missing or could be improved?
> - **Basis:** source on `dev` (`RuleMaxTotalSupplyBase`, `TotalSupplyCapManager`, `CapAccounting`, `TokenSupplyReader`), its tests, and CMTAT `v3.0.0` (`0_CMTATBaseCommon.sol`, read from the `v3.0.0` tag of `lib/CMTAT`).

## 1. How `RuleMaxTotalSupply` works, in one paragraph

- **Kind of rule:** stateless validation rule. It stores only a configured `tokenContract` and a `maxTotalSupply`.
- **When it acts:** only on mints (`from == address(0)`), on both `transferred` overloads; the spender is ignored.
- **The check:** it reads `tokenContract.totalSupply()` and rejects the mint (code `50`) if `totalSupply + value > maxTotalSupply`.
- **Unreadable supply:** if `totalSupply()` cannot be read, it rejects mints with code `51` instead of reverting on the read path.
- **Never blocked:** transfers and burns.
- **Configuration:** `setMaxTotalSupply` and `setTokenContract` change it, gated on `DEFAULT_ADMIN_ROLE` (or the owner, for the Ownable2Step variant). Each emits an event.

**It works on CMTAT v3.0.0 as is.** In v3.0.0, `_mintOverride` calls `_checkTransferred(address(0), address(0), account, value)` *before* `ERC20MintModuleInternal._mintOverride`, so:
- every mint reaches the rule on the 3-argument path with `from == address(0)`;
- `totalSupply()` does not yet include the amount being minted, which is the accounting the rule assumes.

## 2. Requirement-by-requirement coverage

| # | Requirement in #16 | Covered by `RuleMaxTotalSupply`? | Detail |
| --- | --- | --- | --- |
| R1 | One cap per token, independent of the minter | ✅ **Yes** | One `maxTotalSupply` per instance; the spender is never read |
| R2 | Each mint decrements the remaining cap; revert if `value` exceeds it | ✅ **Yes, in effect** | The remaining room is `maxTotalSupply − totalSupply()`, so it falls by exactly `value` on each mint. Over-cap mints revert with `RuleMaxTotalSupply_InvalidTransfer` (code `50`). Nothing is stored: the token's own supply is the counter |
| R3 | **Non-replenishing**: burns do not restore the cap | ❌ **No — the core gap** | A burn lowers `totalSupply()`, so it frees room for a new mint (pinned by `testBurningFreesHeadroomForANewMint`). The rule caps *outstanding* supply, not *cumulative issuance* |
| R4 | Optional replenishing mode (burn restores the cap) | ✅ **Yes, it is the only mode** | And more accurately than a counter could: every burn lowers `totalSupply()`, including the burns that bypass the engine (forced burns), so the cap never drifts |
| R5 | Cap changed only by operator functions (set / increase / decrease), with events | ⚠️ **Partly** | `setMaxTotalSupply` + `MaxTotalSupplyUpdated(newMax)`, also emitted at construction. Missing: `increase` / `decrease`, the previous value in the event, and a dedicated operator role (§3.2–§3.4) |
| R6 | `transferred` callable only by the bound token (`msg.sender`) | ✅ **Not needed** | Both `transferred` overloads are `view`: there is no state for a foreign caller to corrupt, it can only make the call revert. The rule reads the supply of its *configured* `tokenContract`, not of `msg.sender`. The equivalent risk is misconfiguration (§3.6), not caller spoofing |
| R7 | Views reflect the remaining cap | ⚠️ **Partly** | `detectTransferRestriction(address(0), to, v)`, `canTransfer` and the `…From` variants return code `50` / `false` exactly when the mint would be rejected, so a front end can ask "may I mint `v`?". But no view returns **how much** may still be minted (§3.1) |
| R8 | The 4-argument overload applies the same logic | ✅ **Yes** | `_detectTransferRestrictionFrom` ignores the spender and delegates to the 3-argument check, so CMTAT ≥ v3.3 (mint on the 4-argument path) behaves identically |
| — | Works with CMTAT v3.0.0, Standard and Debt | ✅ **Yes** | See §1. The Debt variant has no ERC-1404 layer on the token, but the rule's own views do not depend on it |
| — | Works in both topologies | ✅ **Yes, identically** | No binding, so it behaves the same set directly on the token (CMTAT v3.0.0's `setRuleEngine` has no ERC-165 gate) or behind a `RuleEngine` |
| — | Emergency freeze of minting | ✅ **Yes** | `setMaxTotalSupply(0)` (pinned by `testSetMaxTotalSupplyToZero`), or any value at or below the current supply (`testLoweringTheCapBelowTheSupplyBlocksFurtherMints`). Burns and transfers keep working, so holders are never trapped |

**Summary.**
- R1, R2, R4, R6 and R8 are covered.
- R5 and R7 are partly covered; the missing pieces are small, non-breaking additions to `RuleMaxTotalSupply` (§3).
- R3, the issue's **default** behaviour, is not covered and cannot be. Telling "a burn" apart from "a burn that should not free capacity" needs memory of past issuance, and `RuleMaxTotalSupply` is deliberately stateless. That is the case for a separate rule.

## 3. Gaps and possible improvements to `RuleMaxTotalSupply`

These are independent of whether `RuleIssuanceCap` is built. Each is useful to the replenishing use case that `RuleMaxTotalSupply` already serves.

### 3.1 No "remaining mintable" view (R7) — **done**

> **Update:** implemented as described below (`TotalSupplyCapManager._remainingMintable`, `RuleMaxTotalSupplyBase.remainingMintable`). R7 is now fully covered.

Today a front end must compute `maxTotalSupply() − tokenContract().totalSupply()` itself, with two problems:
- it must handle a cap lowered below the supply, where the subtraction underflows;
- it gets no signal when `totalSupply()` is unreadable.

`RuleMaxBalance` already solves this for its cap with `remainingCapacity(to) → (uint8 restrictionCode, uint256 headroom)`, and the helper it uses (`CapAccounting._capHeadroom`) is already inherited by `RuleMaxTotalSupply`, unused.

```solidity
/// @return restrictionCode 0, or CODE_SUPPLY_ORACLE_UNAVAILABLE (51) when totalSupply() is unreadable.
/// @return headroom maxTotalSupply - totalSupply, saturating at 0; meaningless when the code is non-zero.
function remainingMintable() public view virtual returns (uint8 restrictionCode, uint256 headroom);
```

- **Placement:** the internal half goes in `TotalSupplyCapManager` (`_remainingMintable() → (bool, uint256)`) and the public, code-returning half in `RuleMaxTotalSupplyBase`, mirroring the `BalanceCapManager` / `RuleMaxBalanceBase` split.
- **Compatibility:** non-breaking; adds a selector, changes no storage.
- **ERC-3643 variant:** `RuleMaxTotalSupplyERC3643` inherits it unchanged, since a view always runs before the movement.

### 3.2 No `increaseMaxTotalSupply` / `decreaseMaxTotalSupply` (R5) — **optional**

`setMaxTotalSupply` is absolute. The relative forms the issue asks for matter in one real case:
- two pending governance actions (say, two multisig proposals each authorising a capital increase of `N`), both computed from the same old cap;
- with `set`, the second overwrites the first, and the cap rises by `N` instead of `2N`;
- with `increase`, both apply.

`RuleMintAllowance` already offers `increase` / `decrease` for this reason. The cost is two functions plus tests, and the change is non-breaking.

Counter-argument: a corporate resolution usually fixes an **absolute** authorised amount, which `set` expresses directly. Recommend adding them only if the requester's governance issues relative changes.

### 3.3 `MaxTotalSupplyUpdated` carries only the new value — **done**

> **Update:** implemented in v0.7.0 as `MaxTotalSupplyUpdated(uint256 previousMaxTotalSupply, uint256 newMaxTotalSupply)` and listed under "Breaking change" in the changelog. The event was replaced, not duplicated by a second one.

`event MaxTotalSupplyUpdated(uint256 newMaxTotalSupply)` lets an indexer rebuild the history only by replaying every event. Emitting `(previous, new)` makes each event self-describing, which an auditor reading a single transaction appreciates.

**This is an ABI change:** the event signature and topic change, and `test/Events/ConstructorEvents.t.sol` hashes the current signature. Do it only in a release that already lists breaking changes, or add it as a second event. Low value; listed for completeness.

### 3.4 Cap management is tied to `DEFAULT_ADMIN_ROLE` — **done**

> **Update:** implemented. `setMaxTotalSupply` requires `MAX_TOTAL_SUPPLY_ROLE` and `setTokenContract` stays admin-only, through a second hook `_authorizeTokenContractManager`. The constant lives in the AccessControl deployable only.

`_authorizeMaxTotalSupplyManager` uses `onlyRole(DEFAULT_ADMIN_ROLE)`. Comparable rules use a dedicated role:
- `RuleMaxBalance`: `MAX_BALANCE_ROLE`;
- `RuleMintAllowance`: `ALLOWANCE_OPERATOR_ROLE`;
- `RuleSanctionsList`: `SANCTIONLIST_ROLE`.

The issue speaks of "operator functions". A `MAX_TOTAL_SUPPLY_ROLE` would let an issuer delegate cap changes, for example to a corporate-secretary key, without granting full admin.

- **Backward compatibility:** the admin implicitly holds every role (`AccessControlModuleStandalone.hasRole`), so existing deployments are unaffected.
- **`setTokenContract`:** it should stay admin-only. Repointing the observed token disables the cap far more thoroughly than changing its value.

### 3.5 Behaviours that are correct but undocumented in `RuleMaxTotalSupply.md` — **done**

> **Update:** now documented in `RuleMaxTotalSupply.md` ("What the cap measures", "Behaviour by token operation", "One instance per token"), each row with the test that pins it. The detach / re-attach row gained a test, `testSupplyMintedWhileDetachedIsCountedOnReattach`.

Each line was checked against CMTAT v3.0.0. They are exactly the questions the issue raises:

| Situation | Behaviour | Why it matters for #16 |
| --- | --- | --- |
| Cap set below the current supply | Every further mint rejected; burns and transfers pass | A legitimate freeze lever, not a misconfiguration |
| `burnAndMint(from, to, burnAmt, mintAmt)` | The burn runs first and lowers `totalSupply()`, so the mint leg needs room only for `mintAmt − burnAmt` | A correction or reissue does **not** consume the cap. This is the opposite of a non-replenishing counter, where the mint leg counts in full |
| `crosschainMint` / `crosschainBurn` (Standard) | Counted like `mint` / `burn` | Bridged round trips are net zero. Safe for bridged tokens, unlike a cumulative counter |
| `forcedTransfer(from, address(0), v)` | Bypasses the engine, but lowers `totalSupply()` | The freed room is visible at the next mint. A counter would never see it |
| Supply minted before the rule was installed | Counted, because the cap is absolute | Set `maxTotalSupply = existing supply + newly authorised amount` (for example, after a capital increase) |
| `setRuleEngine(address(0))` / `removeRule` | Lifts the cap. On re-attach, the cap is re-evaluated against the real supply | No drift. A counter-based rule silently misses the mints made while detached |

The last four rows are the strongest argument (made in the plan document) for **not** building a replenishing *counter*. The existing rule already has the semantics the issue asks for in R4, without the failure modes.

### 3.6 One instance per token, with no on-chain guard — **known, documented, unchanged**

The rule reads the supply of `tokenContract`, never of the caller. One instance added to two RuleEngines (or set on two tokens) caps both against the first token's supply. This is already documented in `CLAUDE.md` and `RULE_SEMANTICS.md`.

A guard would mean making a stateless validation rule bindable, which is a library-wide decision. #16 does not change that assessment. Note only that R6 ("callable only by the bound token") would **not** fix it either: the risk is reading the wrong token's supply, not being called by the wrong caller.

### 3.7 Test gaps — **done**

> **Update:** all four are now covered by `test/CMTATv3.0.0/RuleMaxTotalSupplyV300.t.sol`, which runs on a real CMTAT v3.0.0 token (Standard and Debt, direct and behind a `RuleEngine`). The cross-chain test runs on Standard only. The table is kept as the record of what was missing.

| Missing test | Why |
| --- | --- |
| Integration against a **real CMTAT v3.0.0** token (3-argument mint path), in both topologies | v3.0.0 compatibility is the premise of #16, and today it is established only by reading the source. `lib/RuleEngine` pins `CMTATv3.0.0` and tests its routing (`CMTATOperationRoutingV3.t.sol`); the same approach applies here |
| `burnAndMint` needs room only for the net increase | Pins the §3.5 row; a refactor that moved the check after both legs would change it silently |
| `crosschainMint` is capped; `crosschainBurn` frees room | Same reason |
| Forced burn frees room at the next mint | Pins the advantage over a counter |

## 4. Can `RuleMaxTotalSupply` be stretched to cover R3?

| Idea | Verdict |
| --- | --- |
| **Operator lowers the cap after every burn** (manual non-replenishing) | Works only with discipline. It races with mints between the burn and the cap change, and it misses forced burns unless the operator watches for them. Acceptable as a stop-gap, not as a control |
| **Subclass that overrides `_currentSupply` to return a stored `totalIssued`** (the documented storage seam) | **No.** Both `transferred` overloads are `view` in `RuleMaxTotalSupplyBase`, and Solidity cannot override a `view` function with a state-changing one, so the counter could never be incremented. `tokenContract` and code `51` would also become meaningless. Changing the base would put a write path into a rule whose safety rests on having none |
| **Reuse only `CapAccounting` in a new rule** | **Yes.** `CapAccounting` is stateless and phase-agnostic, so `RuleIssuanceCap` can call `_capExceededBy(totalIssued, issuanceCap, value)` and `_capHeadroom(...)` and share the comparison with the three existing cap rules. Adopt this in the plan document |

So R3 needs a separate rule, as proposed in the plan. `RuleMaxTotalSupply` remains the right answer for R4. For instruments that need both limits, use the two rules side by side in one `RuleEngine`.

## 5. Recommended actions

| Priority | Action | Kind |
| --- | --- | --- |
| 1 | Answer #16: R4 (replenishing) is already served by `RuleMaxTotalSupply` on CMTAT v3.0.0. R3 (non-replenishing) needs the new `RuleIssuanceCap` | Issue reply |
| 2 | ~~Add `remainingMintable()` (§3.1)~~ **Done** | Code, non-breaking |
| 3 | ~~Document the §3.5 behaviours in `doc/technical/contracts/RuleMaxTotalSupply.md`~~ **Done** | Documentation |
| 4 | ~~Add the §3.7 tests, starting with real CMTAT v3.0.0~~ **Done** (`test/CMTATv3.0.0/`) | Tests |
| 5 | Optional: ~~dedicated `MAX_TOTAL_SUPPLY_ROLE` (§3.4)~~ **done**; `increase` / `decrease` (§3.2) still open | Code, non-breaking |
| 6 | ~~Optional: `(previous, new)` event (§3.3)~~ **Done** (breaking: new event topic) | Code, ABI change |
| 7 | Update the plan document so that `RuleIssuanceCap` reuses `CapAccounting` (§4) | Plan |
