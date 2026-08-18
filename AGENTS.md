# Project Guide

## Purpose
Modular compliance-rule library for CMTAT / ERC-3643 security tokens. Each rule enforces a transfer restriction (whitelist, spender whitelist, blacklist, sanctions, max supply, identity, conditional approval, mint quota) and can be used standalone or composed via a `RuleEngine`.

## Architecture Overview
A rule answers two questions about a proposed token movement:
- **Read path** — `detectTransferRestriction` / `detectTransferRestrictionFrom` / `canTransfer` / `canTransferFrom` return an ERC-1404 restriction code (`0` = OK). These are views and must not revert.
- **Write path** — `transferred` / `created` / `destroyed` are called by the token *after* it has decided to move value; the rule **reverts** to block, and may mutate state.

### The two integration topologies (this determines `msg.sender` inside a rule)
```
Topology A — "RuleEngine mode" (default)
  CMTAT ──transferred(spender,from,to,value)──▶ RuleEngine ──transferred(...)──▶ Rule
                                                              msg.sender == RuleEngine
  ⇒ bind the RuleEngine to an operation rule, not the token.

Topology B — "direct mode" (CMTAT.setRuleEngine(rule))
  CMTAT ──transferred(spender,from,to,value)──▶ Rule
                                                 msg.sender == CMTAT token
  ⇒ bind the token.
```
Operation rules that treat `msg.sender` or `getTokenBound()` as a *token identity* behave differently in the two topologies. `approveAndTransferIfAllowed` only works in Topology B.

### The mint/burn `spender` convention (CMTAT v3.3+)
`CMTAT._mintOverride` calls `_checkTransferred(_msgSender(), address(0), to, value)`, so **on every mint the minter's address arrives at each rule as `spender`** via the 4-arg `transferred` overload. Plain `transfer()` passes `spender == address(0)` and takes the 3-arg path.

- `RuleWhitelist`, `RuleSpenderWhitelist`, `RuleWhitelistWrapper` explicitly exempt mint/burn from the spender check.
- `RuleIdentityRegistry`, `RuleBlacklist`, `RuleSanctionsList`, `RuleERC2980` do **not** — they screen the minter. For the deny-lists this is intended; for `RuleIdentityRegistry` it means the minter must itself be identity-verified (see `CLAUDE_AUDIT.md` F-1).
- `RuleMintAllowance` is the only rule that *uses* the mint spender: it debits `mintAllowance[spender]`.
- `RuleMaxTotalSupply` and `RuleChainlinkPoR` ignore the spender entirely — they cap *supply*, not identities, and act only when `from == address(0)`.

Full per-rule semantics (who each rule screens, mint/burn handling, unset-oracle behaviour, stateful?, authoritative view) are tabulated in `doc/technical/guides/RULE_SEMANTICS.md` — consult it before assuming any rule behaves like its siblings.

### Standards conformance (non-negotiable)
Rules that implement a standardized interface must match that standard's semantics, not merely its function signatures. Specs are vendored in `doc/ERCSpecification/` — read them before changing a rule's screening logic.

- **`RuleIdentityRegistry` conforms to ERC-3643 (enforced, I-1).** The spec mandates that **only the receiver** be identity-verified: *"The receiver MUST be whitelisted on the Identity Registry and verified"*; `transferFrom` "works the same way"; `mint` and `forcedTransfer` "only require the receiver"; `burn` "bypasses all checks on eligibility". The sender, the spender and the minter are **not** required to be verified — do not re-add those checks as defaults. Screening the sender **traps de-listed holders** (the spec checks only the receiver precisely so a lapsed investor can still exit their position). Stricter screening is available as an explicit opt-in via the `checkSender` / `checkSpender` flags, both defaulting to `false`.
- **`isVerified(address(0))` must be `false`** — ERC-3643 defines `isVerified` as "is this wallet a valid investor holding the required claims", and `address(0)` is not a wallet. Likewise `RuleERC2980`'s `whitelist(address)` / `frozenlist(address)` are MANDATORY ERC-2980 getters and must not return `true` for `address(0)`. **Enforced (I-12):** mint/burn permission is an explicit `allowMint` / `allowBurn` flag, and the zero address can never enter any list — **both single and batch adds revert on it**. The batch functions skip *duplicates* but reject `address(0)`, deliberately: silently dropping it would make the emitted `AddAddresses` event name the sentinel as a set member, re-polluting the off-chain view the guard exists to keep clean. Never re-introduce "whitelist `address(0)` to enable mint/burn".

