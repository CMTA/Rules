# Rule Semantics — comparison table

[TOC]

The rules in this library answer the same two questions — *may this transfer proceed?* (read path) and *record/enforce it* (write path) — but they answer with **different conventions**. In particular they differ on **whether they screen the spender**, **how they treat mint (`from == address(0)`) and burn (`to == address(0)`)**, and **what happens when their external oracle/registry is unset**. This page is the single place those differences are laid out side by side so an integrator does not have to read each rule's source to learn them.

Each cell reflects the rule's own `_detectTransferRestriction*` logic; behaviour is identical on the enforcement path (`transferred`), which reverts on any non-`TRANSFER_OK` code.

Legend: ✅ screened / can block · ❌ not screened · ⚙️ conditional (see note) · n/a not applicable.

---

## 1. Who each rule screens

"Direct" = a plain `transfer` (`transferred(from, to, value)`). The spender columns apply to the 4-arg `transferred(spender, from, to, value)` path; **mint** is that path with `from == address(0)` and `spender == minter`, **burn** with `to == address(0)` and `spender == burner` (CMTAT v3.3+).

| Rule | `from` (direct) | `to` (direct) | spender on `transferFrom` | spender on **mint** | spender on **burn** |
|---|---|---|---|---|---|
| `RuleWhitelist` | ✅ must be listed | ✅ must be listed | ⚙️ only if `checkSpender` | ❌ exempt | ❌ exempt |
| `RuleWhitelistWrapper` | ✅ listed in ≥1 child | ✅ listed in ≥1 child | ⚙️ only if `checkSpender` | ❌ exempt | ❌ exempt |
| `RuleReceiverWhitelist` | ❌ **never** [1b] | ✅ must be listed | ❌ never | ✅ receiver must be listed | ❌ exempt |
| `RuleSpenderWhitelist` | ❌ always allowed | ❌ always allowed | ✅ always (rule's purpose) | ❌ exempt | ❌ exempt |
| `RuleBlacklist` | ✅ blocks if listed | ✅ blocks if listed | ✅ blocks if listed | ✅ blocks listed minter [1] | ✅ blocks listed burner [1] |
| `RuleSanctionsList` | ✅ blocks if sanctioned | ✅ blocks if sanctioned | ✅ blocks if sanctioned | ✅ blocks sanctioned minter [1] | ✅ blocks sanctioned burner [1] |
| `RuleMaxTotalSupply` | ⚙️ mint only [2] | ❌ | ❌ ignored | ❌ caps supply, not minter | ❌ |
| `RuleChainlinkPoR` | ⚙️ mint only [2b] | ❌ | ❌ ignored | ❌ caps supply, not minter | ❌ |
| `RuleIdentityRegistry` | ⚙️ only if `checkSender` [3] | ✅ **must be verified** (ERC-3643) [3] | ⚙️ only if `checkSpender` [3] | ❌ exempt [3] | ❌ exempt [3] |
| `RuleERC2980` | ⚙️ frozen-check only [4] | ✅ frozen-check + must be whitelisted | ✅ frozen-check | ✅ blocks frozen minter | ✅ blocks frozen burner |
| `RuleConditionalTransferLight` | ❌ per-tuple approval [5] | ❌ per-tuple approval [5] | ❌ spender ignored | ❌ exempt | ❌ exempt |
| `RuleConditionalTransferLightMultiToken` | ❌ per-tuple approval [5] | ❌ per-tuple approval [5] | ❌ spender ignored | ❌ exempt | ❌ exempt |
| `RuleMintAllowance` | ❌ not tracked | ❌ not tracked | ❌ not tracked | ✅ **debits minter quota** [6] | ❌ not tracked |

## 2. Operational characteristics

| Rule | When its oracle/registry is unset | Stateful on transfer? [7] | Authoritative pre-flight view | Restriction codes |
|---|---|---|---|---|
| `RuleWhitelist` | n/a (local address set) | ❌ | `canTransfer` / `canTransferFrom` | 21–25 |
| `RuleWhitelistWrapper` | empty wrapper ⇒ **all rejected** (fail-closed); children must be allow-lists [12b] | ❌ | `canTransfer` / `canTransferFrom` | 21–25 |
| `RuleReceiverWhitelist` | n/a (local address set) | ❌ | `canTransfer` / `canTransferFrom` | 81 |
| `RuleSpenderWhitelist` | n/a (local address set) | ❌ | `canTransfer` (always ✓) / `canTransferFrom` | 66 |
| `RuleBlacklist` | n/a (local address set) | ❌ | `canTransfer` / `canTransferFrom` | 36–38 |
| `RuleSanctionsList` | oracle == 0 ⇒ **all allowed** (fail-open) [8] | ❌ | `canTransfer` / `canTransferFrom` | 30–32 |
| `RuleMaxTotalSupply` | token contract required (non-zero, has code, `totalSupply()` callable); a token that later reverts ⇒ **mints rejected** (fail-closed, code 51) | ❌ | `canTransfer` / `canTransferFrom` [9] | 50–51 |
| `RuleChainlinkPoR` | feed required (non-zero contract); broken/stale feed ⇒ **mints rejected** (fail-closed) [2b] | ❌ | `canTransfer` / `canTransferFrom`, plus `maxBackedSupply()` | 75–79 |
| `RuleIdentityRegistry` | registry == 0 ⇒ **all allowed** (fail-open) [8] | ❌ | `canTransfer` / `canTransferFrom` | 55–57 |
| `RuleERC2980` | n/a (local lists) | ❌ | `canTransfer` / `canTransferFrom` | 60–65 |
| `RuleConditionalTransferLight` | n/a (needs `bindToken`) | ✅ consumes an approval | `canTransfer` / `canTransferFrom` | 46 |
| `RuleConditionalTransferLightMultiToken` | n/a (needs `bindToken`) | ✅ consumes an approval | `canTransferForToken` / `detectTransferRestrictionForToken` [10] | 46 |
| `RuleMintAllowance` | n/a (needs `bindToken`) | ✅ debits quota | ⚠️ `canTransferFrom` **only** [11] | 70 |

---

## 3. Overload surface (ERC-7943 `tokenId` / `ITransferContext`)

Not every rule exposes the same entrypoints. The ERC-7943 `tokenId` overloads and the `ITransferContext` struct entrypoints come from `RuleNFTAdapter`, and **only the rules that inherit it have them**. The omission is deliberate: `RuleMaxTotalSupply` and `RuleChainlinkPoR` cap a fungible supply, and the conditional-transfer / mint-allowance rules key on fungible amounts, so a `tokenId` dimension would be meaningless for them.

| Rule | ERC-7943 `tokenId` overloads [12] | `transferred(FungibleTransferContext)` | `transferred(MultiTokenTransferContext)` |
|---|---|---|---|
| `RuleWhitelist` | ✅ | ✅ | ✅ |
| `RuleWhitelistWrapper` | ✅ | ✅ | ✅ |
| `RuleReceiverWhitelist` | ✅ | ✅ | ✅ |
| `RuleBlacklist` | ✅ | ✅ | ✅ |
| `RuleSpenderWhitelist` | ✅ | ✅ | ✅ |
| `RuleSanctionsList` | ✅ | ✅ | ✅ |
| `RuleERC2980` | ✅ | ✅ | ✅ |
| `RuleIdentityRegistry` | ✅ | ✅ | ✅ |
| `RuleMaxTotalSupply` | ❌ | ❌ | ❌ |
| `RuleChainlinkPoR` | ❌ | ❌ | ❌ |
| `RuleConditionalTransferLight` | ❌ | ✅ | ❌ |
| `RuleConditionalTransferLightMultiToken` | ❌ | ✅ | ❌ |
| `RuleMintAllowance` | ❌ | ❌ | ❌ |

The `tokenId` parameter is **always ignored** by the rules that accept it — `RuleNFTAdapter` exists purely to re-expose the same restriction logic under the ERC-7943 signatures. Entrypoints describing the same transfer therefore return the same answer, asserted for every rule above in `test/TransferContext/OverloadParity.t.sol`.

**How each interface signals a direct transfer differs, and that decides the routing.** An owner moving their own tokens reaches the adapter as `spender == from` on the ERC-7943 overloads (the spec calls that parameter "the address performing the transfer (owner/operator)") and as `sender == from` on the `ctx` entrypoints, whereas the CMTAT path signals it with the 3-arg overload or `spender == address(0)`:

| Interface | Direct transfer arrives as | Delegated transfer arrives as |
|---|---|---|
| CMTAT 3-arg / 4-arg | the 3-arg overload, or `spender == address(0)` | `spender != address(0)` |
| ERC-7943 `tokenId` overloads | `spender == from` | `spender != from` |
| `ITransferContext` | `sender == from`, or `sender == address(0)` | `sender != from` |

Every adapter entrypoint normalises `spender == from` to the **direct** hook. The 4-arg CMTAT path deliberately does not, because its own convention already distinguishes the two — so `4-arg(spender == from)` and the ERC-7943 5-arg call with the same arguments describe *different* transfers and are expected to differ. Do not "align" them: an owner-initiated ERC-721 `transferFrom` would then be screened as delegated, which `RuleSpenderWhitelist` documents as always allowed. Both halves are pinned by `test_NM6_SelfSpenderIsNotScreenedByTheSpenderWhitelist` and `test_NM6_CmtatFourArgPathKeepsScreeningASelfSpender`.

**Access control on the `ctx` entrypoints (threat `AC-5`).** `transferred(FungibleTransferContext)` / `transferred(MultiTokenTransferContext)` are `external` with **no caller restriction** on the validation rules. That is safe because those rules' hooks are `view`: an arbitrary caller can run the check and be reverted by it, but cannot mutate any state. The stateful multi-token rule guards its own `ctx` entrypoint with `onlyTransferExecutor`.

## 4. Notes & caveats

> **Mint/burn permission is an explicit flag, never `address(0)` list membership.** `RuleWhitelist`, `RuleWhitelistWrapper` and `RuleERC2980` each expose `allowMint` / `allowBurn` — set together by the `allowMintBurn` constructor parameter, then independently settable via `setAllowMint` / `setAllowBurn` (e.g. to permanently close issuance while keeping redemptions open). The zero address can **never** enter any list (single adds revert, batch adds skip it), so the standardized getters stay truthful: `isVerified(address(0))` and `whitelist(address(0))` are always `false`, as ERC-3643 and ERC-2980 require. A blocked mint returns a dedicated code (`24` for the whitelist rules, `64` for ERC-2980) rather than the misleading "sender not whitelisted". The flag gates the **operation only**: a permitted mint still requires a whitelisted *recipient*, and a permitted burn a whitelisted *sender*.


1. **Deny-lists intentionally screen the minter/burner.** `RuleBlacklist` and `RuleSanctionsList` do **not** exempt mint/burn from the spender check, so a blacklisted/sanctioned address cannot mint or burn. This is correct fail-closed behaviour for a deny-list (threat `BL-1`), the mirror image of the whitelist rules, which exempt mint/burn because the minter acts on its own authority rather than as a delegated spender.

1b. **`RuleReceiverWhitelist` screens the receiver and nothing else** — the CMTAT-side expression of ERC-3643's eligibility rule. The sender and the spender are never checked, deliberately: screening the sender **traps de-listed holders**, and ERC-3643 checks only the receiver precisely so a lapsed investor can still exit. Mint is screened on the receiver like any other transfer (no `allowMint` flag); burn is exempt, because `address(0)` can never be listed and would otherwise be rejected on every burn. Equivalence with the standard is pinned against the real vendored token in `test/ERC3643Real/ERC3643ReceiverWhitelistParity.t.sol`. Use `RuleWhitelist` when you want both parties screened. See [RuleReceiverWhitelist.md](../contracts/RuleReceiverWhitelist.md).

2. **`RuleMaxTotalSupply` only acts on mints.** `_detectTransferRestriction` returns `TRANSFER_OK` unless `from == address(0)`; it caps *total supply*, so the "screened party" is the mint operation, not any address. The spender is ignored on every path.

2b. **`RuleChainlinkPoR` only acts on mints, and fails closed for mints only.** Like `RuleMaxTotalSupply` it returns `TRANSFER_OK` unless `from == address(0)`, and ignores the spender. The cap is not static but read live from a Chainlink Proof of Reserve feed: `totalSupply + value` must stay within the reported reserves, scaled from the feed's decimals to the token's. The limit equals the reserves exactly — there is no margin parameter. Feed failures are reported by kind: code `79` when no usable response could be obtained (`decimals()` or `latestRoundData()` reverted, or the feed reports more than `MAX_FEED_DECIMALS`), code `77` when a round was returned but is unusable (negative reserve, incomplete round), and code `76` when the answer is older than `maxStalenessSeconds`. A `tokenContract` whose `totalSupply()` reverts yields code `78`. **One instance protects one token:** the rule reads `totalSupply()` from its configured `tokenContract`, not from the token that triggered the check, so sharing an instance across two RuleEngines silently evaluates both against the first token's supply and feed (same exposure as `RuleMaxTotalSupply`; see [One instance per protected token](../contracts/RuleChainlinkPoR.md#one-instance-per-protected-token)). Both block **minting only** — transfers and burns still pass, so a lapsed feed never traps holders. The read path is guarded (`code.length` check, `try/catch`, saturating arithmetic) so it can return these codes without reverting. See [RuleChainlinkPoR.md](../contracts/RuleChainlinkPoR.md).

3. **`RuleIdentityRegistry` is ERC-3643 conformant: only the RECEIVER is verified** (improvement I-1, finding **F-1** fixed). The spec mandates exactly one check — *"The receiver MUST be whitelisted on the Identity Registry and verified"* — and explicitly states that `transferFrom` "works the same way", that `mint` "only require[s] the receiver", and that `burn` "bypasses all checks on eligibility". The sender, spender and minter are therefore **not** screened by default. Checking the sender would **trap de-listed holders**: ERC-3643 screens only the receiver precisely so an investor whose identity lapses can still exit their position by sending to a verified counterparty. Stricter screening is available as an explicit opt-in via `checkSender` / `checkSpender` (both default `false`); mint and burn stay exempt from the spender check even when `checkSpender` is on.

4. **`RuleERC2980` does not require the sender to be whitelisted** — only that the sender is *not frozen*; only the recipient must be whitelisted (threat `E29-1`, ERC-2980 semantics). Note also that freezing `address(0)` blocks all mints and that burns require `address(0)` to be whitelisted via the `allowBurn` constructor flag (threat `E29-2`).

5. **Conditional-transfer rules screen the (from, to, value) tuple, not identities.** A transfer is allowed iff an operator has recorded an approval for that exact tuple; the individual addresses are never checked against a list. Mint/burn are exempt (`from`/`to == address(0)` returns early).

6. **`RuleMintAllowance` is the only rule that *uses* the mint spender.** On the 4-arg path with `from == address(0)`, it debits `mintAllowance[spender]`. On the 3-arg path (no spender) it performs no deduction, so it must be deployed against the CMTAT/RuleEngine v3.3+ spender-aware path.

7. **Stateful** means the rule writes storage inside the `transferred` callback. Validation rules are read-only; the three operation rules (`RuleConditionalTransferLight`, `…MultiToken`, `RuleMintAllowance`) mutate state and require `bindToken`.

8. **Fail-open when unset.** `RuleSanctionsList` (oracle == `address(0)`) and `RuleIdentityRegistry` (registry == `address(0)`) return `TRANSFER_OK` for everything — screening is disabled, not fail-closed (threats `SL-1`/`SL-2`). `clearSanctionListOracle()` / `clearIdentityRegistry()` are single-call kill switches for that screening. Compose with another rule if a hard floor is required.

9. **`RuleMaxTotalSupply` views are overflow-safe** (finding **F-2**, fixed): `detectTransferRestriction` / `canTransfer` return code `50` instead of reverting when `currentSupply + value` would overflow.

10. **`RuleConditionalTransferLightMultiToken` is direct-binding-only, and its `detectTransferRestriction` depends on `msg.sender`.** Approvals are recorded under the `token` argument but *consumed* under `msg.sender`, so the rule **must be bound directly to each token** (`CMTAT.setRuleEngine(rule)`) and **must not be added to a `RuleEngine`** — behind an engine it either reverts or silently loses all per-token isolation (finding **F-4**; full case analysis in [RuleConditionalTransferLightMultiToken.md](../contracts/RuleConditionalTransferLightMultiToken.md#deployment-topology--why-a-ruleengine-does-not-work)). For the same reason `detectTransferRestriction` / `canTransfer` derive the token key from the caller, so an off-chain `eth_call` from a non-bound address always reads "not approved" (code 46) even for an approved transfer (threat `CTL-4`, finding **F-8**). Use the caller-explicit **`detectTransferRestrictionForToken(token, …)`** / **`canTransferForToken(token, …)`** views for pre-flight — they take the token as a parameter and give every caller the real answer.

11. **`RuleMintAllowance.canTransfer` / `detectTransferRestriction` are NOT authoritative** (finding **F-7**): they are hardcoded to "allowed" because the 3-arg signature has no minter identity. Pre-flight a mint with `canTransferFrom(minter, address(0), to, value)`. See [RuleMintAllowance.md](../contracts/RuleMintAllowance.md#eligibility-views-which-one-is-authoritative).

12b. **`RuleWhitelistWrapper` children must be ALLOW-lists, and this is now enforced.** `IAddressList` carries *membership*, not polarity: the wrapper ORs its children's `areAddressesListed` answers and reads `true` as **eligible**. A `RuleBlacklist` implements that interface identically and advertises the same ids, so ERC-165 alone could not tell them apart — adding one made its blacklisted addresses whitelisted and `isVerified` returned `true` for them (`NM-20`). Polarity is now declared rather than inferred: **`IAddressListPolarity`** (`0xdc4efe10`) adds a single `isAllowList()`, and `addRule` requires the interface *and* a `true` answer, on top of the `IAddressListBatchQuery` check from `NM-18`. **Absence of the polarity declaration is a refusal, never an assumed allow-list** — the only reading that fails closed. `RuleWhitelist` and `RuleReceiverWhitelist` declare `true`; `RuleBlacklist` declares `false`; `RuleSpenderWhitelist` deliberately declines, because its set is permitted *spenders* rather than permitted *holders* and polarity alone would mislead. A nested wrapper is refused at the first check, since it does not implement `areAddressesListed` — **deliberately**: an OR nested in an OR is algebraically flat (`OR(OR(a,b),OR(c,d))` ≡ `OR(a,b,c,d)`), so nesting adds no expressive power, while costing multiplicatively (~8.8k gas per child, and the rejected path never early-exits) and opening an `A → B → A` cycle class with no cheap on-chain defence. AND-of-ORs is available by putting several wrappers in the `RuleEngine`, which returns the first non-zero code. `NM-19`, declined.

12. **The ERC-7943 `tokenId` overloads** are `detectTransferRestriction(from,to,tokenId,value)`, `detectTransferRestrictionFrom(spender,from,to,tokenId,value)`, `canTransfer(from,to,tokenId,amount)`, `canTransferFrom(spender,from,to,tokenId,value)`, `transferred(from,to,tokenId,value)` and `transferred(spender,from,to,tokenId,value)` — all supplied by `RuleNFTAdapter`. Per ERC-7943, `amount`/`value` MUST be `1` for ERC-721. The rules ignore `tokenId` entirely; it exists so an ERC-721/ERC-1155 token can call the same compliance rule without a shim.

## 5. Cap rules: the two seams for an ERC-3643 variant

`RuleMaxBalance`, `RuleMaxTotalSupply` and `RuleChainlinkPoR` all end in the same question — *would this movement leave an observed figure above its cap?* — and that question has two free variables. Each is a documented `internal virtual` hook, so a variant overrides one line rather than reimplementing a rule.

The shared arithmetic lives in [`CapAccounting`](../../../src/rules/validation/abstract/core/CapAccounting.sol), which holds **no storage** and is deliberately ignorant of both variables.

### Seam 1 — accounting phase: `_detectTransferRestrictionOnNotify`

**The stock rules assume the token calls them BEFORE it moves the value**, so the observation still excludes it and `value` must be counted. CMTAT does this. **ERC-3643 / T-REX calls afterwards** — `Token.transfer` runs `_transfer` then `_tokenCompliance.transferred`, and `mint` runs `_mint` then `created` — so the observation already includes the value and counting it again **halves the effective cap**, rejecting movements that are within it (Nethermind AuditAgent NM-11).

Adapting is one override, because "the observation already includes it" is the same as "there is nothing left to add":

```solidity
function _detectTransferRestrictionOnNotify(address from, address to, uint256)
    internal view override returns (uint8)
{
    return _detectTransferRestriction(from, to, 0);
}
```

**Only the write path is routed through this hook, never the read path.** A pre-flight view (`detectTransferRestriction`, `canTransfer`, `remainingCapacity`) always runs *before* the movement on either kind of token, so it must always project `value`. Re-phasing it too would make the pre-flight answer disagree with enforcement — the mirror image of the bug being fixed.

### Seam 2 — observation source: `_currentSupply` / `_balanceOf`

Both are `internal view virtual`, so a rule may serve the figure from **its own storage** instead of calling the token — the shape needed for a rule that tracks the supply itself from an opening figure set at the start of the token's life.

A rule that keeps its own running total also controls *when* it updates it, so it checks before it records and **seam 1 stops applying to it**: it never depends on the host token's call order.

Two constraints before building one:

- **It must observe every change or it drifts, permanently and silently.** Being installed after issuance has begun, removed and re-added, or served by a second engine all desynchronise it. A rule that reads the token self-heals; an accumulator does not.
- **Supply can be tracked; per-address balances are version-dependent and therefore unsafe.** How `Token.recoveryAddress` moves a balance **changed across T-REX versions**: up to 4.1 it routed through the public `forcedTransfer`, which *does* call `_tokenCompliance.transferred`; the vendored **4.2.0-beta1 calls `_transfer` directly and notifies nobody** (verified: zero `_tokenCompliance` references in that function body). A tracked per-address ledger is therefore in sync on one minor version and permanently skewed on the next, by an agent-callable path with no on-chain signal — a dependency no rule should carry. Total supply is unaffected by recovery either way, so a tracked-supply rule is safe from this.
- A tracked rule's write hook mutates state, so it belongs under `src/rules/operation/`, not `src/rules/validation/`.

### Worked examples

`src/mocks/harness/ERC3643CapHarnesses.sol` implements all four (one per cap rule for seam 1, plus a tracked-supply rule for seam 2), and `test/CapAccounting/ERC3643CapSeams.t.sol` asserts that the stock rules double-count under post-update accounting while the variants do not, and that neither ever admits anything above the cap.

---

## 6. ERC-3643 compatibility — which rules actually work on a T-REX token

A rule's guarantees depend on **what the token tells it and when**. CMTAT and ERC-3643 / T-REX differ on both,
so a rule that is correct on one can be inert or wrong on the other — silently, with nothing reverting at
deployment. This section is the per-rule answer.

### The two differences that cause everything below

| | CMTAT | ERC-3643 / T-REX |
|---|---|---|
| **Spender** | forwarded on the 4-arg `transferred(spender, from, to, value)` (v3.3+) | **never forwarded** — `transfer` *and* `transferFrom` both call the 3-arg `transferred(from, to, value)` |
| **Ordering** | rule called **before** the value moves | rule called **after** — `_transfer` then `transferred`; `_mint` then `created` |
| **Mint signal** | 4-arg `transferred(minter, address(0), to, value)` | `created(to, value)`, which `RuleEngine` forwards as 3-arg `transferred(address(0), to, value)` |

Both paths also call `canTransfer` **before** the movement, so the read views are unaffected by the ordering
difference and must always project the pending amount.

### Per-rule status

| Rule | On ERC-3643 | Why |
|---|---|---|
| `RuleWhitelist` | ✅ works, one flag inert | `from`/`to` arrive on the 3-arg path. **`checkSpender` never fires** |
| `RuleWhitelistWrapper` | ✅ works, one flag inert | as above |
| `RuleReceiverWhitelist` | ✅ works | screens `to` only, which the 3-arg path carries |
| `RuleBlacklist` | ✅ works, spender leg inert | blocks a listed `from`/`to`; a listed **spender** moving someone else's tokens is not caught |
| `RuleSanctionsList` | ✅ works, spender leg inert | as above |
| `RuleERC2980` | ✅ works, spender leg inert | whitelist and frozen checks on `from`/`to` fire; the frozen-**spender** leg does not |
| `RuleIdentityRegistry` | ✅ works, one flag inert | `to` is screened. **`checkSpender` never fires**. Usually redundant anyway: the token already calls `isVerified(_to)` itself |
| `RuleMaxTotalSupply` | ⚠️ **use `RuleMaxTotalSupplyERC3643`** | post-update ordering ⇒ the amount is counted twice and fully-backed mints revert |
| `RuleChainlinkPoR` | ⚠️ **use `RuleChainlinkPoRERC3643`** | same |
| `RuleMaxBalance` | ❌ **not supported** | same double-count, and no variant exists — see below |
| `RuleConditionalTransferLight` | ✅ works | approvals are keyed `(from, to, value)`; ordering is irrelevant to consuming one. Requires `bindRuleEngine` |
| `RuleConditionalTransferLightMultiToken` | ❌ **not supported** | direct-binding only, and ERC-3643 needs the engine for `created` / `destroyed` |
| `RuleMintAllowance` | ❌ **inert** | the quota is debited only on the 4-arg path; `created` arrives with no minter identity, so nothing is debited and every mint passes |

### Reading the three failure modes

They are not equally dangerous, and the difference matters more than the symbol:

- **"one flag / leg inert"** — the rule enforces less than its configuration suggests. Fail-**open** for that
  leg: an operator who set `checkSpender = true` gets no spender screening and no signal. The `from`/`to`
  screening is unaffected, so the rule still does its main job.
- **"use the ERC-3643 variant"** — the stock rule fails **closed**: it rejects mints that are within the cap.
  Nothing is over-issued, but issuance breaks in a way that looks intermittent, because only the amount *in
  flight* is double-counted. The variants re-phase the write path only.
- **"inert" / "not supported"** — the rule enforces **nothing**, or cannot be wired at all. `RuleMintAllowance`
  is the one to watch: it is silently permissive rather than restrictive, and its pre-flight view says
  `TRANSFER_OK` too, so neither the token nor an integrator sees a problem.

### Why `RuleMaxBalance` has no ERC-3643 variant

Not effort — a policy decision that has not been made. Its observation is **per-address**, so unlike the two
supply rules it engages on every transfer, and two T-REX agent powers interact badly with a post-update variant:

- **`forcedTransfer` does notify compliance**, so the variant would *revert* an agent's forced transfer that
  pushes the recipient over the cap. On T-REX ≤ 4.1, where `recoveryAddress` routes through `forcedTransfer`,
  that **bricks wallet recovery** whenever the destination already holds tokens.
- On the vendored **4.2.0-beta1 `recoveryAddress` notifies nobody**, so a recovered wallet can silently sit
  above the cap. A token-reading rule self-heals — further receipts are blocked — but the invariant is violated
  in state with no event.

Whether an agent action should be cap-exempt is the question to settle first. T-REX's own module library also
ships a `MaxBalanceModule`, so the marginal value is the lowest of the three.

### Wiring, whichever rules you choose

Use a **`RuleEngine`**, never a bare rule. ERC-3643 drives mint and burn through `created` / `destroyed`, which
the validation rules do not implement; the engine implements the full `ICompliance` surface and forwards them.
And build a `RuleChainlinkPoRERC3643` **after** `Token.init` — an uninitialised token reports `decimals() == 0`,
which the rule's constructor accepts and caches.

---

---

See [`CLAUDE_AUDIT.md`](../../security/audits/tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md) for the findings referenced above.
