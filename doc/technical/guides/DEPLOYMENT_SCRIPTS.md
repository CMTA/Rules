# Deployment Scripts

<!-- toc -->

- [Inventory](#inventory)
- [The shape every script shares](#the-shape-every-script-shares)
  - [Why the deployer is a parameter](#why-the-deployer-is-a-parameter)
  - [Temporary admin and hand-over](#temporary-admin-and-hand-over)
  - [The two topologies](#the-two-topologies)
- [Configuration](#configuration)
  - [Running](#running)
- [The scripts](#the-scripts)
  - [DeployCMTATWithWhitelist](#deploycmtatwithwhitelist)
  - [DeployCMTATWithBlacklist](#deploycmtatwithblacklist)
  - [DeployCMTATWithMaxTotalSupply](#deploycmtatwithmaxtotalsupply)
  - [DeployCMTATWithReceiverWhitelist](#deploycmtatwithreceiverwhitelist)
  - [DeployCMTATWithSpenderWhitelist](#deploycmtatwithspenderwhitelist)
  - [DeployCMTATWithWhitelistWrapper](#deploycmtatwithwhitelistwrapper)
  - [DeployCMTATWithSanctionsList](#deploycmtatwithsanctionslist)
  - [DeployCMTATWithERC2980](#deploycmtatwitherc2980)
  - [DeployCMTATWithIdentityRegistry](#deploycmtatwithidentityregistry)
  - [DeployCMTATWithMaxBalance](#deploycmtatwithmaxbalance)
  - [DeployCMTATWithChainlinkPoR](#deploycmtatwithchainlinkpor)
  - [DeployCMTATWithConditionalTransferLight](#deploycmtatwithconditionaltransferlight)
  - [DeployCMTATWithConditionalTransferLightMultiToken](#deploycmtatwithconditionaltransferlightmultitoken)
  - [DeployCMTATWithMintAllowance](#deploycmtatwithmintallowance)
  - [DeployCMTATWithIssuanceCap](#deploycmtatwithissuancecap)
  - [DeployCMTATWithBlacklistAndSanctionsList](#deploycmtatwithblacklistandsanctionslist)
  - [DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply](#deploycmtatwithblacklistsanctionslistandmaxtotalsupply)
- [After deployment](#after-deployment)
- [Limitations](#limitations)
- [Testing](#testing)

<!-- /toc -->

This document covers the Foundry scripts in [`script/`](../../../script/): what each one deploys, the shape they all share, how to configure them, what you still have to do after running one, and the limitations worth knowing before you use them on a real chain.

Every script produces a working CMTAT token with compliance rules attached and all admin rights held by a single address you choose. None of them is a turnkey issuance: each leaves configuration that only the operator can supply, listed per script under [After deployment](#after-deployment).

## Inventory

| Script | Deploys | Topology | Tests |
| --- | --- | --- | --- |
| `DeployCMTATWithWhitelist.s.sol` | CMTAT + `RuleWhitelist` | B (direct) | 7 |
| `DeployCMTATWithBlacklist.s.sol` | CMTAT + `RuleBlacklist` | B (direct) | 6 |
| `DeployCMTATWithMaxTotalSupply.s.sol` | CMTAT + `RuleMaxTotalSupply` | B (direct) | 8 |
| `DeployCMTATWithReceiverWhitelist.s.sol` | CMTAT + `RuleReceiverWhitelist` | B (direct) | 8 |
| `DeployCMTATWithSpenderWhitelist.s.sol` | CMTAT + `RuleSpenderWhitelist` | B (direct) | 7 |
| `DeployCMTATWithWhitelistWrapper.s.sol` | CMTAT + `RuleWhitelistWrapper` + 2 child `RuleWhitelist` | B (direct) | 7 |
| `DeployCMTATWithSanctionsList.s.sol` | CMTAT + `RuleSanctionsList` | B (direct) | 9 |
| `DeployCMTATWithERC2980.s.sol` | CMTAT + `RuleERC2980` | B (direct) | 8 |
| `DeployCMTATWithIdentityRegistry.s.sol` | CMTAT + `IdentityRegistryWhitelist` + `RuleIdentityRegistry` | B (direct) | 7 |
| `DeployCMTATWithMaxBalance.s.sol` | CMTAT + `RuleMaxBalance` | B (direct) | 8 |
| `DeployCMTATWithChainlinkPoR.s.sol` | CMTAT + `RuleChainlinkPoR` | B (direct) | 8 |
| `DeployCMTATWithConditionalTransferLight.s.sol` | CMTAT + `RuleConditionalTransferLight` | B (direct) | 8 |
| `DeployCMTATWithConditionalTransferLightMultiToken.s.sol` | CMTAT + `RuleConditionalTransferLightMultiToken` | B (direct) | 7 |
| `DeployCMTATWithMintAllowance.s.sol` | CMTAT + `RuleMintAllowance` | B (direct) | 7 |
| `DeployCMTATWithIssuanceCap.s.sol` | CMTAT + `RuleIssuanceCap` | B (direct) | 7 |
| `DeployCMTATWithBlacklistAndSanctionsList.s.sol` | CMTAT + `RuleEngine` + 2 rules | A (engine) | 20 |
| `DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply.s.sol` | CMTAT + `RuleEngine` + 3 rules | A (engine) | 21 |

All seventeen share [`script/base/CMTATDeploymentBase.sol`](../../../script/base/CMTATDeploymentBase.sol), which holds the token metadata, the environment configuration, and the address-logging helper.

## The shape every script shares

Each script exposes two entry points:

| Function | Used by | Notes |
| --- | --- | --- |
| `deploy(...)` | tests, and other scripts | Plain function call. Takes `admin`, plus `deployer` in the scripts that need a temporary admin (see below). |
| `run()` | `forge script` | Wraps `deploy` in `vm.startBroadcast()`, passing `msg.sender` as `admin` (and as `deployer`). |

### Why the deployer is a parameter

Where a script needs a temporary admin, `deploy()` takes both an `admin` and a `deployer`, which looks redundant since `run()` passes the same address for both. It is not redundant, and reading the deployer from `address(this)` instead is a bug that these scripts used to have.

Under `forge script` the calls are made by the **broadcaster**, not by the script contract. Two independent things break if a script assumes otherwise:

1. Foundry rejects `address(this)` inside a broadcast outright, with *"script contracts are ephemeral and their addresses should not be relied upon"*. The script reverts during simulation.
2. Even without that guard, `renounceRole` would fail. It is not `revokeRole`: its second argument is a confirmation that the caller is that account (`AccessControl.sol:155`), so `token.renounceRole(role, deployer)` only succeeds when `msg.sender == deployer`.

Three of the four scripts read `address(this)` and could not deploy anything at all until this was fixed. The full write-up is [`CLAUDE_ANALYSIS_SCRIPT.md`](../../security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_SCRIPT.md) S-1.

### Temporary admin and hand-over

**The token is created with its final `admin` whenever possible.** CMTAT accepts its rule, or a RuleEngine, in its constructor, so a script that can deploy the rule first passes it there with `admin` as the token's admin: no `setRuleEngine` call, no temporary admin, and the token never exists without its compliance. The deployer only holds a role where a role-gated call must happen **after** the token exists:

| Script | Temporary admin held by the deployer | Why |
| --- | --- | --- |
| Whitelist, receiver whitelist, spender whitelist, blacklist, sanctions list, ERC-2980, identity registry | none | the rule is deployed first and passed to the token's constructor; `deploy()` takes no `deployer` |
| Whitelist wrapper | the wrapper | `wrapper.addRule(...)` for the two children |
| Conditional transfer, multi-token conditional transfer, mint allowance | the rule | `rule.bindToken(token)` needs the token's address, so it runs after the token exists |
| The two RuleEngine scripts | the RuleEngine | `addRule` and `bindToken(token)`. The engine is passed to the token's constructor and binds the token last, so the token itself gets `admin` directly |
| Max total supply, max balance, Chainlink PoR, issuance cap | the **token** (and the rule, for the issuance cap) | the rule needs the token's address, so it can only be installed with `setRuleEngine` once the token exists, which needs the token's admin |

Each script that keeps a temporary admin says why in a comment above its hand-over.

The hand-over is a grant followed by a renounce, in that order, because `AccessControl` has no atomic transfer and renouncing first would leave nobody able to grant:

```solidity
if (admin != deployer) {
    ruleEngine.grantRole(ruleEngine.DEFAULT_ADMIN_ROLE(), admin);
    ruleEngine.renounceRole(ruleEngine.DEFAULT_ADMIN_ROLE(), deployer);
}
```

**The `if` is load-bearing.** In `run()` both arguments are `msg.sender`, so `admin == deployer`. Without the guard the grant would be a no-op and the renounce would then strip the only administrator, leaving a contract nobody can ever configure. Removing the guard and running the `admin == deployer` case was measured: the contract ends with no admin at all.

Both CMTAT and `RuleEngine` grant exactly one role at construction, `DEFAULT_ADMIN_ROLE`, so renouncing it is complete. If someone later adds an explicit `grantRole(SOME_ROLE, deployer)` to the wiring, this block would not remove it and the current tests would not notice.

### The two topologies

The scripts deliberately use both integration models described in `CLAUDE.md`, and the choice changes what `msg.sender` is inside a rule:

- **Topology B, direct binding** (every single-rule script). The rule is installed straight on the token, in its constructor or with `setRuleEngine(rule)`, with no engine in between, so inside the rule `msg.sender` is the token. Fine for a single validation rule, and cheaper: one contract fewer and no engine hop per transfer.
- **Topology A, RuleEngine** (the two others). Required as soon as there is more than one rule.

This matters if you copy a script as a starting point. An operation rule such as `RuleConditionalTransferLightMultiToken` is direct-binding only, while `RuleMintAllowance` is not, so the two are not interchangeable. Each script states its topology in its NatSpec header.

## Configuration

Values come from the environment, with the previous hard-coded constants as defaults, so every script runs unconfigured. Defaults live in `CMTATDeploymentBase`.

| Variable | Default | Applies to |
| --- | --- | --- |
| `CMTAT_NAME` | `CMTA Token` | all |
| `CMTAT_SYMBOL` | `CMTAT` | all |
| `CMTAT_DECIMALS` | `0` | all |
| `CMTAT_TOKEN_ID` | `CMTAT_ISIN` | all |
| `CMTAT_TERMS_NAME` | `Terms` | all |
| `CMTAT_TERMS_URI` | `https://cmta.ch` | all |
| `CMTAT_TERMS_HASH` | example document hash | all |
| `CMTAT_INFORMATION` | `CMTAT_info` | all |
| `CMTAT_FORWARDER` | `address(0)` | all |
| `SANCTIONS_ORACLE` | `address(0)` | the three sanctions scripts |
| `CMTAT_MAX_SUPPLY` | `1000000` | the two scripts deploying `RuleMaxTotalSupply` |
| `CMTAT_MAX_BALANCE` | `100000` | `DeployCMTATWithMaxBalance` |
| `CMTAT_ISSUANCE_CAP` | `1000000` | `DeployCMTATWithIssuanceCap` |
| `CHAINLINK_POR_FEED` | `address(0)`: a mock feed on chain 31337, a revert elsewhere | `DeployCMTATWithChainlinkPoR` |
| `CHAINLINK_POR_MAX_STALENESS` | `86400` | `DeployCMTATWithChainlinkPoR` |

A script needing different metadata overrides `_erc20Attributes()` or `_extraInformationAttributes()` rather than copying the block again.

### Running

```bash
# local simulation, no key or RPC needed
forge script script/DeployCMTATWithBlacklist.s.sol:DeployCMTATWithBlacklist

# real deployment
forge script script/DeployCMTATWithBlacklist.s.sol:DeployCMTATWithBlacklist \
  --rpc-url <RPC> --broadcast

# with contract verification
forge script ... --broadcast --verify --etherscan-api-key <KEY>
```

Each script prints its deployed addresses with labels, so the run output doubles as a deployment record:

```
CMTAT token        0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
RuleEngine         0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3
RuleBlacklist      0x34A1D3fff3958843C43aD80F30b94c510645C316
RuleSanctionsList  0x90193C961A926261B756D1E5bb255e67ff9498A1
RuleMaxTotalSupply 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
```

## The scripts

### DeployCMTATWithWhitelist

Signature: `deploy(admin, forwarder, checkSpender, allowMintBurn)`.

Transfers are allowed only between whitelisted addresses (code `21` / `22`, and `23` for the spender when `checkSpender` is on). `run()` passes `checkSpender = false` and `allowMintBurn = true`.

**`allowMintBurn` decides whether the token can be issued at all.** The whitelist screens the mint/burn sentinel `address(0)` like any other participant, so with `false` every mint is rejected with code `24`, even to a whitelisted investor. The script used to hard-code `false` and produced a token nobody could issue (`CLAUDE_ANALYSIS_SCRIPT.md` S-3). Both directions are pinned by tests. Recoverable either way with `setAllowMint` / `setAllowBurn`, which `RuleWhitelist` gates on `DEFAULT_ADMIN_ROLE`, so the admin the script hands over to can always recover.

### DeployCMTATWithBlacklist

Signature: `deploy(admin, forwarder)`.

Blocks transfers involving a blacklisted sender, recipient or spender (codes `36` to `38`). The list starts empty, so a freshly deployed token allows every transfer until an address is added. Mint is open: `address(0)` is not on the list and `RuleBlacklist` has no mint flag.

This is the inverse default of the whitelist script, and worth being deliberate about. A whitelist token is closed until you open it; a blacklist token is open until you close it.

### DeployCMTATWithMaxTotalSupply

Signature: `deploy(admin, deployer, forwarder, maxTotalSupply)`. `run()` reads the cap from `CMTAT_MAX_SUPPLY`, default `1000000`.

Caps mints so that `totalSupply()` never exceeds `maxTotalSupply` (code `50`, or `51` when the supply cannot be read). Transfers and burns always pass, and a burn frees room for a later mint. The cap is in base units: with the default `CMTAT_DECIMALS = 0` that is whole tokens.

**Step order matters.** `RuleMaxTotalSupply` validates its token at construction (non-zero, has code, `totalSupply()` callable), so the script deploys the token first, then the rule, then calls `setRuleEngine`. The rule is constructed with `admin`, so `MAX_TOTAL_SUPPLY_ROLE` and `setTokenContract` belong to the final admin from the start.

To combine the cap with other rules, use the three-rule script below, which puts it behind a RuleEngine. For the order that leaves no unscreened window (a RuleEngine passed in the token constructor, token bound last), see [`DEPLOY_RULE_MAX_TOTAL_SUPPLY_CMTAT_V3.3.0.md`](./DEPLOY_RULE_MAX_TOTAL_SUPPLY_CMTAT_V3.3.0.md).

### DeployCMTATWithReceiverWhitelist

Signature: `deploy(admin, forwarder)`.

Screens only the receiver, as ERC-3643 eligibility does (code `90`). The sender and spender are never checked, so a holder removed from the list can still send to a listed receiver. Mints are screened on the receiver, with no `allowMint` flag; burns always pass. The list starts empty, so nothing can be minted until investors are added.

### DeployCMTATWithSpenderWhitelist

Signature: `deploy(admin, forwarder)`.

Acts only on `transferFrom`: the spender must be listed (code `66`). Direct transfers, mints and burns always pass, so on its own the token screens no holder. In production, combine it behind a RuleEngine with a rule that screens holders (`RuleWhitelist`, `RuleReceiverWhitelist` or `RuleIdentityRegistry`).

### DeployCMTATWithWhitelistWrapper

Signature: `deploy(admin, deployer, forwarder, checkSpender, allowMintBurn)`, returning the token, the wrapper and both children. `run()` passes `checkSpender = false`, `allowMintBurn = true`.

Two child whitelists, one per operator, are owned by `admin` from the start. The wrapper is constructed with `deployer` as temporary admin so that it can `addRule` both children, then it is passed to the token's constructor and the wrapper is handed over; the token gets `admin` directly. An address listed in **either** child is eligible. The children are never set on the token or added to a RuleEngine. Mint and burn depend on the wrapper's own `allowMintBurn`, not on the children's flags; with `false`, every mint is rejected with code `24`.

### DeployCMTATWithSanctionsList

Signature: `deploy(admin, forwarder, sanctionsOracle)`. `run()` reads the oracle from `SANCTIONS_ORACLE`.

The sanctions rule alone, set directly on the token (codes `30` to `32`). On CMTAT v3.3 the minter and burner are screened too. **An unset oracle fails open**, as in the engine scripts. An oracle address without code, or a reverting oracle, makes every operation revert.

### DeployCMTATWithERC2980

Signature: `deploy(admin, forwarder, allowMintBurn)`. `run()` passes `allowMintBurn = true`.

ERC-2980 whitelist (receiver only) plus frozenlist (sender, receiver and `transferFrom` spender; frozen takes priority), codes `60` to `65`. The rule's frozenlist is separate from the token's own freeze. On CMTAT v3.3 the minter is also checked against the frozenlist.

### DeployCMTATWithIdentityRegistry

Signature: `deploy(admin, forwarder, checkSender, checkSpender)`, returning the token, the registry and the rule. `run()` passes `false, false`: receiver only, as ERC-3643 requires.

Deploys an `IdentityRegistryWhitelist` owned by `admin` as the registry, and `RuleIdentityRegistry` pointing at it, set directly on the token (codes `55` to `57`). CMTAT has no identity-registry slot, so the token never calls the registry and needs no role on it. A de-listed holder can still send.

### DeployCMTATWithMaxBalance

Signature: `deploy(admin, deployer, forwarder, maxBalance)`. `run()` reads the cap from `CMTAT_MAX_BALANCE`, default `100000` base units.

Caps what one address may hold (codes `81`, `82`), screening the receiver; burns are exempt. Deployed after the token, which its constructor validates. **Bypassable by splitting a position across wallets**: in production combine it behind a RuleEngine with a one-address-per-investor rule. `maxBalance = 0` forbids holding, it does not disable the rule.

### DeployCMTATWithChainlinkPoR

Signature: `deploy(admin, deployer, forwarder, feed, maxStalenessSeconds)`. `run()` reads `CHAINLINK_POR_FEED` and `CHAINLINK_POR_MAX_STALENESS` (default `86400`).

Caps mints at the reserves reported by a Chainlink Proof of Reserve feed (codes `75` to `79`); transfers and burns always pass. Deployed after the token; the token decimals are read from the token. **Without a feed**, `run()` deploys an `AggregatorV3Mock` on the local chain (31337) so that the CI dry run succeeds, and logs a warning; on any other chain it reverts with `DeployCMTATWithChainlinkPoR_FeedNotConfigured`. The rule admin can repoint the feed, so it controls how much can be minted.

### DeployCMTATWithConditionalTransferLight

Signature: `deploy(admin, deployer, forwarder)`.

An operation rule: each transfer needs an operator approval of the exact `(from, to, value)`, consumed by the transfer (code `46` without one, `85` while unbound). Mints and burns need no approval. The rule is constructed with `deployer` as temporary admin so that it can `bindToken(token)` once the token exists, then the rule is handed over. The token is created with `admin` and the rule in its constructor, so it gets no temporary admin; until `bindToken` every operation reverts. One token per rule.

### DeployCMTATWithConditionalTransferLightMultiToken

Signature: `deploy(admin, deployer, forwarder)`.

The same approval flow, keyed per token, so one rule can serve several tokens (one `bindToken` each). **Direct binding only: never add it to a RuleEngine.** Off-chain checks use `detectTransferRestrictionForToken(token, ...)`: called by anyone other than the bound token, the plain `detectTransferRestriction` always answers `46`. Same temporary-admin and hand-over pattern as the previous script.

### DeployCMTATWithMintAllowance

Signature: `deploy(admin, deployer, forwarder)`.

A per-minter quota debited on each mint (code `70`), needing CMTAT v3.3 or later. The script sets **no quota**, so every mint is refused until the operator sets one, **including the admin's**: the admin is not exempt. Pre-check a mint with `detectTransferRestrictionFrom(minter, address(0), to, value)`; the 3-argument view always answers `0`. Same temporary-admin and hand-over pattern as the conditional-transfer scripts.

### DeployCMTATWithIssuanceCap

Signature: `deploy(admin, deployer, forwarder, issuanceCap)`. `run()` reads the cap from `CMTAT_ISSUANCE_CAP`, default `1000000` base units; `initialIssued` is `0` (new token).

Caps cumulative issuance: burns never free room (code `86`, and `50` / `51` from the inherited supply check). Deployed after the token and bound to it, with the same temporary-admin and hand-over pattern. The observed token is locked and the rule accepts one binding, so it serves one token. Not for bridged tokens: each bridge round trip uses up the cap.

### DeployCMTATWithBlacklistAndSanctionsList

Signature: `deploy(admin, deployer, forwarder, sanctionsOracle)`.

Adds a `RuleEngine` holding `RuleBlacklist` then `RuleSanctionsList` (codes `30` to `32`). The engine is deployed with no token and the deployer as temporary admin, the rules are added, the token is created with `admin` and the engine in its constructor, and the engine binds the token last; only the engine is handed over. Rule order affects only *which* code a rejected transfer reports, since the engine returns the first non-zero one, not whether it is rejected. `testBlacklistTakesPriorityOverSanctions` pins that ordering.

**Which engine is deployed depends on `forwarder`.** Since RuleEngine `v3.0.0-rc7`, ERC-2771 is opt-in: the plain `RuleEngine(admin, token)` has no trusted forwarder, and `RuleEngine2771(admin, forwarder, token)` is the variant that has one. Both engine scripts deploy `RuleEngine` when `forwarder == address(0)` and `RuleEngine2771` otherwise, so the engine trusts the same forwarder as the token and the rules. The returned value is typed `RuleEngine` in both cases (`RuleEngine2771` extends it). Either way, token callbacks (`transferred`, `created`, `destroyed`) are never relayable: rc7 identifies the token by `msg.sender`. The same choice applies to the next script; `testRuleEngineHasNoForwarderWhenNoneIsGiven` and `testRuleEngineTrustsTheForwarderWhenOneIsGiven` pin it in both.

> ⚠️ **An unset oracle fails open.** With `sanctionsOracle == address(0)` the rule is registered, the engine reports no error, and every transfer passes the sanctions check. The deployment looks complete and screening is off. The oracle address is chain-specific, so there is no safe default.

### DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply

Signature: `deploy(admin, deployer, forwarder, sanctionsOracle, maxTotalSupply)`.

The same, plus `RuleMaxTotalSupply` capping mints at `maxTotalSupply` (code `50`, or `51` when the supply cannot be read). Burning frees headroom for a later mint, which `testBurningFreesHeadroomForANewMint` pins.

**Step order matters here.** `RuleMaxTotalSupply` validates its token at construction: non-zero, has code, and `totalSupply()` callable. It therefore cannot be deployed before the token exists, and passing a placeholder reverts with `RuleMaxTotalSupply_TokenIsNotAContract`. The order is: engine (no token yet), token with the engine in its constructor, the cap rule, `addRule` for the three rules, then `bindToken` last.

## After deployment

Nothing below can be done by the script, because only the operator knows the values.

| Script | Still required |
| --- | --- |
| Whitelist | Add every participant with `addAddress` / `addAddresses`. Until then transfers fail, including to the admin, who is not whitelisted by deployment. |
| Blacklist | Nothing to make it work. Add addresses as needed. Review that an open-by-default token is what you want. |
| Max total supply | Confirm `CMTAT_MAX_SUPPLY` is the real cap, in base units, and not the `1000000` default. Check `remainingMintable()`. |
| Receiver whitelist | Add investors with `addAddress` / `addAddresses`. |
| Spender whitelist | List the permitted spenders with `addAddress`; until then every `transferFrom` is rejected. |
| Whitelist wrapper | Grant each operator `ADDRESS_LIST_ADD_ROLE` / `ADDRESS_LIST_REMOVE_ROLE` on its own child, then list investors there. |
| Sanctions list | **Set the oracle** with `setSanctionListOracle`, unless `SANCTIONS_ORACLE` was set. |
| ERC-2980 | Whitelist receivers with `addWhitelistAddresses`; until then every mint and transfer fails with code `63`. |
| Identity registry | Register investors with `registry.registerIdentity(wallet, address(0), 0)` (`IDENTITY_REGISTRAR_ROLE`). |
| Max balance | Confirm `CMTAT_MAX_BALANCE`, and exempt the treasury or custodian with `addExemptAddresses`. |
| Chainlink PoR | Check `rule.maxBackedSupply()` against the expected reserves, and set the staleness to the feed's heartbeat. |
| Conditional transfer | Grant `OPERATOR_ROLE` to whoever approves transfers. |
| Conditional transfer, multi-token | Grant `OPERATOR_ROLE`; approvals are `approveTransfer(token, from, to, value)`. |
| Mint allowance | Set each minter's quota with `setMintAllowance` (`ALLOWANCE_OPERATOR_ROLE`). |
| Issuance cap | Confirm `CMTAT_ISSUANCE_CAP`; raise it later with `increaseMaxTotalSupply`. |
| Blacklist + sanctions | **Set the oracle** with `setSanctionListOracle`, unless `SANCTIONS_ORACLE` was set. |
| The three-rule script | The same oracle step, plus confirm `CMTAT_MAX_SUPPLY` is the real cap and not the `1000000` default. |
| All | Grant operational roles (minter, pauser, list managers) to whoever needs them. The admin implicitly holds all roles, so nothing is blocked, but relying on that means a single key does everything. |
| All | Run a small end-to-end transfer before enabling production flows. |

## Limitations

**The deployed token is not upgradeable.** These scripts deploy `CMTATStandardStandalone`, not a proxy. There is no upgrade path afterwards; migration means deploying a new token.

**A single address ends up holding everything.** The hand-over grants `DEFAULT_ADMIN_ROLE` to one `admin`, and under `run()` that is whoever broadcast the transaction. No multisig or timelock is wired up, and no role separation is applied. For production, hand over to a multisig and split roles afterwards.

**Addresses are not deterministic.** Contracts are created with plain `new`, so addresses depend on the deployer's nonce. Re-running a script produces different addresses, and the same script on two chains does not give matching ones. There is no CREATE2 or salt support.

**One `RuleMaxTotalSupply` instance protects one token, with no on-chain guard.** It reads `totalSupply()` from the `tokenContract` it was given, never from whichever token triggered the check, and behind a RuleEngine it cannot learn that identity. Adding this instance to a second RuleEngine caps both tokens against this one's supply. Deploy a second instance instead. The same applies to `RuleChainlinkPoR`, which no script deploys.

**Sanctions screening fails open when unset**, as described above. This is the rule's documented behaviour, not a script defect, but the script default is the unsafe value because a chain-specific address has no sensible default.

**`CMTAT_DECIMALS` defaults to `0`.** Correct for CMTA equity tokens per the CMTAT specification, and wrong for most other instruments. It is irrevocable after construction.

**The metadata defaults are examples.** `CMTAT_ISIN`, the `https://cmta.ch` terms URI and the document hash are placeholders that will be written on-chain unless overridden. They are legal metadata, so review them.

**No post-deployment assertion on-chain.** The scripts do not check, after the fact, that the rules are attached and the roles handed over. The tests cover it, but a partial failure on a live chain would not be caught by the script itself.

## Testing

Two layers, and they cover different things.

**Unit tests**, in [`test/DeploymentScripts/`](../../../test/DeploymentScripts/), call `deploy()` directly and assert the wiring, the role hand-over, and the resulting compliance behaviour end to end: 145 tests across the seventeen scripts, including that the admin owns everything and the deployer owns nothing.

**A `forge script` dry run in CI**, one per script, in `.github/workflows/test.yml`.

The second exists because the first cannot cover the execution model. `deploy()` is a plain call with no broadcast context, so the guard that fires under `forge script` never runs. Calling `run()` from a test instead does not work either:

| Attempt | Result |
| --- | --- |
| `script.run()` from a test | Fails with an `AccessControlUnauthorizedAccount` that is an artefact of the harness, not the real error |
| `vm.prank(DEFAULT_SENDER)` then `run()` | The prank is consumed by the preceding `new Script()`, a CREATE |
| Construct first, then prank, then `run()` | `broadcasting and pranks are not compatible` |

Foundry refuses to combine a prank with a broadcast, so no test can present itself to `run()` as the broadcaster. This was confirmed by reintroducing the bug into a fixed script: all six of that script's unit tests still passed, while the dry-run step failed. `forge script` is the only faithful harness, which is why it runs in CI.
