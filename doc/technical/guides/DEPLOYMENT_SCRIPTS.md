# Deployment Scripts

[TOC]

This document covers the Foundry scripts in [`script/`](../../../script/): what each one deploys, the shape they all share, how to configure them, what you still have to do after running one, and the limitations worth knowing before you use them on a real chain.

Every script produces a working CMTAT token with compliance rules attached and all admin rights held by a single address you choose. None of them is a turnkey issuance: each leaves configuration that only the operator can supply, listed per script under [After deployment](#after-deployment).

## Inventory

| Script | Deploys | Topology | Tests |
| --- | --- | --- | --- |
| `DeployCMTATWithWhitelist.s.sol` | CMTAT + `RuleWhitelist` | B (direct) | 7 |
| `DeployCMTATWithBlacklist.s.sol` | CMTAT + `RuleBlacklist` | B (direct) | 6 |
| `DeployCMTATWithMaxTotalSupply.s.sol` | CMTAT + `RuleMaxTotalSupply` | B (direct) | 8 |
| `DeployCMTATWithBlacklistAndSanctionsList.s.sol` | CMTAT + `RuleEngine` + 2 rules | A (engine) | 18 |
| `DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply.s.sol` | CMTAT + `RuleEngine` + 3 rules | A (engine) | 19 |

All five share [`script/base/CMTATDeploymentBase.sol`](../../../script/base/CMTATDeploymentBase.sol), which holds the token metadata, the environment configuration, and the address-logging helper.

## The shape every script shares

Each script exposes two entry points:

| Function | Used by | Notes |
| --- | --- | --- |
| `deploy(...)` | tests, and other scripts | Plain function call. Takes `admin` and `deployer` explicitly. |
| `run()` | `forge script` | Wraps `deploy` in `vm.startBroadcast()`, passing `msg.sender` for both. |

### Why the deployer is a parameter

`deploy()` takes both an `admin` and a `deployer`, which looks redundant since `run()` passes the same address for both. It is not redundant, and reading the deployer from `address(this)` instead is a bug that these scripts used to have.

Under `forge script` the calls are made by the **broadcaster**, not by the script contract. Two independent things break if a script assumes otherwise:

1. Foundry rejects `address(this)` inside a broadcast outright, with *"script contracts are ephemeral and their addresses should not be relied upon"*. The script reverts during simulation.
2. Even without that guard, `renounceRole` would fail. It is not `revokeRole`: its second argument is a confirmation that the caller is that account (`AccessControl.sol:155`), so `token.renounceRole(role, deployer)` only succeeds when `msg.sender == deployer`.

Three of the four scripts read `address(this)` and could not deploy anything at all until this was fixed. The full write-up is [`CLAUDE_ANALYSIS_SCRIPT.md`](../../security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_SCRIPT.md) S-1.

### Temporary admin and hand-over

The token and the RuleEngine are constructed with `deployer` as admin, because the wiring calls that follow are role-gated: `token.setRuleEngine(...)` needs admin on the token, `ruleEngine.addRule(...)` needs rights on the engine. The rules are constructed with `admin` directly, because nothing in the script ever configures them. `addRule` is a call on the engine, not on the rule.

| Contract | Constructor admin | Deployer ever holds rights? | Handed over at the end? |
| --- | --- | --- | --- |
| CMTAT token | `deployer` | Yes | Yes |
| `RuleEngine` | `deployer` | Yes | Yes |
| Each rule | `admin` | No | Not needed |

The hand-over is a grant followed by a renounce, in that order, because `AccessControl` has no atomic transfer and renouncing first would leave nobody able to grant:

```solidity
if (admin != deployer) {
    ruleEngine.grantRole(ruleEngine.DEFAULT_ADMIN_ROLE(), admin);
    ruleEngine.renounceRole(ruleEngine.DEFAULT_ADMIN_ROLE(), deployer);
    token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
    token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
}
```

**The `if` is load-bearing.** In `run()` both arguments are `msg.sender`, so `admin == deployer`. Without the guard the grant would be a no-op and the renounce would then strip the only administrator, leaving a token nobody can ever configure or mint. Removing the guard and running the `admin == deployer` case was measured: the contract ends with no admin at all.

Both CMTAT and `RuleEngine` grant exactly one role at construction, `DEFAULT_ADMIN_ROLE`, so renouncing it is complete. If someone later adds an explicit `grantRole(SOME_ROLE, deployer)` to the wiring, this block would not remove it and the current tests would not notice.

### The two topologies

The scripts deliberately use both integration models described in `CLAUDE.md`, and the choice changes what `msg.sender` is inside a rule:

- **Topology B, direct binding** (`DeployCMTATWithWhitelist`, `DeployCMTATWithBlacklist`, `DeployCMTATWithMaxTotalSupply`). The rule is passed straight to `token.setRuleEngine(rule)`, with no engine in between, so inside the rule `msg.sender` is the token. Fine for a single validation rule, and cheaper: one contract fewer and no engine hop per transfer.
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
| `SANCTIONS_ORACLE` | `address(0)` | the two sanctions scripts |
| `CMTAT_MAX_SUPPLY` | `1000000` | the two scripts deploying `RuleMaxTotalSupply` |

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

Signature: `deploy(admin, deployer, forwarder, checkSpender, allowMintBurn)`.

Transfers are allowed only between whitelisted addresses (code `21` / `22`, and `23` for the spender when `checkSpender` is on). `run()` passes `checkSpender = false` and `allowMintBurn = true`.

**`allowMintBurn` decides whether the token can be issued at all.** The whitelist screens the mint/burn sentinel `address(0)` like any other participant, so with `false` every mint is rejected with code `24`, even to a whitelisted investor. The script used to hard-code `false` and produced a token nobody could issue (`CLAUDE_ANALYSIS_SCRIPT.md` S-3). Both directions are pinned by tests. Recoverable either way with `setAllowMint` / `setAllowBurn`, which `RuleWhitelist` gates on `DEFAULT_ADMIN_ROLE`, so the admin the script hands over to can always recover.

### DeployCMTATWithBlacklist

Signature: `deploy(admin, deployer, forwarder)`.

Blocks transfers involving a blacklisted sender, recipient or spender (codes `36` to `38`). The list starts empty, so a freshly deployed token allows every transfer until an address is added. Mint is open: `address(0)` is not on the list and `RuleBlacklist` has no mint flag.

This is the inverse default of the whitelist script, and worth being deliberate about. A whitelist token is closed until you open it; a blacklist token is open until you close it.

### DeployCMTATWithMaxTotalSupply

Signature: `deploy(admin, deployer, forwarder, maxTotalSupply)`. `run()` reads the cap from `CMTAT_MAX_SUPPLY`, default `1000000`.

Caps mints so that `totalSupply()` never exceeds `maxTotalSupply` (code `50`, or `51` when the supply cannot be read). Transfers and burns always pass, and a burn frees room for a later mint. The cap is in base units: with the default `CMTAT_DECIMALS = 0` that is whole tokens.

**Step order matters.** `RuleMaxTotalSupply` validates its token at construction (non-zero, has code, `totalSupply()` callable), so the script deploys the token first, then the rule, then calls `setRuleEngine`. The rule is constructed with `admin`, so `MAX_TOTAL_SUPPLY_ROLE` and `setTokenContract` belong to the final admin from the start.

To combine the cap with other rules, use the three-rule script below, which puts it behind a RuleEngine. For the order that leaves no unscreened window (a RuleEngine passed in the token constructor, token bound last), see [`DEPLOY_RULE_MAX_TOTAL_SUPPLY_CMTAT_V3.3.0.md`](./DEPLOY_RULE_MAX_TOTAL_SUPPLY_CMTAT_V3.3.0.md).

### DeployCMTATWithBlacklistAndSanctionsList

Signature: `deploy(admin, deployer, forwarder, sanctionsOracle)`.

Adds a `RuleEngine` holding `RuleBlacklist` then `RuleSanctionsList` (codes `30` to `32`). Rule order affects only *which* code a rejected transfer reports, since the engine returns the first non-zero one, not whether it is rejected. `testBlacklistTakesPriorityOverSanctions` pins that ordering.

**Which engine is deployed depends on `forwarder`.** Since RuleEngine `v3.0.0-rc7`, ERC-2771 is opt-in: the plain `RuleEngine(admin, token)` has no trusted forwarder, and `RuleEngine2771(admin, forwarder, token)` is the variant that has one. Both engine scripts deploy `RuleEngine` when `forwarder == address(0)` and `RuleEngine2771` otherwise, so the engine trusts the same forwarder as the token and the rules. The returned value is typed `RuleEngine` in both cases (`RuleEngine2771` extends it). Either way, token callbacks (`transferred`, `created`, `destroyed`) are never relayable: rc7 identifies the token by `msg.sender`. The same choice applies to the next script; `testRuleEngineHasNoForwarderWhenNoneIsGiven` and `testRuleEngineTrustsTheForwarderWhenOneIsGiven` pin it in both.

> ⚠️ **An unset oracle fails open.** With `sanctionsOracle == address(0)` the rule is registered, the engine reports no error, and every transfer passes the sanctions check. The deployment looks complete and screening is off. The oracle address is chain-specific, so there is no safe default.

### DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply

Signature: `deploy(admin, deployer, forwarder, sanctionsOracle, maxTotalSupply)`.

The same, plus `RuleMaxTotalSupply` capping mints at `maxTotalSupply` (code `50`, or `51` when the supply cannot be read). Burning frees headroom for a later mint, which `testBurningFreesHeadroomForANewMint` pins.

**Step order matters here.** `RuleMaxTotalSupply` validates its token at construction: non-zero, has code, and `totalSupply()` callable. It therefore cannot be deployed before the token exists, and passing a placeholder reverts with `RuleMaxTotalSupply_TokenIsNotAContract`.

## After deployment

Nothing below can be done by the script, because only the operator knows the values.

| Script | Still required |
| --- | --- |
| Whitelist | Add every participant with `addAddress` / `addAddresses`. Until then transfers fail, including to the admin, who is not whitelisted by deployment. |
| Blacklist | Nothing to make it work. Add addresses as needed. Review that an open-by-default token is what you want. |
| Max total supply | Confirm `CMTAT_MAX_SUPPLY` is the real cap, in base units, and not the `1000000` default. Check `remainingMintable()`. |
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

**Unit tests**, in [`test/DeploymentScripts/`](../../../test/DeploymentScripts/), call `deploy()` directly and assert the wiring, the role hand-over, and the resulting compliance behaviour end to end: 58 tests across the five scripts, including that the admin owns everything and the deployer owns nothing.

**A `forge script` dry run in CI**, one per script, in `.github/workflows/test.yml`.

The second exists because the first cannot cover the execution model. `deploy()` is a plain call with no broadcast context, so the guard that fires under `forge script` never runs. Calling `run()` from a test instead does not work either:

| Attempt | Result |
| --- | --- |
| `script.run()` from a test | Fails with an `AccessControlUnauthorizedAccount` that is an artefact of the harness, not the real error |
| `vm.prank(DEFAULT_SENDER)` then `run()` | The prank is consumed by the preceding `new Script()`, a CREATE |
| Construct first, then prank, then `run()` | `broadcasting and pranks are not compatible` |

Foundry refuses to combine a prank with a broadcast, so no test can present itself to `run()` as the broadcaster. This was confirmed by reintroducing the bug into a fixed script: all six of that script's unit tests still passed, while the dry-run step failed. `forge script` is the only faithful harness, which is why it runs in CI.