## Key Directories
| Path | Description |
|---|---|
| `src/rules/validation/` | Read-only rules (view functions, no state changes during transfer) |
| `src/rules/operation/` | Read-write rules (modify state on transfer) |
| `src/rules/validation/abstract/core/` | `RuleTransferValidation` (ERC-1404/3643/7551 views), `RuleNFTAdapter` (ERC-7943 + `ITransferContext` overloads), `RuleWhitelistShared`, `TokenSupplyReader` (revert-free `totalSupply()` read, shared by `RuleMaxTotalSupply` and `RuleChainlinkPoR`), `ChainlinkPoRFeedManager` (PoR feed configuration + the revert-free reserve read; **no constructor, no ERC-1404**, so it is reusable and initializer-agnostic), `TotalSupplyCapManager` and `BalanceCapManager` (the same split for `RuleMaxTotalSupply` and `RuleMaxBalance`: state, setters and the revert-free read, with the constructor and the restriction-code mapping left in the rule), `CapAccounting` (the cap comparison shared by all three cap rules; stateless, so it adds no slot) |
| `src/rules/validation/abstract/` | Shared base contracts and invariant storage |
| `src/rules/interfaces/` | Shared interfaces (`IAddressList`, `IIdentityRegistry`, `ISanctionsList`, `ITotalSupply`, `ITransferContext`, `IERC2980`, `IERC7943NonFungibleCompliance`, `AggregatorV3Interface`, `IDecimals`) |
| `src/registry/` | Contracts filling a token's **identity registry** slot, not its compliance slot (`IdentityRegistryWhitelist`). Not rules: no `IRule`, never added to a RuleEngine |
| `src/modules/` | Reusable modules (`AccessControlModuleStandalone`, `MetaTxModuleStandalone`, `VersionModule`, `Ownable2StepERC165Module`) |
| `doc/technical/contracts/` | One documentation page per deployable contract |
| `doc/technical/guides/` | Cross-cutting docs: `RULE_SEMANTICS.md`, `INVARIANT_TESTS.md`, `DEPLOYMENT_SCRIPTS.md` |
| `test/` | Foundry tests, one folder per rule |
| `lib/` | Git submodule dependencies (do not edit) |

## Key Files to Read First
1. `src/rules/validation/abstract/core/RuleTransferValidation.sol` — the read-path interface every rule implements; declares the `_detectTransferRestriction*` hooks.
2. `src/rules/validation/abstract/core/RuleNFTAdapter.sol` — adds the ERC-7943 `tokenId` overloads and the `ITransferContext` struct entrypoints; declares the `_transferred*` write hooks.
3. `src/rules/validation/abstract/RuleAddressSet/RuleAddressSet.sol` — the `EnumerableSet` membership machinery shared by whitelist/blacklist/spender-whitelist.
4. `src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol` — the approval state machine (`approvalCounts`, `_transferHash`).
5. `src/rules/operation/abstract/RuleMintAllowanceBase.sol` — the only rule keyed on the mint `spender`.
6. `lib/RuleEngine/src/RuleEngineBase.sol` — how a rule actually gets called.

