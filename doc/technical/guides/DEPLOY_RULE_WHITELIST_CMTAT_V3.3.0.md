# Deploy `RuleWhitelist` with a CMTAT v3.3.0 token

[TOC]

This guide deploys a CMTAT **v3.3.0** token whose transfers and mints are restricted to whitelisted addresses by
`RuleWhitelist`. It covers the two places the rule can sit (on the token directly, or inside a RuleEngine), the two
moments it can be installed (in the token constructor, or later with `setRuleEngine`), and what happens on a mint and
on a transfer once it is active.

v3.3.0 is not final yet: this library is validated against **`v3.3.0-rc4`**, the version pinned in `lib/CMTAT`, and
every statement below was checked against that code. For the last audited release, see the
[v3.0.0 guide](./DEPLOY_RULE_WHITELIST_CMTAT_V3.0.0.md); [§8](#8-differences-from-cmtat-v300) lists what differs.

Tested against a real v3.3.0-rc4 token in `test/RuleWhitelist/CMTATIntegration.t.sol` (rule set directly after
deployment), `test/RuleWhitelist/CMTATRuleEngineIntegration.t.sol` (behind a RuleEngine) and
`test/RuleWhitelist/RuleWhitelistCMTATConstructor.t.sol` (rule or RuleEngine passed in the constructor).

## 1. What the rule enforces

| Operation | Checked by `RuleWhitelist` | Rejected with |
| --- | --- | --- |
| Transfer `from → to` | `from` and `to` are whitelisted | 21 (sender), 22 (receiver) |
| `transferFrom` by a spender | as above, plus the spender if `checkSpender` is `true` | 23 (spender) |
| Mint to `to` | `allowMint` is `true` and `to` is whitelisted | 24 (mint not allowed), 22 |
| Burn from `from` | `allowBurn` is `true` and `from` is whitelisted | 25 (burn not allowed), 21 |

The zero address is never a whitelist member: mint and burn are permitted by the `allowMint` / `allowBurn` flags, not
by listing `address(0)`.

On v3.3.0 the token forwards the **minter** (and the burner) to the rule as `spender`, on the 4-argument
`transferred(spender, from, to, value)`. `RuleWhitelist` deliberately does **not** screen it, even with
`checkSpender = true`: the minter acts on its own authority, not as a delegated ERC-20 spender. Who may mint is
decided by the token's `MINTER_ROLE`, not by the whitelist. To also screen minters, add `RuleBlacklist` or
`RuleSanctionsList` (deny-lists that do screen the minter) through a RuleEngine.

## 2. Choose the setup

**Where the rule sits.**

| Topology | Token calls | Use it when |
| --- | --- | --- |
| **Direct** | the rule itself (`token.ruleEngine() == rule`) | the whitelist is the only rule. Simplest, cheapest |
| **RuleEngine** | a `RuleEngine`, which calls each of its rules | you need several rules (for example whitelist + max total supply), or want to add rules later without touching the token |

`RuleWhitelist` is stateless, so it behaves identically in both. It needs no binding to the token.

**When the rule is installed.**

| Moment | How | Effect |
| --- | --- | --- |
| **At deployment** | pass the rule (or the RuleEngine) in the token constructor's `Engine.ruleEngine` field | the token is never unrestricted, the very first mint is screened |
| **After deployment** | deploy the token with `Engine.ruleEngine = address(0)`, then `token.setRuleEngine(...)` | between the two transactions the token has **no compliance**: any mint or transfer goes through. Do not mint or grant `MINTER_ROLE` before `setRuleEngine` |

Installing at deployment is recommended. Installing afterwards is the right choice for a token already live, or to
change or replace the compliance later.

## 3. Contracts and roles

| Contract | Constructor | Roles that matter here |
| --- | --- | --- |
| `RuleWhitelist` (or `RuleWhitelistOwnable2Step`) | `(admin, forwarderIrrevocable, checkSpender, allowMintBurn)` | `DEFAULT_ADMIN_ROLE` (all roles, flags), `ADDRESS_LIST_ADD_ROLE`, `ADDRESS_LIST_REMOVE_ROLE` |
| `RuleEngine` (RuleEngine `v3.0.0-rc7`, optional) | `(admin, tokenContract)`; `tokenContract` may be `address(0)` | `RULES_MANAGEMENT_ROLE` (`addRule`), `COMPLIANCE_MANAGER_ROLE` (`bindToken`) |
| CMTAT v3.3.0 `CMTATStandardStandalone` (or `CMTATStandaloneDebt`, or a proxy variant) | `(forwarder, admin, ERC20Attributes, ExtraInformationAttributes, Engine{ruleEngine})`. `CMTATStandaloneDebt` takes no forwarder | `DEFAULT_ADMIN_ROLE` (`setRuleEngine`, `forcedTransfer`, all roles), `MINTER_ROLE`, `BURNER_ROLE`, `PAUSER_ROLE`, `ENFORCER_ROLE` (freeze an address), `ERC20ENFORCER_ROLE` (freeze part of a balance) |

On both CMTAT and the AccessControl rules, the default admin implicitly holds every role. The v3.3.0 `Engine` struct
has a single field, `ruleEngine`; the snapshot and document engines of v3.0.0 are no longer constructor arguments.

Constructor flags of the rule:

- `allowMintBurn = true` to be able to issue. With `false`, every mint is rejected with code 24, even to a
  whitelisted investor. Both flags can be changed later with `setAllowMint` / `setAllowBurn` (for example to close
  issuance for good while keeping redemptions open).
- `checkSpender = true` to also require the spender of a `transferFrom` to be whitelisted. It never applies to the
  minter or burner. It can be toggled later with `setCheckSpender`.
- `forwarderIrrevocable = address(0)` unless you use ERC-2771 meta-transactions for the rule's admin calls.

## 4. Deployment steps

Each setup lists its steps, then draws them as a sequence diagram. The calls are shown from a single admin; in
production the whitelist, rule and minting roles can be held by different addresses (§3).

### 4.1 Rule set directly, at deployment (recommended for a whitelist alone)

1. **Deploy the rule:** `RuleWhitelist(admin, address(0), checkSpender, true)`. It needs no token address.
2. **Fill the whitelist:** `addAddresses([investor1, investor2, ...])`, as the admin or an `ADDRESS_LIST_ADD_ROLE`
   holder. This can also happen after step 3; until then every mint and transfer is rejected.
3. **Deploy the token** with `Engine(ruleEngine = rule)`.
4. **Grant `MINTER_ROLE`** to the issuer's minting address, if it is not the admin. It does not need to be
   whitelisted.
5. **Check the setup:** `token.ruleEngine() == rule`; on the Standard variant,
   `token.detectTransferRestriction(address(0), investor1, 1) == 0` and the same call to an unlisted address returns
   22. A small test mint confirms it end to end.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin (deployer)
    participant Rule as RuleWhitelist
    participant Token as CMTAT v3.3.0

    Admin->>Rule: deploy RuleWhitelist(admin, 0, checkSpender, true)
    Admin->>Rule: addAddresses([investor1, investor2, ...])
    Admin->>Token: deploy CMTATStandardStandalone(..., Engine(rule))
    Note over Token,Rule: compliance active from the first block: token.ruleEngine() == rule
    Admin->>Token: grantRole(MINTER_ROLE, minter)
    Admin->>Token: detectTransferRestriction(0, investor1, 1) returns 0
```

### 4.2 Rule set directly, after deployment

1. **Deploy the token** with `Engine(ruleEngine = address(0))`. Do not mint yet.
2. **Deploy the rule** and fill the whitelist, as in 4.1 steps 1 and 2.
3. **Install it:** `token.setRuleEngine(rule)`, as the token's `DEFAULT_ADMIN_ROLE`. It emits `RuleEngine(rule)`
   and reverts with `CMTAT_ValidationModule_SameValue` if that rule is already set.
4. **Grant `MINTER_ROLE`**, then check as in 4.1 step 5.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin (deployer)
    participant Token as CMTAT v3.3.0
    participant Rule as RuleWhitelist

    Admin->>Token: deploy CMTATStandardStandalone(..., Engine(0))
    Note over Token: no compliance yet: do not mint
    Admin->>Rule: deploy RuleWhitelist(admin, 0, checkSpender, true)
    Admin->>Rule: addAddresses([investor1, investor2, ...])
    Admin->>Token: setRuleEngine(rule)
    Token-->>Admin: event RuleEngine(rule)
    Admin->>Token: grantRole(MINTER_ROLE, minter)
    Admin->>Token: detectTransferRestriction(0, investor1, 1) returns 0
```

The repository script `script/DeployCMTATWithWhitelist.s.sol` deploys this setup on v3.3.0. See
[`DEPLOYMENT_SCRIPTS.md`](./DEPLOYMENT_SCRIPTS.md).

### 4.3 Behind a RuleEngine, at deployment

The token address does not exist yet when the engine is deployed, so the engine is deployed without a token and
binds it afterwards. Until that binding, the engine rejects every call from the token
(`TokenBinding_UnauthorizedCaller`): no mint or transfer can happen unscreened.

1. **Deploy the RuleEngine:** `RuleEngine(admin, address(0))`.
2. **Deploy the rule**, fill the whitelist, and add it: `engine.addRule(rule)` (`RULES_MANAGEMENT_ROLE`).
3. **Deploy the token** with `Engine(ruleEngine = engine)`.
4. **Bind the token:** `engine.bindToken(token)` (`COMPLIANCE_MANAGER_ROLE`). From now on the token works.
5. **Grant `MINTER_ROLE`** and check as in 4.1 step 5.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin (deployer)
    participant Engine as RuleEngine
    participant Rule as RuleWhitelist
    participant Token as CMTAT v3.3.0

    Admin->>Engine: deploy RuleEngine(admin, 0)
    Admin->>Rule: deploy RuleWhitelist(admin, 0, checkSpender, true)
    Admin->>Rule: addAddresses([investor1, investor2, ...])
    Admin->>Engine: addRule(rule)
    Admin->>Token: deploy CMTATStandardStandalone(..., Engine(engine))
    Note over Token,Engine: token not bound yet: every mint and transfer reverts (TokenBinding_UnauthorizedCaller)
    Admin->>Engine: bindToken(token)
    Admin->>Token: grantRole(MINTER_ROLE, minter)
    Admin->>Token: detectTransferRestriction(0, investor1, 1) returns 0
```

### 4.4 Behind a RuleEngine, after deployment

1. **Deploy the token** with `Engine(ruleEngine = address(0))`. Do not mint yet.
2. **Deploy the RuleEngine** with the token already known: `RuleEngine(admin, token)` binds it in the constructor.
3. **Deploy the rule**, fill the whitelist, `engine.addRule(rule)`.
4. **Install it:** `token.setRuleEngine(engine)`.
5. **Grant `MINTER_ROLE`** and check as in 4.1 step 5.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin (deployer)
    participant Token as CMTAT v3.3.0
    participant Engine as RuleEngine
    participant Rule as RuleWhitelist

    Admin->>Token: deploy CMTATStandardStandalone(..., Engine(0))
    Note over Token: no compliance yet: do not mint
    Admin->>Engine: deploy RuleEngine(admin, token): binds the token
    Admin->>Rule: deploy RuleWhitelist(admin, 0, checkSpender, true)
    Admin->>Rule: addAddresses([investor1, investor2, ...])
    Admin->>Engine: addRule(rule)
    Admin->>Token: setRuleEngine(engine)
    Admin->>Token: grantRole(MINTER_ROLE, minter)
    Admin->>Token: detectTransferRestriction(0, investor1, 1) returns 0
```

A RuleEngine serving one token is the expected shape. `RuleWhitelist` itself would work for several tokens (it reads
no token state), but every token would then share one whitelist.

## 5. Mint workflow

`mint(to, value)` by a `MINTER_ROLE` holder, with the rule active. The token runs its own checks first (contract
deactivated, receiver frozen), then notifies the compliance contract **before** creating the tokens, on the
4-argument `transferred(minter, address(0), to, value)`. Pause does not stop a mint. On the Standard variant the call
to the compliance contract runs under a transient reentrancy guard.

### 5.1 Rule plugged directly into the token

The token calls `RuleWhitelist` itself: `token.ruleEngine() == rule`.

```mermaid
sequenceDiagram
    autonumber
    actor Minter as Minter (MINTER_ROLE)
    participant Token as CMTAT v3.3.0
    participant Rule as RuleWhitelist

    Minter->>Token: mint(to, value)
    Token->>Token: onlyRole(MINTER_ROLE)
    Token->>Token: deactivated? receiver frozen?
    alt token check fails
        Token-->>Minter: revert EnforcedDeactivation / ERC7943CannotReceive
    end
    Token->>Rule: transferred(minter, address(0), to, value)
    Rule->>Rule: minter not screened (mint is exempt from the spender check)
    Rule->>Rule: allowMint? (else code 24)
    Rule->>Rule: receiver whitelisted? (else code 22)
    alt rejected
        Rule-->>Token: revert RuleWhitelist_InvalidTransferFrom(rule, minter, 0, to, value, code)
        Token-->>Minter: whole mint reverts
    else accepted
        Rule-->>Token: return
        Token->>Token: _mint(to, value): balance and totalSupply increase
        Token-->>Minter: Transfer(address(0), to, value)
    end
```

### 5.2 Rule behind a RuleEngine

The token calls the RuleEngine, which accepts only its bound token and then calls each of its rules in order.
The first rule that reverts stops the mint, and the revert reaches the token through the engine.

```mermaid
sequenceDiagram
    autonumber
    actor Minter as Minter (MINTER_ROLE)
    participant Token as CMTAT v3.3.0
    participant Engine as RuleEngine
    participant Rule as RuleWhitelist

    Minter->>Token: mint(to, value)
    Token->>Token: onlyRole(MINTER_ROLE)
    Token->>Token: deactivated? receiver frozen?
    alt token check fails
        Token-->>Minter: revert EnforcedDeactivation / ERC7943CannotReceive
    end
    Token->>Engine: transferred(minter, address(0), to, value)
    Engine->>Engine: onlyBoundToken (caller is the bound token?)
    Engine->>Rule: transferred(minter, address(0), to, value)
    Rule->>Rule: minter not screened (mint is exempt from the spender check)
    Rule->>Rule: allowMint? (else code 24)
    Rule->>Rule: receiver whitelisted? (else code 22)
    alt rejected
        Rule-->>Engine: revert RuleWhitelist_InvalidTransferFrom(rule, minter, 0, to, value, code)
        Engine-->>Token: revert bubbles up
        Token-->>Minter: whole mint reverts
    else accepted
        Rule-->>Engine: return
        Engine-->>Token: return
        Token->>Token: _mint(to, value): balance and totalSupply increase
        Token-->>Minter: Transfer(address(0), to, value)
    end
```

## 6. Transfer workflow

`transfer(to, value)` by a holder. The token first checks that the tokens are not frozen (active balance), then that
the token is not paused and nobody involved is frozen, then notifies the compliance contract **before** moving the
balance. A `transfer` has no spender and takes the 3-argument path; `transferFrom` takes the 4-argument path with the
caller as spender, where the rule also checks the spender if `checkSpender` is on.

### 6.1 Rule plugged directly into the token

The token calls `RuleWhitelist` itself: `token.ruleEngine() == rule`.

```mermaid
sequenceDiagram
    autonumber
    actor Holder as Holder (from)
    participant Token as CMTAT v3.3.0
    participant Rule as RuleWhitelist

    Holder->>Token: transfer(to, value)
    Token->>Token: active balance >= value? (frozen tokens excluded)
    Token->>Token: paused? sender or receiver frozen?
    alt token check fails
        Token-->>Holder: revert ERC7943InsufficientUnfrozenBalance / EnforcedPause / ERC7943CannotSend / ERC7943CannotReceive
    end
    Token->>Rule: transferred(from, to, value)
    Rule->>Rule: sender whitelisted? (else code 21)
    Rule->>Rule: receiver whitelisted? (else code 22)
    alt rejected
        Rule-->>Token: revert RuleWhitelist_InvalidTransfer(rule, from, to, value, code)
        Token-->>Holder: whole transfer reverts
    else accepted
        Rule-->>Token: return
        Token->>Token: _transfer(from, to, value)
        Token-->>Holder: Transfer(from, to, value)
    end
```

### 6.2 Rule behind a RuleEngine

Same path through the engine as for a mint (§5.2), on the 3-argument `transferred`.

```mermaid
sequenceDiagram
    autonumber
    actor Holder as Holder (from)
    participant Token as CMTAT v3.3.0
    participant Engine as RuleEngine
    participant Rule as RuleWhitelist

    Holder->>Token: transfer(to, value)
    Token->>Token: active balance >= value? (frozen tokens excluded)
    Token->>Token: paused? sender or receiver frozen?
    alt token check fails
        Token-->>Holder: revert ERC7943InsufficientUnfrozenBalance / EnforcedPause / ERC7943CannotSend / ERC7943CannotReceive
    end
    Token->>Engine: transferred(from, to, value)
    Engine->>Engine: onlyBoundToken
    Engine->>Rule: transferred(from, to, value)
    Rule->>Rule: sender whitelisted? (else code 21)
    Rule->>Rule: receiver whitelisted? (else code 22)
    alt rejected
        Rule-->>Engine: revert RuleWhitelist_InvalidTransfer(rule, from, to, value, code)
        Engine-->>Token: revert bubbles up
        Token-->>Holder: whole transfer reverts
    else accepted
        Rule-->>Engine: return
        Engine-->>Token: return
        Token->>Token: _transfer(from, to, value)
        Token-->>Holder: Transfer(from, to, value)
    end
```

Before sending, a wallet or a front end can ask the same question without a transaction:
`token.canTransfer(from, to, value)` on both variants, and `token.detectTransferRestriction(from, to, value)` plus
`messageForTransferRestriction(code)` on the Standard variant (the Debt variant has no ERC-1404 layer).

## 7. Operating the token

| Task | Call | Role |
| --- | --- | --- |
| Onboard investors | `rule.addAddresses([...])` (skips duplicates) or `addAddress` (reverts on a duplicate) | `ADDRESS_LIST_ADD_ROLE` |
| Offboard | `rule.removeAddresses([...])` / `removeAddress` | `ADDRESS_LIST_REMOVE_ROLE` |
| Stop issuance, keep redemptions | `rule.setAllowMint(false)` | rule `DEFAULT_ADMIN_ROLE` |
| Screen delegated spenders | `rule.setCheckSpender(true)` | rule `DEFAULT_ADMIN_ROLE` |
| Replace the compliance | `token.setRuleEngine(newRuleOrEngine)` | token `DEFAULT_ADMIN_ROLE` |
| Remove the compliance | `token.setRuleEngine(address(0))`: the token becomes unrestricted | token `DEFAULT_ADMIN_ROLE` |

**Removing an investor traps their tokens:** a de-listed holder can neither send nor be burned from (code 21) until
re-listed. To move tokens out of a de-listed address use the token's `forcedTransfer(from, to, value)`
(`DEFAULT_ADMIN_ROLE`; `to = address(0)` burns), which does not call the compliance contract. If holders must always
be able to exit, use `RuleReceiverWhitelist`, which screens only the receiver.

## 8. Differences from CMTAT v3.0.0

| | v3.0.0 | v3.3.0 |
| --- | --- | --- |
| Constructor `Engine` struct | `{ruleEngine, snapshotEngine, documentEngine}` | `{ruleEngine}` |
| Standard standalone contract | `CMTATStandalone` | `CMTATStandardStandalone` |
| Mint and burn reach the rule | 3-argument `transferred`, no minter | 4-argument `transferred`, minter / burner as `spender` (not screened by `RuleWhitelist`) |
| Mint rejected by the rule | `RuleWhitelist_InvalidTransfer` | `RuleWhitelist_InvalidTransferFrom` |
| Token-side check fails (frozen, paused, deactivated) | `CMTAT_InvalidTransfer` | the specific error: `ERC7943CannotSend` / `ERC7943CannotReceive`, `EnforcedPause`, `EnforcedDeactivation` |
| Reentrancy guard around the compliance call | none | transient guard on the Standard variant |

For `RuleWhitelist` the behaviour is the same on both versions: the minter never mattered to it. Other rules differ
more (`RuleMintAllowance` needs v3.3.0; deny-lists screen the minter only on v3.3.0); see
[`RULE_SEMANTICS.md`](./RULE_SEMANTICS.md) §7.

See also: [`RuleWhitelist.md`](../contracts/RuleWhitelist.md) for the full rule reference.
