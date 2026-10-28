# Deploy `RuleSpenderWhitelist` with a CMTAT v3.3.0 token

<!-- toc -->

- [1. What the rule enforces](#1-what-the-rule-enforces)
- [2. Choose the setup](#2-choose-the-setup)
- [3. Contracts and roles](#3-contracts-and-roles)
- [4. Deployment steps](#4-deployment-steps)
  - [Rule constructor parameters](#rule-constructor-parameters)
  - [4.1 Rule set directly, at deployment](#41-rule-set-directly-at-deployment)
  - [4.2 Rule set directly, after deployment](#42-rule-set-directly-after-deployment)
  - [4.3 Behind a RuleEngine, at deployment (recommended)](#43-behind-a-ruleengine-at-deployment-recommended)
  - [4.4 Behind a RuleEngine, after deployment](#44-behind-a-ruleengine-after-deployment)
- [5. transferFrom workflow](#5-transferfrom-workflow)
  - [5.1 Rule plugged directly into the token](#51-rule-plugged-directly-into-the-token)
  - [5.2 Rule behind a RuleEngine](#52-rule-behind-a-ruleengine)
  - [5.3 Happy path: a listed settlement contract moves an investor's tokens](#53-happy-path-a-listed-settlement-contract-moves-an-investors-tokens)
- [6. Transfer, mint and burn: the rule returns at once](#6-transfer-mint-and-burn-the-rule-returns-at-once)
  - [6.1 Transfer](#61-transfer)
  - [6.2 Mint and burn](#62-mint-and-burn)
- [7. Operating the token](#7-operating-the-token)
- [8. Differences from CMTAT v3.0.0](#8-differences-from-cmtat-v300)

<!-- /toc -->

This guide deploys a CMTAT **v3.3.0** token where `transferFrom` can only be called by whitelisted spenders, enforced by `RuleSpenderWhitelist`. Direct transfers, mints and burns are not screened by the rule. It covers:

- where the rule sits: on the token directly, or inside a RuleEngine next to a rule that screens holders;
- when it is installed: in the token constructor, or later with `setRuleEngine`;
- what happens on a `transferFrom`, and why a transfer, a mint or a burn passes.

v3.3.0 is not final yet: this library is validated against **`v3.3.0-rc4`**, the version pinned in `lib/CMTAT`, and every statement below was checked against that code. For the last audited release, see the [v3.0.0 guide](./DEPLOY_RULE_SPENDER_WHITELIST_CMTAT_V3.0.0.md); [§8](#8-differences-from-cmtat-v300) lists what differs.

The tests behind this guide, on a real v3.3.0-rc4 token:

- `test/RuleSpenderWhitelist/RuleSpenderWhitelistCMTATDeployment.t.sol`: rule passed in the token constructor (4.1), rule set directly with `setRuleEngine` after deployment (4.2), and RuleEngine passed in the token constructor (4.3), with a mint and a burn by an unlisted minter, a direct transfer, and `transferFrom` by a listed and an unlisted spender;
- setup 4.4 (RuleEngine set after deployment) is not run on a v3.3 token; the rule's own logic is covered without a token by `test/RuleSpenderWhitelist/RuleSpenderWhitelist.t.sol`.

## 1. What the rule enforces

| Operation | Checked by `RuleSpenderWhitelist` | Rejected with |
| --- | --- | --- |
| Transfer `from → to` | nothing | never |
| `transferFrom` by a spender | the spender (the caller) is whitelisted. `from` and `to` are not checked | 66 (spender) |
| Mint | nothing: the minter is not a delegated spender | never |
| Burn | nothing: the burner is not a delegated spender | never |

On v3.3.0 the token forwards the **minter** (and the burner) to the rule as `spender`, on the 4-argument `transferred(spender, from, to, value)`. The rule exempts every call where `from` or `to` is `address(0)`, so a mint or a burn passes whoever makes it. Who may mint or burn is decided by the token's `MINTER_ROLE` and `BURNER_ROLE`.

**The rule restricts nobody's holdings.** Any holder can send to any address with `transfer`, and any address can receive. On its own it only controls who may move tokens on a holder's behalf, for example a settlement or escrow contract. To screen holders, combine it with a rule such as `RuleWhitelist`, `RuleReceiverWhitelist` or `RuleIdentityRegistry` in a RuleEngine.

A holder who calls `transferFrom` on their own tokens arrives as the spender and is screened like any other caller. Use `transfer` for one's own tokens.

## 2. Choose the setup

**Where the rule sits.**

| Topology | Token calls | Use it when |
| --- | --- | --- |
| **Direct** | the rule itself (`token.ruleEngine() == rule`) | delegated transfers are the only thing to control and holders are not screened at all |
| **RuleEngine** | a `RuleEngine`, which calls each of its rules | the usual case: the spender whitelist sits next to a rule that screens holders, or you want to add rules later without touching the token |

`RuleSpenderWhitelist` is stateless, so it behaves identically in both. It needs no binding to the token.

**When the rule is installed.**

| Moment | How | Effect |
| --- | --- | --- |
| **At deployment** | pass the rule (or the RuleEngine) in the token constructor's `Engine.ruleEngine` field | the token is never unrestricted, the first `transferFrom` is screened |
| **After deployment** | deploy the token with `Engine.ruleEngine = address(0)`, then `token.setRuleEngine(...)` | between the two transactions the token has **no compliance**: any mint or transfer goes through. Do not mint or grant `MINTER_ROLE` before `setRuleEngine` |

Recommended: setup 4.3, a RuleEngine at deployment holding this rule and a rule that screens holders. Installing afterwards is the right choice for a token already live, or to change or replace the compliance later.

## 3. Contracts and roles

| Contract | Constructor | Roles that matter here |
| --- | --- | --- |
| `RuleSpenderWhitelist` (or `RuleSpenderWhitelistOwnable2Step`) | `(admin, forwarderIrrevocable)`; the Ownable2Step variant takes `(owner, forwarderIrrevocable)` | `DEFAULT_ADMIN_ROLE` (all roles), `ADDRESS_LIST_ADD_ROLE`, `ADDRESS_LIST_REMOVE_ROLE`. The Ownable2Step variant gives all of it to the owner |
| `RuleEngine` (RuleEngine `v3.0.0-rc7`, optional) | `(admin, tokenContract)`; `tokenContract` may be `address(0)` | `RULES_MANAGEMENT_ROLE` (`addRule`), `COMPLIANCE_MANAGER_ROLE` (`bindToken`) |
| CMTAT v3.3.0 `CMTATStandardStandalone` (or `CMTATStandaloneDebt`, or a proxy variant) | `(forwarder, admin, ERC20Attributes, ExtraInformationAttributes, Engine{ruleEngine})`. `CMTATStandaloneDebt` takes no forwarder | `DEFAULT_ADMIN_ROLE` (`setRuleEngine`, `forcedTransfer`, all roles), `MINTER_ROLE`, `BURNER_ROLE`, `PAUSER_ROLE`, `ENFORCER_ROLE` (freeze an address), `ERC20ENFORCER_ROLE` (freeze part of a balance) |

On both CMTAT and the AccessControl rule, the default admin implicitly holds every role. The v3.3.0 `Engine` struct has a single field, `ruleEngine`; the snapshot and document engines of v3.0.0 are no longer constructor arguments.

The rule has no flags. `forwarderIrrevocable = address(0)` unless you use ERC-2771 meta-transactions for the rule's admin calls.

**Not a `RuleWhitelistWrapper` child.** The wrapper refuses this rule (`RuleWhitelistWrapper_ChildDoesNotDeclarePolarity`): its list holds permitted spenders, not permitted holders.

## 4. Deployment steps

Each setup lists its steps, then draws them as a sequence diagram. The calls are shown from a single admin; in production the list, rule and minting roles can be held by different addresses (§3).


### Rule constructor parameters

| Parameter | Type | What it sets | Checks and notes |
| --- | --- | --- | --- |
| `admin` | `address` | Receives `DEFAULT_ADMIN_ROLE`, which implicitly holds every role of the rule. Set it to the account (ideally a multisig) that will operate the rule. | Reverts if `address(0)`. On the `Ownable2Step` variant this parameter is `owner`, who then holds every privileged function |
| `forwarderIrrevocable` | `address` | ERC-2771 trusted forwarder for gasless (meta-transaction) calls to the rule's admin functions. | `address(0)` disables meta-transactions. Cannot be changed after deployment |

### 4.1 Rule set directly, at deployment

1. **Deploy the rule:** `RuleSpenderWhitelist(admin, address(0))`. It needs no token address.
2. **List the spenders:** `addAddresses([spender1, spender2, ...])`, as the admin or an `ADDRESS_LIST_ADD_ROLE` holder. This can also happen after step 3; until then every `transferFrom` is rejected.
3. **Deploy the token** with `Engine(ruleEngine = rule)`.
4. **Grant `MINTER_ROLE`** to the issuer's minting address, if it is not the admin. It does not need to be listed.
5. **Check the setup:** `token.ruleEngine() == rule`; on the Standard variant, `token.detectTransferRestrictionFrom(spender1, holder, to, 1) == 0` and the same call with an unlisted spender returns 66.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin (deployer)
    participant Rule as RuleSpenderWhitelist
    participant Token as CMTAT v3.3.0

    Admin->>Rule: deploy RuleSpenderWhitelist(admin, 0)
    Admin->>Rule: addAddresses([spender1, spender2, ...])
    Admin->>Token: deploy CMTATStandardStandalone(..., Engine(rule))
    Note over Token,Rule: compliance active from the first block: token.ruleEngine() == rule
    Admin->>Token: grantRole(MINTER_ROLE, minter)
    Admin->>Token: detectTransferRestrictionFrom(spender1, holder, to, 1) returns 0
```

The repository script `script/DeployCMTATWithSpenderWhitelist.s.sol` deploys this rule on a v3.3.0 token, set directly on it, in one run. See [`DEPLOYMENT_SCRIPTS.md`](./DEPLOYMENT_SCRIPTS.md).

### 4.2 Rule set directly, after deployment

1. **Deploy the token** with `Engine(ruleEngine = address(0))`. Do not mint yet.
2. **Deploy the rule** and list the spenders, as in 4.1 steps 1 and 2.
3. **Install it:** `token.setRuleEngine(rule)`, as the token's `DEFAULT_ADMIN_ROLE`. It emits `RuleEngine(rule)` and reverts with `CMTAT_ValidationModule_SameValue` if that rule is already set.
4. **Grant `MINTER_ROLE`**, then check as in 4.1 step 5.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin (deployer)
    participant Token as CMTAT v3.3.0
    participant Rule as RuleSpenderWhitelist

    Admin->>Token: deploy CMTATStandardStandalone(..., Engine(0))
    Note over Token: no compliance yet: do not mint
    Admin->>Rule: deploy RuleSpenderWhitelist(admin, 0)
    Admin->>Rule: addAddresses([spender1, spender2, ...])
    Admin->>Token: setRuleEngine(rule)
    Token-->>Admin: event RuleEngine(rule)
    Admin->>Token: grantRole(MINTER_ROLE, minter)
    Admin->>Token: detectTransferRestrictionFrom(spender1, holder, to, 1) returns 0
```

### 4.3 Behind a RuleEngine, at deployment (recommended)

The token address does not exist yet when the engine is deployed, so the engine is deployed without a token and binds it afterwards. Until that binding, the engine rejects every call from the token (`TokenBinding_UnauthorizedCaller`): no mint or transfer can happen unscreened.

1. **Deploy the RuleEngine:** `RuleEngine(admin, address(0))`.
2. **Deploy the holder rule** (here a `RuleWhitelist`), fill it, and add it: `engine.addRule(holderRule)` (`RULES_MANAGEMENT_ROLE`).
3. **Deploy the spender rule**, list the spenders, and add it: `engine.addRule(spenderRule)`.
4. **Deploy the token** with `Engine(ruleEngine = engine)`.
5. **Bind the token:** `engine.bindToken(token)` (`COMPLIANCE_MANAGER_ROLE`). From now on the token works.
6. **Grant `MINTER_ROLE`** and check as in 4.1 step 5.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin (deployer)
    participant Engine as RuleEngine
    participant Holders as RuleWhitelist (holders)
    participant Rule as RuleSpenderWhitelist
    participant Token as CMTAT v3.3.0

    Admin->>Engine: deploy RuleEngine(admin, 0)
    Admin->>Holders: deploy RuleWhitelist(admin, 0, false, true)
    Admin->>Holders: addAddresses([investor1, investor2, ...])
    Admin->>Engine: addRule(holderRule)
    Admin->>Rule: deploy RuleSpenderWhitelist(admin, 0)
    Admin->>Rule: addAddresses([spender1, spender2, ...])
    Admin->>Engine: addRule(spenderRule)
    Admin->>Token: deploy CMTATStandardStandalone(..., Engine(engine))
    Note over Token,Engine: token not bound yet: every mint and transfer reverts (TokenBinding_UnauthorizedCaller)
    Admin->>Engine: bindToken(token)
    Admin->>Token: grantRole(MINTER_ROLE, minter)
    Admin->>Token: detectTransferRestrictionFrom(spender1, investor1, investor2, 1) returns 0
```

The test for this setup puts the spender rule alone in the engine; the holder rule is an example of what to add next to it.

### 4.4 Behind a RuleEngine, after deployment

1. **Deploy the token** with `Engine(ruleEngine = address(0))`. Do not mint yet.
2. **Deploy the RuleEngine** with the token already known: `RuleEngine(admin, token)` binds it in the constructor.
3. **Deploy the rules**, fill their lists, and add them with `engine.addRule(...)`.
4. **Install it:** `token.setRuleEngine(engine)`.
5. **Grant `MINTER_ROLE`** and check as in 4.1 step 5.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Admin (deployer)
    participant Token as CMTAT v3.3.0
    participant Engine as RuleEngine
    participant Rule as RuleSpenderWhitelist

    Admin->>Token: deploy CMTATStandardStandalone(..., Engine(0))
    Note over Token: no compliance yet: do not mint
    Admin->>Engine: deploy RuleEngine(admin, token): binds the token
    Admin->>Rule: deploy RuleSpenderWhitelist(admin, 0)
    Admin->>Rule: addAddresses([spender1, spender2, ...])
    Admin->>Engine: addRule(spenderRule), plus the holder rule
    Admin->>Token: setRuleEngine(engine)
    Admin->>Token: grantRole(MINTER_ROLE, minter)
    Admin->>Token: detectTransferRestrictionFrom(spender1, holder, to, 1) returns 0
```

A RuleEngine serving one token is the intended setup. `RuleSpenderWhitelist` itself would work for several tokens (it reads no token state), but every token would then share one spender list.

## 5. `transferFrom` workflow

`transferFrom(from, to, value)` by a spender holding an allowance. The token first checks that `from` has enough unfrozen tokens, then that the token is not paused and that neither the spender, `from` nor `to` is frozen. It then notifies the compliance contract on the 4-argument `transferred(spender, from, to, value)`, and only after that spends the allowance and moves the balance. An unlisted spender is therefore rejected by the rule even if its allowance is also too low.

### 5.1 Rule plugged directly into the token

The token calls `RuleSpenderWhitelist` itself: `token.ruleEngine() == rule`.

```mermaid
sequenceDiagram
    autonumber
    actor Spender as Spender (caller)
    participant Token as CMTAT v3.3.0
    participant Rule as RuleSpenderWhitelist

    Spender->>Token: transferFrom(from, to, value)
    Token->>Token: active balance of from >= value?
    Token->>Token: paused? spender, from or to frozen?
    alt token check fails
        Token-->>Spender: revert ERC7943InsufficientUnfrozenBalance / EnforcedPause / ERC7943CannotSend / ERC7943CannotReceive
    end
    Token->>Rule: transferred(spender, from, to, value)
    Rule->>Rule: from and to not address(0), so not a mint or burn
    Rule->>Rule: spender whitelisted? (else code 66)
    alt rejected
        Rule-->>Token: revert RuleSpenderWhitelist_InvalidTransferFrom(rule, spender, from, to, value, 66)
        Token-->>Spender: whole transferFrom reverts
    else accepted
        Rule-->>Token: return
        Token->>Token: spend allowance, _transfer(from, to, value)
        Token-->>Spender: Transfer(from, to, value)
    end
```

### 5.2 Rule behind a RuleEngine

The token calls the RuleEngine, which accepts only its bound token and then calls each of its rules in order. The first rule that reverts stops the transfer, and the engine passes the revert back to the token.

```mermaid
sequenceDiagram
    autonumber
    actor Spender as Spender (caller)
    participant Token as CMTAT v3.3.0
    participant Engine as RuleEngine
    participant Rule as RuleSpenderWhitelist

    Spender->>Token: transferFrom(from, to, value)
    Token->>Token: active balance of from >= value?
    Token->>Token: paused? spender, from or to frozen?
    alt token check fails
        Token-->>Spender: revert ERC7943InsufficientUnfrozenBalance / EnforcedPause / ERC7943CannotSend / ERC7943CannotReceive
    end
    Token->>Engine: transferred(spender, from, to, value)
    Engine->>Engine: onlyBoundToken (caller is the bound token?)
    Engine->>Rule: transferred(spender, from, to, value)
    Rule->>Rule: spender whitelisted? (else code 66)
    alt rejected
        Rule-->>Engine: revert RuleSpenderWhitelist_InvalidTransferFrom(rule, spender, from, to, value, 66)
        Engine-->>Token: revert bubbles up
        Token-->>Spender: whole transferFrom reverts
    else accepted
        Rule-->>Engine: return
        Engine-->>Token: return
        Token->>Token: spend allowance, _transfer(from, to, value)
        Token-->>Spender: Transfer(from, to, value)
    end
```

### 5.3 Happy path: a listed settlement contract moves an investor's tokens

Alice approved 100 tokens to Escrow, a settlement contract on the spender list. Escrow calls `transferFrom(alice, bob, 100)`. Nobody is frozen and the token is not paused. The rule is plugged directly into the token; behind a RuleEngine the engine sits between the token and the rule, as in §5.2.

```mermaid
sequenceDiagram
    autonumber
    actor Escrow as Escrow (listed spender)
    participant Token as CMTAT v3.3.0
    participant Rule as RuleSpenderWhitelist

    Escrow->>Token: transferFrom(alice, bob, 100)
    Token->>Token: Alice active balance >= 100: yes
    Token->>Token: paused, Escrow, Alice or Bob frozen: no
    Token->>Rule: transferred(escrow, alice, bob, 100)
    Rule->>Rule: Escrow whitelisted: yes
    Rule-->>Token: return, no revert (restriction code 0)
    Token->>Token: allowance(alice, escrow) -= 100, _transfer(alice, bob, 100)
    Token-->>Escrow: Transfer(alice, bob, 100), returns true
```

## 6. Transfer, mint and burn: the rule returns at once

The diagrams show the rule plugged directly into the token; behind a RuleEngine the engine sits between them, as in §5.2, and the other rules of the engine still run.

### 6.1 Transfer

```mermaid
sequenceDiagram
    autonumber
    actor Holder as Holder (from)
    participant Token as CMTAT v3.3.0
    participant Rule as RuleSpenderWhitelist

    Holder->>Token: transfer(to, value)
    Token->>Token: active balance >= value? paused? sender or receiver frozen?
    alt token check fails
        Token-->>Holder: revert ERC7943InsufficientUnfrozenBalance / EnforcedPause / ERC7943CannotSend / ERC7943CannotReceive
    end
    Token->>Rule: transferred(from, to, value)
    Rule->>Rule: no spender: nothing to check
    Rule-->>Token: return
    Token->>Token: _transfer(from, to, value)
    Token-->>Holder: Transfer(from, to, value)
```

### 6.2 Mint and burn

```mermaid
sequenceDiagram
    autonumber
    actor Issuer as Issuer (MINTER_ROLE and BURNER_ROLE, not listed)
    participant Token as CMTAT v3.3.0
    participant Rule as RuleSpenderWhitelist

    Issuer->>Token: mint(to, value)
    Token->>Token: deactivated? receiver frozen?
    Token->>Rule: transferred(issuer, address(0), to, value)
    Rule->>Rule: from == address(0): mint, minter not screened
    Rule-->>Token: return
    Token->>Token: _mint(to, value)
    Issuer->>Token: burn(from, value)
    Token->>Token: deactivated? holder frozen? active balance >= value?
    Token->>Rule: transferred(issuer, from, address(0), value)
    Rule->>Rule: to == address(0): burn, burner not screened
    Rule-->>Token: return
    Token->>Token: _burn(from, value)
```

Before calling `transferFrom`, a spender or a front end can ask the same question without a transaction: `token.canTransferFrom(spender, from, to, value)` on both variants, and `token.detectTransferRestrictionFrom(spender, from, to, value)` plus `messageForTransferRestriction(code)` on the Standard variant (the Debt variant has no ERC-1404 layer). `canTransfer(from, to, value)` always passes this rule, since it has no spender.

## 7. Operating the token

| Task | Call | Role |
| --- | --- | --- |
| Authorise a spender (a settlement, escrow or custody contract) | `rule.addAddresses([...])` (skips duplicates, reverts on `address(0)`) or `addAddress` (reverts on a duplicate) | `ADDRESS_LIST_ADD_ROLE` |
| Withdraw a spender | `rule.removeAddresses([...])` / `removeAddress` | `ADDRESS_LIST_REMOVE_ROLE` |
| Replace the compliance | `token.setRuleEngine(newRuleOrEngine)` | token `DEFAULT_ADMIN_ROLE` |
| Remove the compliance | `token.setRuleEngine(address(0))`: the token becomes unrestricted | token `DEFAULT_ADMIN_ROLE` |

**Removing a spender does not revoke its allowances.** The allowances stay on the token; the next `transferFrom` from that spender is rejected with code 66 until it is listed again. A holder who wants the allowance gone calls `approve(spender, 0)`.

**Listing a spender lets it move any holder's tokens within the allowance that holder gave.** The rule does not check `from` or `to`, so pair it with a holder rule (§2) if the counterparties must be screened.

## 8. Differences from CMTAT v3.0.0

| | v3.0.0 | v3.3.0 |
| --- | --- | --- |
| Constructor `Engine` struct | `{ruleEngine, snapshotEngine, documentEngine}` | `{ruleEngine}` |
| Standard standalone contract | `CMTATStandalone` | `CMTATStandardStandalone` |
| How mint and burn call the rule | 3-argument `transferred`, a no-op for this rule | 4-argument `transferred`, minter or burner as `spender`, exempted by the rule |
| How `transferFrom` calls the rule | 4-argument, caller as spender | same |
| Token-side check fails (frozen, paused, deactivated) | `CMTAT_InvalidTransfer` | the specific error: `ERC7943CannotSend` / `ERC7943CannotReceive`, `EnforcedPause`, `EnforcedDeactivation` |
| Reentrancy guard around the compliance call | none | transient guard on the Standard variant |

What the rule allows is the same on both versions: the `transferFrom` spender is forwarded on both, and mint and burn pass on both. See [`RULE_SEMANTICS.md`](./RULE_SEMANTICS.md) §7 for the other rules.

See also: [`RuleSpenderWhitelist.md`](../contracts/RuleSpenderWhitelist.md) for the full rule reference.