## Main Contracts
| Contract | Role |
|---|---|
| `RuleWhitelist` / `RuleWhitelistOwnable2Step` | Allow transfers only between whitelisted addresses |
| `RuleReceiverWhitelist` / `RuleReceiverWhitelistOwnable2Step` | Screen **only the receiver**, reproducing ERC-3643 eligibility. Sender and spender are never checked — do not add those, it traps de-listed holders (same reasoning as I-1). Burn is exempt (`to == address(0)` can never be listed); mint is screened on the receiver with no `allowMint` flag. Code 81 |
| `RuleWhitelistWrapper` / `Ownable2Step` | Aggregate multiple whitelist rules (OR logic) |
| `RuleBlacklist` / `RuleBlacklistOwnable2Step` | Block transfers involving blacklisted addresses |
| `RuleSanctionsList` | Block sanctioned addresses via Chainalysis oracle |
| `RuleMaxBalance` / `RuleMaxBalanceOwnable2Step` | Cap how many tokens **one address** may hold, with an operator-managed exemption list. Screens the receiver only; burns exempt; mints capped. Codes 82, 83. **Bypassable by splitting across wallets** — pair with a rule admitting one address per investor (`RuleWhitelist` / `RuleReceiverWhitelist` / `RuleIdentityRegistry`) and an onboarding policy of one address per entity. `maxBalance = 0` forbids holding, it does NOT disable the rule |
| `RuleMaxTotalSupply` | Cap minting so total supply never exceeds a maximum |
| `RuleMaxTotalSupplyERC3643` / `…Ownable2Step` | **ERC-3643-only** variant of `RuleMaxTotalSupply`, same re-phasing as `RuleChainlinkPoRERC3643` and the same silent-misconfiguration warning. Compose with `RuleChainlinkPoRERC3643` to add a static ceiling to the reserve-backed one. Codes 50, 51 |
| `RuleChainlinkPoR` / `RuleChainlinkPoROwnable2Step` | Cap minting at the reserves reported by a Chainlink Proof of Reserve feed (`AggregatorV3Interface`). The limit equals the reported reserves exactly — no margin parameter (deliberately dropped from Chainlink's `SecureMintPolicy`); compose with `RuleMaxTotalSupply` for a static cap. Mints only; transfers and burns always pass, so a stale or broken feed never traps holders. The read path is guarded (`code.length` check + `try/catch` + saturating arithmetic) so the ERC-1404 views never revert |
| `RuleChainlinkPoRERC3643` / `…Ownable2Step` | **ERC-3643-only** variant of `RuleChainlinkPoR`. Identical reserve logic; re-phases the **write** path because ERC-3643 calls compliance *after* the mint (`_mint` then `created`, forwarded by `RuleEngine` as the 3-arg `transferred(0, to, value)`), so `totalSupply()` already includes it. The read views still project the pending amount — the token calls `canTransfer` *before* `_mint`. Do not use with CMTAT, and do not use the stock rule with ERC-3643: both mistakes are silent. Codes 75–79 |
| `RuleIdentityRegistry` | Check ERC-3643 identity registry for participant verification |
| `IdentityRegistryWhitelist` | The mirror image of `RuleIdentityRegistry`: **is** an ERC-3643 identity registry, backed by a whitelist, so no ONCHAINID is needed. Keeps **no identity state** — `_identity` and `_country` are accepted for signature compatibility then discarded, and `investorCountry` is a constant 0; do not add identity storage back. Inherits `RuleAddressSetInternal` (the same set machinery as `RuleWhitelist`) rather than deploying or re-implementing a whitelist — **only the internal layer**, because `RuleAddressSet`'s public `addAddress`/`removeAddress` are not `virtual` and so could not maintain the `keyHasPurpose` reverse index; a second write path would produce verified-but-unrecoverable wallets. Installed with `token.setIdentityRegistry()`. Implements **no** ERC-734 surface: `recoveryAddress` needs a real ONCHAINID as `_investorOnchainID`. A `keyHasPurpose` implementation was tried and removed — the agent chooses which contract that call lands on, so it added no security while forcing a hash-to-wallet reverse index and duplicate-tolerant registration. Do not re-add it. The token itself must hold `IDENTITY_REGISTRAR_ROLE`. See `doc/technical/contracts/IdentityRegistryWhitelist.md` |
| `RuleSpenderWhitelist` / `RuleSpenderWhitelistOwnable2Step` | Allow `transferFrom` only when spender is whitelisted; direct transfers are always allowed |
| `RuleERC2980` | ERC-2980 Swiss Compliant rule: whitelist (recipient-only) + frozenlist (blocks sender, recipient, and spender for `transferFrom`); frozenlist takes priority |
| `RuleERC2980Ownable2Step` | Ownable2Step variant of RuleERC2980 |
| `RuleConditionalTransferLight` | Require operator approval before each transfer; bound to exactly one token at a time (`bindToken` reverts if a token is already bound; use `unbindToken` first to migrate) |
| `RuleConditionalTransferLightOwnable2Step` | Owner-only approval and execution for conditional transfers |
| `RuleConditionalTransferLightMultiToken` / `…Ownable2Step` | Conditional transfers with approvals keyed `(token, from, to, value)`. **Direct-binding-only (Topology B)** — approvals are *consumed* under `msg.sender`, so this rule must NOT be added to a RuleEngine; behind an engine it either reverts or loses all per-token isolation. See `CLAUDE_AUDIT.md` F-4 and `doc/technical/contracts/RuleConditionalTransferLightMultiToken.md` |
| `RuleMintAllowance` / `RuleMintAllowanceOwnable2Step` | Per-minter mint quota, debited on the 4-arg `transferred(spender, from=0, to, value)` path. Requires CMTAT ≥ v3.3. `canTransfer` is **not** authoritative for this rule — use `canTransferFrom(minter, address(0), to, value)` |
| `AccessControlModuleStandalone` | Base RBAC module; admin implicitly holds all roles |
| `MetaTxModuleStandalone` | ERC-2771 meta-transaction support. Note: the operation rules deliberately do **not** inherit this, so `_msgSender()` used as a binding identity is never forwarder-controlled |
| `Ownable2StepERC165Module` | Shared ERC-165 advertisement (`IERC173`, `IOwnable2Step`) for the Ownable2Step variants |
| `VersionModule` | Implements `IERC3643Version`; returns the contract version string |

## Dependencies (lib/)
- `openzeppelin-contracts` v5.7.0 — `AccessControl`, `Ownable2Step`, `EnumerableSet`, `ERC2771Context`
- `openzeppelin-contracts-upgradeable` v5.7.0
- `CMTAT` v3.3.0-rc3 (submodule pin; library supports ≥ v3.0.0) — `IERC1404`, `IERC3643`, `IRuleEngine` interfaces
- `RuleEngine` v3.0.0-rc5 — `IRule`, `RulesManagementModule`
- `forge-std` — Foundry test utilities

Remappings are in `remappings.txt`; aliases used in source: `@openzeppelin/`, `CMTAT/`, `RuleEngine/`.

## Toolchain
```bash
forge build          # compile
forge test           # run all tests
forge test -vvv      # verbose output

FOUNDRY_PROFILE=erc3643 forge test   # the real-ERC-3643-token suite (see below)
```
Foundry config: `foundry.toml` (solc 0.8.36, EVM prague, optimizer 200 runs).

**There are two profiles, and `forge test` alone does not run everything.** The vendored ERC-3643
`Token.sol` pins `pragma solidity 0.8.30` *exactly*, which cannot share a compilation unit with our
0.8.36. So `test/ERC3643Real/**` is in the default profile's `skip` list and is built by
`[profile.erc3643]` at solc 0.8.30 instead (our contracts are `^0.8.20`, so they compile there too).
CI must run **both** commands. Gotchas: profiles inherit unspecified keys from `[profile.default]`,
so that profile has to clear `skip = []` explicitly; and it writes to `out-erc3643/` to avoid
clobbering the 0.8.36 artifacts.

ERC-3643 imports `@onchain-id/solidity`, which is an npm package rather than a submodule and so is
not vendored. `test/utils/onchainid/` holds minimal `IIdentity` / `IClaimIssuer` stubs wired in by a
**context-scoped** remapping (`lib/ERC-3643/:@onchain-id/solidity/contracts/=test/utils/onchainid/`)
so they apply to the ERC-3643 build only. Only `keyHasPurpose` is ever called; everywhere else those
types appear as parameters or event fields, which canonicalise to `address` and affect no selector.

That remapping is declared as `remappings = [...]` inside `[profile.erc3643]` in `foundry.toml`, **not
in `remappings.txt`** — and it must stay there. `forge remappings` prints `remappings.txt` for every
profile; `hardhat-foundry` runs exactly that command and rejects any line containing a `:` with
*"remapping contexts are not allowed"*, which breaks `npx hardhat test` (a CI step). As profile
config it is applied only when that profile is selected, so the default and `ci` profiles Hardhat
sees stay context-free. Hardhat compiles only `src/` (Foundry's `src`), so it never needs the stubs.

## Restriction Code Ranges
| Rule | Codes |
|---|---|
| RuleWhitelist / RuleWhitelistWrapper | 21–23, 24 (mint not allowed), 25 (burn not allowed) |
| RuleSanctionsList | 30–32 |
| RuleBlacklist | 36–38 |
| RuleConditionalTransferLight / …MultiToken | 46 |
| RuleMaxTotalSupply | 50, 51 (total supply unavailable) |
| RuleIdentityRegistry | 55–57 |
| RuleERC2980 | 60–63, 64 (mint not allowed), 65 (burn not allowed) |
| RuleSpenderWhitelist | 66 |
| RuleMintAllowance | 70 |
| RuleChainlinkPoR | 75 (reserves exceeded), 76 (feed stale), 77 (answer returned but unusable), 78 (total supply unavailable), 79 (feed unreadable) |
| RuleReceiverWhitelist | 81 |
| RuleMaxBalance | 82, 83 (balance unavailable) |

## Conventions
- Each rule has an `InvariantStorage` abstract contract holding its constants, custom errors, and events.
- Access control is implemented via an abstract `_authorize*()` method overridden by concrete subclasses (template method pattern).
- AccessControl variants must use `onlyRole(ROLE)` in `_authorize*()` methods (avoid direct `_checkRole`).
- **All `_authorize*()` / `_only*()` access-control hooks are `internal view virtual`** — both the abstract declaration and every override. An authorization hook checks and reverts; it must never mutate state, and `view` makes that a compiler-enforced invariant rather than a convention. It is free: these are `internal`, so `view` costs no gas and changes no runtime behaviour. Both OZ check functions (`AccessControl._checkRole`, `Ownable._checkOwner`) are `view`, so every hook can be.
  - **One documented exception**: `RuleConditionalTransferLightMultiTokenBase._authorizeComplianceBindingChange` cannot be `view`, because it delegates to `_onlyComplianceManager()`, which `lib/RuleEngine` declares non-`view` (Solidity checks mutability against a virtual's *declared* type, not the installed override). If you hit this constraint elsewhere, document why inline — do not silently drop `view` from a hook.
- AccessControl variants treat the default admin as having all roles via `hasRole`, but the admin may not appear in role member enumerations unless explicitly granted.
- All rules **and `IdentityRegistryWhitelist`** implement `IERC3643Version` via `VersionModule`; the current version string is `"0.5.0"`. `test/Version.t.sol` asserts it for every deployable contract — keep it exhaustive, a half-covered version test reads as authoritative while missing the mirror it exists to catch.
- **ERC-165 interface IDs**: `type(IFoo).interfaceId` only XORs selectors defined directly on `IFoo` and does NOT include selectors from inherited interfaces. Always use the pre-computed library constants instead: `ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID` (from `CMTAT/library/`), `RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID` (from `CMTAT/library/`), and `RuleInterfaceId.IRULE_INTERFACE_ID` (from `RuleEngine/modules/library/`). If no pre-computed constant exists for an interface, define a flat mock interface that redeclares all functions from the full inheritance tree and use `type(IFooFlattened).interfaceId` to compute the correct value (see `lib/RuleEngine/src/mocks/IRuleInterfaceIdHelper.sol` for the established pattern).
- Batch add/remove operations are non-reverting **for duplicates and missing entries** (those are skipped and counted); single-item operations revert on the same input. The one exception is `address(0)`, which **reverts on every add path, batch included** — see I-12. A batch containing a zero entry therefore fails as a whole rather than being partially applied.
- All `internal` functions should be marked `virtual`.
- Do not create git commits; provide commit messages only when requested.
- Always run full tests (`forge test`) after any code modification, including lint-driven or mechanical refactors, before reporting completion.
- Use `require(condition, CustomError(...))` for custom errors; avoid direct `revert CustomError(...)`.
- **Keep NatSpec blocks short — 20 lines is the ceiling, and most should be far shorter.** Measured over `src/`, the median block is **4 lines** and the 90th percentile is **8**; anything past 20 is an outlier that has stopped being a comment and become a document. A reader opening a contract wants to know what it does and what will bite them, not read an essay before the first line of code. Long blocks also rot faster: the more claims a comment makes, the more of them silently go stale.
  - **State the conclusion and the warning; leave the derivation to `doc/technical/`.** This is the same rule as the no-cross-reference convention above, applied from the other end — that one says do not replace the substance with a pointer, this one says do not inflate the substance into a treatise. Both point at the same target: the comment carries what a reader with only the verified source must know, and the doc carries the reasoning.
  - **What earns its place in a long block**: a safety precondition (`must never revert`, and why that holds), a footgun (`maxBalance = 0` forbids holding, it does not disable the rule), and a non-obvious design constraint. **What does not**: restating what the code says, narrating the refactor that produced the file, or listing benefits.
- **Never reference a `doc/technical/` page from contract code.** NatSpec and comments in `src/` must not cite `doc/technical/contracts/*.md` or `doc/technical/guides/*.md`, by path or by bare filename. Documentation paths move — the `contracts/` + `guides/` split rewrote four source comments that had been correct the day before — and a stale pointer inside a deployed contract's source cannot be fixed by editing the docs. **Write the substance into the comment instead**: a reader with only the verified source must get the whole warning, not a breadcrumb to a file they may not have. If the explanation is too long for NatSpec, it is a sign the comment should state the conclusion and the doc should carry the derivation, with no cross-reference in the code.
  - **Exception: `src/mocks/`.** Test doubles are never deployed as production contracts and exist to serve the test suite, so a pointer to the page explaining what they stand in for is useful and carries no cost.
  - **Audit reports are a separate case and stay allowed**, cited by bare filename (`CLAUDE_AUDIT.md`, `CLAUDE_ANALYSIS.md`, `CLAUDE_ANALYSIS_SCRIPT.md`, `CLAUDE_ANALYSIS_MAXBALANCE.md`). They are immutable historical records of a finding, the bare filename survives the file being moved, and the finding ID is what gives a reviewer the context a comment cannot restate.
- **No emoji in code comments or NatSpec.** Use a plain word marker instead: `WARNING:`, `NOTE:`, `IMPORTANT:`. Emoji render inconsistently across editors, terminals, `forge doc` output and diffs; they are not searchable (`grep WARNING` finds the marker, `grep ⚠️` depends on the shell); and they encode as multi-byte sequences that can be silently mangled by tooling. This applies to `src/`, `test/` and `script/`. Markdown documentation may use emoji freely — the restriction is Solidity comments only.
- `AGENTS.md` and `CLAUDE.md` are identical — always update both together.
- **Two READMEs.** `README.md` at the root is a short summary (purpose, architecture, rule list, quick start) and is the GitHub front page; `doc/README.md` is the full reference. Update `doc/README.md` with the latest change, and the root `README.md` only when the summary itself becomes wrong (a new rule, a changed code range, a moved document). Links inside `doc/README.md` are relative to `doc/`.
- New rule or features implemented: create/update technical documentation — a per-contract page in `doc/technical/contracts/`, or `doc/technical/guides/` when the material spans several contracts, update `doc/README.md` (and the root summary if the rule table or code ranges change), create/update test (target: 100% of code coverage), update CHANGELOG.md. Code coverage, run `forge coverage --report summary`
- After each implemented feature or fix, provide a one-line GitHub commit message for all changes since the last commit.

## Security Findings Reference
- [`doc/security/audits/tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md`](doc/security/audits/tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md) — the v0.4.0 security audit: trust model, catalogued threats and invariants, findings (0 High/Medium, 2 Low, 8 Info), and the disposition of every threat ID. Source comments cite it by bare filename, `CLAUDE_AUDIT.md`.
- [`doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS.md`](doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS.md) — code-quality review (duplication, missing events, gas, `virtual` convention, behaviour at odds with the library's purpose). 28 findings with the disposition and commit for each, including two whose gas claims were wrong and one whose proposed remedy did not work. Source comments cite it by bare filename, `CLAUDE_ANALYSIS.md`, so the path can move.
- [`doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_SCRIPT.md`](doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_SCRIPT.md) — deployment-script review (`script/`). 12 findings, all implemented, including three scripts that reverted under `forge script` and a test-methodology gap that hid it. Source comments cite it by bare filename, `CLAUDE_ANALYSIS_SCRIPT.md`, so the path can move.
- [`doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_MAXBALANCE.md`](doc/security/audits/tools/v0.5.0/CLAUDE_ANALYSIS_MAXBALANCE.md) — code-quality review of `RuleMaxBalance` and the `ChainlinkPoRFeedManager` split. 12 findings, 2 implemented, 4 deliberately left, including a measured decision to KEEP the exemption-before-balance check order and the pre-update accounting assumption the cap rests on. Source comments cite it by bare filename, `CLAUDE_ANALYSIS_MAXBALANCE.md`.
- [`test/ThreatModel/ThreatModelTests.t.sol`](test/ThreatModel/ThreatModelTests.t.sol) — 18 PoCs. Tests suffixed `_CurrentBehaviour` assert behaviour the audit considers wrong; **fixing the underlying issue must make them fail**, at which point update the test and the finding together.

Gotchas worth knowing before you change anything:
- **Deployment scripts must take the deployer as a parameter, never read `address(this)`.** Under `forge script` the broadcaster makes the calls, not the script contract, and Foundry rejects `address(this)` inside a broadcast outright. A script that reads it passes every unit test and reverts on the real deployment path, because the tests call `deploy()` directly and never enter a broadcast context. **No unit test can cover this**: Foundry refuses to combine a prank with a broadcast, so `run()` cannot be faithfully exercised from `forge test`. The guard is the `forge script` dry-run step in CI, which runs every `script/*.s.sol`. Shared token metadata and env configuration live in `script/base/CMTATDeploymentBase.sol`. See `CLAUDE_ANALYSIS_SCRIPT.md`.
- `HelperContract` already inherits `RuleConditionalTransferLightInvariantStorage`; inheriting the multi-token variant alongside it is a compile error (`OPERATOR_ROLE`, `CODE_TRANSFER_REQUEST_NOT_APPROVED` clash).
- `RuleWhitelistWrapperBase._detectTransferRestrictionForTargets` short-circuits once every target address is resolved, so a broken child rule may never be reached for some address pairs.
- `RuleWhitelistWrapper` does not ERC-165-check its child rules (unlike `RuleEngineBase._checkRule`); a non-`IAddressList` child bricks the scan.
- `RuleChainlinkPoR` reads the feed's `decimals()` **live on every check** and deliberately does NOT cache it. Caching saves ~2,900 gas per mint but lets an aggregator migration that changes decimals mis-scale the reserves by `10 ** delta` with no on-chain signal — in the overstating direction that is unlimited unbacked minting. Both feed calls share the `code.length` guard (Solidity's extcodesize revert on a `try` to a codeless address is uncatchable) and `MAX_FEED_DECIMALS` is re-checked at read time, not just at configuration. Do not "optimise" this back into a cache.
- `RuleChainlinkPoR` (and `RuleMaxTotalSupply`) protect **one token per instance** with no on-chain guard: they read `totalSupply()` from the configured `tokenContract`, never from the token that triggered the check, and behind a RuleEngine they cannot learn that identity. One instance added to two RuleEngines evaluates both tokens against the first one's supply and feed — silently over-minting or freezing the second. Chainlink's `SecureMintPolicy` blocks this with `onInstall`/`PolicyAlreadyBound`; adding an equivalent here would mean making a stateless validation rule bindable, which is a library-wide decision. Documented, not fixed.
- `ADDRESS_LIST_ADD_ROLE` / `ADDRESS_LIST_REMOVE_ROLE` live in `RuleAddressSetRolesStorage`, inherited by `RuleAddressSet` (the public layer that enforces them) — **not** by `RuleAddressSetInternal`. Do not move them back into `RuleAddressSetInvariantStorage`: a contract reusing only the internal layer (`IdentityRegistryWhitelist`) would then publish two roles it never checks, and an operator granting one would get no privilege and no signal.
- `RuleChainlinkPoR` and `RuleMaxTotalSupply` both guard `tokenContract.totalSupply()` with a code-length check plus `try/catch`, returning a restriction code (78 and 51 respectively) rather than reverting, and both validate the token at configuration (non-zero, has code, `totalSupply()` callable). The shared mechanics — the revert-free read and the configuration probe — live in `TokenSupplyReader`; each rule supplies its own token via the `_supplyToken()` hook (so the base holds **no storage** and cannot reorder any rule's slots) and raises its own named errors. Do not move the `require`s into the base: three distinct configuration failures deliberately keep three distinct per-rule errors. The ERC-1404 views MUST NOT revert — never call `totalSupply()` unguarded on a read path. Neither rule re-checks `code.length` at read time: `try/catch` cannot catch a call to a codeless address (the ABI decoder fails in the caller's frame, outside `catch`'s reach -- **not** `EXTCODESIZE`, which solc >= 0.8.10 skips when return data is expected), but the setters require code and EIP-6780 (Cancun) makes that permanent, so the check would be unreachable. This is a **deployment precondition** (Cancun or later, `foundry.toml` targets `prague`), documented in each rule doc rather than enforced at runtime — do not re-add the guard unless targeting a pre-Cancun chain. `decimals()` stays optional on the token; `totalSupply()` is mandatory. The two rules use *different* constant names for the same idea (`CODE_TOTAL_SUPPLY_UNAVAILABLE` vs `CODE_SUPPLY_ORACLE_UNAVAILABLE`) because `HelperContract` inherits both invariant-storage contracts and identical identifiers would clash.
- **The three cap rules (`RuleMaxBalance`, `RuleMaxTotalSupply`, `RuleChainlinkPoR`) assume the token notifies BEFORE it moves the value**, so the observation still excludes it. CMTAT does; ERC-3643 / T-REX does **not** (`Token.transfer` runs `_transfer` then `transferred`; `mint` runs `_mint` then `created`), and on such a token the stock rule counts the value twice and halves the effective cap (NM-11). Adapting is one override of `_detectTransferRestrictionOnNotify`, the hook the **write** path enforces through: `return _detectTransferRestriction(from, to, 0)`. **Do not route the read path through it** — a pre-flight view always runs before the movement on either kind of token, so it must always project the value; re-phasing it makes the pre-flight answer disagree with enforcement, which is the mirror image of the bug. The shared comparison lives in `CapAccounting`, which is stateless and deliberately holds no accounting-phase flag for exactly this reason. Second seam: `_currentSupply` / `_balanceOf` are `internal view virtual`, so a rule may serve the figure from its own storage — viable for *supply*, **not** for per-address balances, because `Token.recoveryAddress` notifies compliance on T-REX <= 4.1 (via the public `forcedTransfer`) but not on the vendored 4.2.0-beta1 (direct `_transfer`), so a shadow ledger's correctness would hinge on the token's minor version. See `doc/technical/guides/RULE_SEMANTICS.md` §5.
- `RuleChainlinkPoR` accepts `tokenDecimals == 0`. Chainlink's `SecureMintPolicy` requires 1–18, but CMTAT equity tokens report 0 decimals, so the lower bound was dropped. Do not re-add it.
