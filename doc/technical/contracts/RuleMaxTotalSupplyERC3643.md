# Rule Max Total Supply — ERC-3643 variant

> ⚠️ **For ERC-3643 tokens only.** Use plain [`RuleMaxTotalSupply`](./RuleMaxTotalSupply.md) with CMTAT.
> The two are not interchangeable, and choosing the wrong one **silently** mis-caps issuance in one
> direction or the other. Nothing reverts at deployment to tell you.

`RuleMaxTotalSupplyERC3643` and `RuleMaxTotalSupplyERC3643Ownable2Step` cap minting at a static
maximum supply, exactly like the stock rule. The cap logic, restriction codes (50, 51),
configuration, roles and events are **identical and inherited**. The only difference is *when the
token is assumed to report the mint*.

## Why a separate variant: compliance is called AFTER the transfer

A rule that caps a supply has to know whether the figure it reads already includes the amount being
minted. The two token families answer differently.

| Token | Order on a mint | `totalSupply()` when the rule is notified | Use |
|---|---|---|---|
| **CMTAT** | rule first, then the mint | **excludes** the new tokens | [`RuleMaxTotalSupply`](./RuleMaxTotalSupply.md) |
| **ERC-3643 / T-REX** | mint first, then `created` | **includes** the new tokens | `RuleMaxTotalSupplyERC3643` |

ERC-3643's `Token.mint` is explicit, and consults compliance **twice** — on either side of the state
change:

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
`transferred(address(0), to, value)`, which is the shape every rule already gates on
(`from == address(0)`). No rule-side change is needed for the signal; what changes is the accounting.

### What each variant does with it

Only the **write** path is re-phased. The variant overrides one hook:

```solidity
function _detectTransferRestrictionOnNotify(address from, address to, uint256 /* value */)
    internal view override returns (uint8)
{
    return _detectTransferRestriction(from, to, 0);   // the supply already includes the mint
}
```

The **read** path is deliberately untouched: `detectTransferRestriction` and `canTransfer` still
project the pending amount, because a pre-flight query always runs *before* the movement — as the
`require(... canTransfer ...)` line above shows, the ERC-3643 token depends on it. Re-phasing the
views too would make the pre-flight answer disagree with enforcement.

The two consultations therefore reduce to the same condition, which is what makes the variant
correct: `canTransfer` asks `supply + amount <= cap` before the mint, and `created` asks
`supply' <= cap` after it, where `supply' == supply + amount`.

### What goes wrong with the wrong variant

| Deployment | Effect |
|---|---|
| Stock rule on an **ERC-3643** token | The amount is counted twice. `canTransfer` accepts the mint, the token mints, then `created` rejects it and the whole transaction reverts — **mints within the ceiling fail**. The largest single mint from an empty supply is halved to `cap / 2`. It is not a uniform halving: a series of small mints can still creep to the full cap, so the failure looks intermittent and depends on how issuance is chunked. |
| This variant on a **CMTAT** token | The pending amount is ignored on enforcement. The pre-flight view still blocks an over-cap mint, but the write hook would no longer stop one that slipped past — **the ceiling is weakened**. |

## Deployment

Constructors match the stock rule exactly.

```solidity
new RuleMaxTotalSupplyERC3643(
    admin,           // DEFAULT_ADMIN_ROLE
    tokenContract,   // the ERC-3643 token; must expose totalSupply()
    maxTotalSupply   // the ceiling
);
```

Wire it as a rule inside a `RuleEngine` occupying the token's **compliance** slot:

```
ERC-3643 Token ── compliance ──▶ RuleEngine ──▶ RuleMaxTotalSupplyERC3643
```

Use `RuleEngine`, not a bare rule: ERC-3643 drives mint and burn through `created` / `destroyed`,
which the validation rules do not implement.

`RuleMaxTotalSupplyERC3643Ownable2Step` is the same contract under `Ownable2Step` instead of
`AccessControl`.

### Composing with Proof of Reserve

[`RuleChainlinkPoRERC3643`](./RuleChainlinkPoRERC3643.md) caps minting at the reported reserves with
**no margin parameter**, so pair the two when a static ceiling is wanted alongside the reserve-backed
one. Add both to the same engine; whichever limit binds first stops the mint. The engine returns the
**first non-zero code**, so rule order decides whether a rejection is reported as `50` or `75`. Both
orderings are exercised in the test suite below.

## Behaviour inherited unchanged

- **Mints only.** Transfers always pass; burns always pass and *free headroom*, because the cap is on
  supply rather than on cumulative issuance.
- **Restriction codes** 50 (max total supply exceeded) and 51 (total supply unavailable — the token
  reverted or lost its code; fail-closed, and the read path still never reverts).
- **Lowering the cap below the current supply** does not claw anything back; it simply blocks further
  mints until burns bring the supply back under.
- **One token per instance.** The rule reads `totalSupply()` from its configured `tokenContract`,
  never from the token that triggered the check, and cannot learn that identity behind a RuleEngine.
  Do not add one instance to two engines.

## Tests

- `test/RuleMaxTotalSupply/RuleMaxTotalSupplyERC3643.t.sol` — unit coverage in the default profile.
- `test/ERC3643Real/ERC3643RealTokenMaxTotalSupply.t.sol` — drives the **genuine** vendored
  `lib/ERC-3643/` token (4.2.0-beta1), not a mock: mints to the ceiling, rejection past it,
  incremental issuance, burns freeing headroom, a raised cap raising the ceiling, and both
  compositions with the Proof-of-Reserve variant. Two tests pin the stock rule's failure on the same
  token so the reason this variant exists stays executable.

The real-token suite needs the dedicated profile, which `forge test` alone does **not** include:

```bash
FOUNDRY_PROFILE=erc3643 forge test
```

## See also

- [`RuleMaxTotalSupply`](./RuleMaxTotalSupply.md) — the CMTAT rule and the full reference
- [`RuleChainlinkPoRERC3643`](./RuleChainlinkPoRERC3643.md) — the reserve-backed sibling
- [`RULE_SEMANTICS.md` §5](../guides/RULE_SEMANTICS.md) — the two seams the cap rules expose
