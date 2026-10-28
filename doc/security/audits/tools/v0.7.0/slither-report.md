# Slither Report — `v0.7.0`

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.7.0/slither-report.md
```

Tool: **Slither 0.11.6** (latest release; run through `uvx --from slither-analyzer==0.11.6`) · Compiler: solc `0.8.38`, EVM `osaka`
· Run date: **2026-10-28** (pre-release re-run; the first run, 2026-10-26 at solc `0.8.36`, is superseded)
Scope: production contracts only — **mocks excluded**, vendored dependencies (including the test-only
`lib/CMTATv3.0.0`) excluded via the `lib` filter. 232 contracts, 102 detectors, **47 results**.

**0 High\* · 2 High-impact (both false positives) · 5 Medium · 18 Low · 22 Informational.**

| Detector | Impact | Instances | Assessment |
|---|---|---|---|
| `arbitrary-send-erc20` | High | 2 | **False positive** — `approveAndTransferIfAllowed`, gated by `onlyTransferApprover`, a recorded approval, an allowance check and a bound token. |
| `uninitialized-local` | Medium | 2 | False positive — assigned inside a `try` whose `catch` returns or reverts |
| `unused-return` | Medium | 3 | False positive — configuration probes and an oracle read whose discarded values are the point |
| `calls-loop` | Low | 17 | By design — the wrapper's bounded child scan and its `_checkRule` guard |
| `timestamp` | Low | 1 | By design — the Proof-of-Reserve staleness comparison *is* the feature |
| `assembly` | Informational | 2 | By design — the documented `_transferHash` preimage |
| `dead-code` | Informational | 10 | False positive — all ten are reached through virtual dispatch (ERC-2771 `_contextSuffixLength`, the `_afterMintChecked` hook, the zero-address guards) |
| `naming-convention` | Informational | 6 | By design — spec-aligned parameter names |
| `unused-state` | Informational | 4 | Cosmetic — the four `TRANSFERRED_SELECTOR_*` constants are genuinely unreferenced |

\* Slither has no "High severity" column as such; the two `arbitrary-send-erc20` results carry High *impact*
and are verified false positives.

**Nothing to fix.** No finding is exploitable. One result more than the first run (46 → 47): `dead-code` on
`RuleIssuanceCapBase._remainingMintable()`, an override reached through virtual dispatch from
`RuleMaxTotalSupplyBase.remainingMintable()`. The 0.11.5 comparison run on the first run's code is kept as
[`slither-report-0.11.5.md`](./slither-report-0.11.5.md).

**Blind spot, both versions:** Slither cannot build IR for `_addAddresses` / `_removeAddresses` in `RuleMaxBalance`
and `IdentityRegistryWhitelist` (a function pointer passed to `AddressSetBatchLib`), so no detector analyses those
two copies. The same inherited code is analysed in the other address-set rules. See the feedback file.

Triage: [`slither-report-feedback.md`](./slither-report-feedback.md) · Overview: [`AUDIT_OVERVIEW.md`](../../AUDIT_OVERVIEW.md)

---

Multiple frameworks detected: Foundry, Hardhat. Using Foundry (highest priority). Use --compile-force-framework to override.
'forge clean' running (wd: /home/ryan/Pictures/dev/Rules)
'forge config --json' running
'forge build --build-info --deny never --skip ./test/** ./script/** --force' running (wd: /home/ryan/Pictures/dev/Rules)
**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [arbitrary-send-erc20](#arbitrary-send-erc20) (2 results) (High)
 - [uninitialized-local](#uninitialized-local) (2 results) (Medium)
 - [unused-return](#unused-return) (3 results) (Medium)
 - [calls-loop](#calls-loop) (17 results) (Low)
 - [timestamp](#timestamp) (1 results) (Low)
 - [assembly](#assembly) (2 results) (Informational)
 - [dead-code](#dead-code) (10 results) (Informational)
 - [naming-convention](#naming-convention) (6 results) (Informational)
 - [unused-state](#unused-state) (4 results) (Informational)
## arbitrary-send-erc20
Impact: High
Confidence: High
 - [ ] ID-0
[RuleConditionalTransferLightBase.approveAndTransferIfAllowed(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L125-L151) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L140)

src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L125-L151


 - [ ] ID-1
[RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L139-L165) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L155)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L139-L165


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-2
[ChainlinkPoRFeedManager._maxBackedSupply().currentFeedDecimals](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L199) is a local variable never initialized

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L199


 - [ ] ID-3
[ChainlinkPoRFeedManager._setReservesFeed(AggregatorV3Interface).newFeedDecimals](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L130) is a local variable never initialized

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L130


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-4
[TokenSupplyReader._probeTotalSupplyCallable(address)](src/rules/validation/abstract/core/TokenSupplyReader.sol#L65-L71) ignores return value by [ITotalSupply(candidate).totalSupply()](src/rules/validation/abstract/core/TokenSupplyReader.sol#L66-L70)

src/rules/validation/abstract/core/TokenSupplyReader.sol#L65-L71


 - [ ] ID-5
[BalanceCapManager._setBalanceToken(address)](src/rules/validation/abstract/core/BalanceCapManager.sol#L177-L192) ignores return value by [IBalanceOf(newBalanceToken).balanceOf(address(this))](src/rules/validation/abstract/core/BalanceCapManager.sol#L182-L189)

src/rules/validation/abstract/core/BalanceCapManager.sol#L177-L192


 - [ ] ID-6
[ChainlinkPoRFeedManager._maxBackedSupply()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L195-L231) ignores return value by [(answer,updatedAt) = feed.latestRoundData()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L210-L230)

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L195-L231


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-7
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-8
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestriction(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-9
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransferFrom(address,address,address,uint256,uint256)
		RuleNFTAdapter.detectTransferRestrictionFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-10
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-11
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.MultiTokenTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-12
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleWhitelistWrapperHarnessInternal.exposedTransferredSpenderInternal(address,address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-13
[RuleWhitelistWrapperBase._checkRule(address)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L240-L253) has external calls inside a loop: [require(bool,error)(IAddressListPolarity(rule_).isAllowList(),revert RuleWhitelistWrapper_ChildIsNotAnAllowList(address)(rule_))](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L252)
	Calls stack containing the loop:
		RulesManagementModule.setRules(IRule[])
		RulesManagementModule._addRule(IRule)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L240-L253


 - [ ] ID-14
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestrictionFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-15
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-16
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleTransferValidation.canTransfer(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-17
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-18
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransfer(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-19
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleWhitelistWrapperBase.isVerified(address)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-20
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,address,uint256,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-21
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleTransferValidation.canTransferFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-22
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


 - [ ] ID-23
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L276)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.FungibleTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L290


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-24
[ChainlinkPoRFeedManager._maxBackedSupply()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L195-L231) uses timestamp for comparisons
	Dangerous comparisons:
	- [answer < 0 || updatedAt == 0 || updatedAt > block.timestamp](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L216)
	- [staleness != 0 && block.timestamp - updatedAt > staleness](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L221)

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L195-L231


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-25
[RuleConditionalTransferLightApprovalBase._transferHash(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L162-L174) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L167-L173)

src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L162-L174


 - [ ] ID-26
[RuleConditionalTransferLightMultiTokenBase._transferHash(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L468-L482) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L474-L481)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L468-L482


## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-27
[RuleWhitelist._contextSuffixLength()](src/rules/validation/deployment/RuleWhitelist.sol#L106-L108) is never used and should be removed

src/rules/validation/deployment/RuleWhitelist.sol#L106-L108


 - [ ] ID-28
[RuleERC2980Internal._requireNotZeroAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L142-L144) is never used and should be removed

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L142-L144


 - [ ] ID-29
[RuleBlacklist._contextSuffixLength()](src/rules/validation/deployment/RuleBlacklist.sol#L86-L88) is never used and should be removed

src/rules/validation/deployment/RuleBlacklist.sol#L86-L88


 - [ ] ID-30
[RuleBlacklistOwnable2Step._contextSuffixLength()](src/rules/validation/deployment/RuleBlacklistOwnable2Step.sol#L85-L87) is never used and should be removed

src/rules/validation/deployment/RuleBlacklistOwnable2Step.sol#L85-L87


 - [ ] ID-31
[RuleERC2980._contextSuffixLength()](src/rules/validation/deployment/RuleERC2980.sol#L109-L111) is never used and should be removed

src/rules/validation/deployment/RuleERC2980.sol#L109-L111


 - [ ] ID-32
[RuleERC2980Ownable2Step._contextSuffixLength()](src/rules/validation/deployment/RuleERC2980Ownable2Step.sol#L102-L104) is never used and should be removed

src/rules/validation/deployment/RuleERC2980Ownable2Step.sol#L102-L104


 - [ ] ID-33
[RuleIssuanceCapBase._remainingMintable()](src/rules/operation/abstract/RuleIssuanceCapBase.sol#L185-L194) is never used and should be removed

src/rules/operation/abstract/RuleIssuanceCapBase.sol#L185-L194


 - [ ] ID-34
[RuleWhitelistOwnable2Step._contextSuffixLength()](src/rules/validation/deployment/RuleWhitelistOwnable2Step.sol#L99-L101) is never used and should be removed

src/rules/validation/deployment/RuleWhitelistOwnable2Step.sol#L99-L101


 - [ ] ID-35
[RuleIssuanceCapBase._afterMintChecked(uint256)](src/rules/operation/abstract/RuleIssuanceCapBase.sol#L167-L180) is never used and should be removed

src/rules/operation/abstract/RuleIssuanceCapBase.sol#L167-L180


 - [ ] ID-36
[RuleAddressSetInternal._requireNotZeroAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L64-L66) is never used and should be removed

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L64-L66


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-37
Parameter [RuleERC2980Base.frozenlist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L368) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L368


 - [ ] ID-38
Parameter [IdentityRegistryWhitelistBase.isVerified(address)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L92) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L92


 - [ ] ID-39
Parameter [IdentityRegistryWhitelistBase.deleteIdentity(address)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L67) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L67


 - [ ] ID-40
Parameter [RuleERC2980Base.whitelist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L319) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L319


 - [ ] ID-41
Parameter [IdentityRegistryWhitelistBase.registerIdentity(address,address,uint16)._identity](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L48) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L48


 - [ ] ID-42
Parameter [IdentityRegistryWhitelistBase.registerIdentity(address,address,uint16)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L47) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L47


## unused-state
Impact: Informational
Confidence: High
 - [ ] ID-43
[RuleNFTAdapter.TRANSFERRED_SELECTOR_RULE_ENGINE](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L37) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L37


 - [ ] ID-44
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L41-L42) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L41-L42


 - [ ] ID-45
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943_FROM](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L46-L47) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L46-L47


 - [ ] ID-46
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC3643](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L33) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L33


