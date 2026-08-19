# Rule Chainlink PoR — ERC-3643 variant

> ⚠️ **For ERC-3643 tokens only.** Use plain [`RuleChainlinkPoR`](./RuleChainlinkPoR.md) with CMTAT.
> The two are not interchangeable, and choosing the wrong one **silently** mis-caps issuance in one
> direction or the other. Nothing reverts at deployment to tell you.

`RuleChainlinkPoRERC3643` and `RuleChainlinkPoRERC3643Ownable2Step` cap minting at the reserves
reported by a Chainlink Proof of Reserve feed, exactly like the stock rule. The reserve logic,
restriction codes (75–79), configuration, roles and events are **identical and inherited**. The only
difference is *when the token is assumed to report the mint*.

## Why a separate variant: compliance is called AFTER the transfer

A compliance rule that caps a supply has to know whether the figure it reads already includes the
amount being moved. The two token families answer differently.

| Token | Order on a mint | `totalSupply()` when the rule is notified | Use |
|---|---|---|---|
| **CMTAT** | rule first, then the mint | **excludes** the new tokens | [`RuleChainlinkPoR`](./RuleChainlinkPoR.md) |
| **ERC-3643 / T-REX** | mint first, then `created` | **includes** the new tokens | `RuleChainlinkPoRERC3643` |

ERC-3643's `Token.mint` is explicit about it — and note it consults compliance **twice**, on either
side of the state change:

```solidity
function mint(address _to, uint256 _amount) public override onlyAgent {
    // ...
    require(_tokenCompliance.canTransfer(address(0), _to, _amount), ComplianceNotFollowed());
    _mint(_to, _amount);                                  // <-- supply changes here
    _tokenCompliance.created(_to, _amount);               // <-- rule notified afterwards
}
```

**ERC-3643 signals a mint with `created`, not `transferred`.** `RuleEngine` implements the full
`ICompliance` surface and forwards `created(to, value)` to each rule as the three-argument
`transferred(address(0), to, value)`, which is the shape every rule in this library already gates on
(`from == address(0)`). No rule-side change is needed for that; what changes is the accounting.

### What each variant does with it

Only the **write** path is re-phased. The variant overrides one hook:

```solidity
function _detectTransferRestrictionOnNotify(address from, address to, uint256 /* value */)
    internal view override returns (uint8)
{
    return _detectTransferRestriction(from, to, 0);   // the supply already includes the mint
}
```

The **read** path is deliberately untouched: `detectTransferRestriction`, `canTransfer` and
`maxBackedSupply` still project the pending amount, because a pre-flight query always runs *before*
the movement — as the `require(... canTransfer ...)` line above shows, the ERC-3643 token depends on
it. Re-phasing the views too would make the pre-flight answer disagree with enforcement.

The two consultations therefore reduce to the same condition, which is the property that makes the
variant correct: `canTransfer` asks `supply + amount <= reserves` before the mint, and `created` asks
`supply' <= reserves` after it, where `supply' == supply + amount`.

### What goes wrong with the wrong variant

| Deployment | Effect |
|---|---|
| Stock rule on an **ERC-3643** token | The amount is counted twice. `canTransfer` accepts the mint, the token mints, then `created` rejects it and the whole transaction reverts — **fully backed mints fail**. The largest single mint from an empty supply is halved to `reserves / 2`. It is not a uniform halving: a series of small mints can still creep up to the full reserves, so the failure looks intermittent and depends on how issuance is chunked. |
| This variant on a **CMTAT** token | The pending amount is ignored on enforcement. The pre-flight view still blocks an over-reserve mint, but the write hook would no longer stop one that slipped past — **the backing guarantee is weakened**. |

## Deployment

Constructors match the stock rule exactly.

```solidity
new RuleChainlinkPoRERC3643(
    admin,                 // DEFAULT_ADMIN_ROLE
    tokenContract,         // the ERC-3643 token; must expose totalSupply()
    tokenDecimals,         // 0–18, checked against decimals() when the token exposes it
    reservesFeed,          // AggregatorV3Interface
    maxStalenessSeconds    // 0 disables the staleness check
);
```

Wire it as a rule inside a `RuleEngine` occupying the token's **compliance** slot:

```
ERC-3643 Token ── compliance ──▶ RuleEngine ──▶ RuleChainlinkPoRERC3643
```

Use `RuleEngine`, not a bare rule: ERC-3643 drives mint and burn through `created` / `destroyed`,
which the validation rules do not implement. `RuleEngine` implements the full `ICompliance` surface
and forwards them.

`RuleChainlinkPoRERC3643Ownable2Step` is the same contract under `Ownable2Step` instead of
`AccessControl`.

### ⚠️ Deployment order: build the rule AFTER `Token.init`

ERC-3643 deploys the token and initialises it in two steps, and **an uninitialised `Token` reports
`decimals() == 0`**. The rule's constructor probes `decimals()` and accepts a matching value, so a
rule constructed before `init` is configured for a 0-decimals token — and `init(..., 18, ...)` then
makes it an 18-decimals token while the rule still believes 0.

Nothing reverts and no event marks it. The reserve answer is simply scaled by `10 ** 18` too little
and every mint is refused; the same mistake with the decimals reversed would authorise **unbacked
minting** instead. The constructor probe cannot catch this — it genuinely succeeded at the time.

- **Construct the rule after `token.init(...)`**, or
- call `setTokenMetadata(token, decimals)` once the token is initialised to re-sync.

In a `TREXFactory.deployTREXSuite` flow the token address only exists after the factory call anyway,
so the natural order is: deploy the `RuleEngine`, deploy the suite with it as compliance, then deploy
the rule against the finished token and `engine.addRule(...)`.

Pinned by `testRuleBuiltBeforeInitCachesTheWrongDecimals`.

### On `CODE_TOTAL_SUPPLY_UNAVAILABLE` (78)

`Token.totalSupply()` is `external view { return _totalSupply; }` — no modifier, no external call —
so it cannot revert, and code 78 is unreachable against a **directly deployed** ERC-3643 token. The
guarded read is still not dead weight: the standard T-REX deployment puts the token behind a
`TokenProxy` resolving its implementation through an `ImplementationAuthority`, and a proxy repointed
at a broken implementation *can* make the call revert. The rule then returns 78 and blocks minting
instead of breaking the MUST-NOT-revert views. Pinned by
`testSupplyIsAlwaysReadableOnADirectlyDeployedToken`.

## Behaviour inherited unchanged

- **Mints only.** Transfers and burns always pass, including while the feed is stale, broken or
  reporting zero — a lapsed feed must never trap holders in their position.
- **Restriction codes** 75 (reserves exceeded), 76 (feed stale), 77 (answer unusable, including a
  future-dated round), 78 (total supply unavailable), 79 (feed unreadable).
- **Live feed decimals**, never cached; `maxBackedSupply()` previews the ceiling; the read path never
  reverts. See [`RuleChainlinkPoR`](./RuleChainlinkPoR.md) for the full treatment.
- **One token per instance.** The rule reads `totalSupply()` from its configured `tokenContract`,
  never from the token that triggered the check, and cannot learn that identity behind a RuleEngine.
  Do not add one instance to two engines.

## Tests

`test/ERC3643Real/ERC3643RealTokenChainlinkPoR.t.sol` drives the **genuine** vendored
`lib/ERC-3643/` token (4.2.0-beta1) — not a mock — through this rule: mints up to the reserves,
rejection past them, incremental issuance against a shared ceiling, a raised feed answer raising the
ceiling, transfers and burns staying open while reserves are zero, and a stale feed halting issuance
without trapping holders. Two tests pin the stock rule's failure on the same token so the reason this
variant exists stays executable.

Run it with the dedicated profile, which `forge test` alone does **not** include:

```bash
FOUNDRY_PROFILE=erc3643 forge test
```

## See also

- [`RuleChainlinkPoR`](./RuleChainlinkPoR.md) — the CMTAT rule and the full PoR reference
- [`RULE_SEMANTICS.md` §5](../guides/RULE_SEMANTICS.md) — the two seams the cap rules expose, and why
  a tracked-supply rule is a different design
