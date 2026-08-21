# Slither Report — `v0.6.0`

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.6.0/slither-report.md
```

Tool: **Slither 0.11.5** · Compiler: solc `0.8.36` · Run date: **2026-08-21** (re-run after the RuleEngine
`v3.0.0-rc6` bump; supersedes the 2026-08-18 run)
Scope: production contracts only — **mocks excluded**, vendored dependencies excluded via the `lib` filter.
225 contracts, 101 detectors, **46 results**.

**0 High\* · 2 High-impact (both false positives) · 11 Medium · 18 Low · 15 Informational.**

| Detector | Impact | Instances | Assessment |
|---|---|---|---|
| `arbitrary-send-erc20` | High | 2 | **False positive** — `approveAndTransferIfAllowed` is gated by `onlyTransferApprover`, a recorded approval, an allowance check and a bound token |
| `uninitialized-local` | Medium | 2 | False positive — assigned inside a `try` whose `catch` returns or reverts |
| `unused-return` | Medium | 9 | False positive — `EnumerableSet` return values deliberately discarded, or configuration probes whose discarded value is the point |
| `calls-loop` | Low | 17 | By design — the wrapper's bounded child scan and its `_checkRule` guard |
| `timestamp` | Low | 1 | By design — the Proof-of-Reserve staleness comparison *is* the feature |
| `assembly` | Informational | 2 | By design — the documented `_transferHash` preimage |
| `dead-code` | Informational | 3 | False positive — all three are reachable; see the feedback file |
| `naming-convention` | Informational | 6 | By design — spec-aligned parameter names |
| `unused-state` | Informational | 4 | Cosmetic — the four `TRANSFERRED_SELECTOR_*` constants are genuinely unreferenced |

\* Slither has no "High severity" column as such; the two `arbitrary-send-erc20` results carry High *impact*
and are verified false positives.

**Nothing to fix.** No finding is exploitable. The delta from `v0.5.0` is **+2** (44 → 46), both traceable to
code added in this release and both dismissed against the source.

**Re-run delta (2026-08-18 → 2026-08-21): no detector moved.** Every one of the nine detectors holds its exact
result count; the entire diff is **line numbers in three files** (`RuleConditionalTransferLightBase`,
`RuleConditionalTransferLightMultiTokenBase`, `RuleChainlinkPoRBase`). The contract count rose **221 → 225**,
which is not this repository's code: RuleEngine `v3.0.0-rc6` split the binding registry out of
`ERC3643ComplianceModule`, adding `TokenBindingModule`, `TokenBindingExtendedModule`, `ITokenBinding`,
`ITokenBindingExtended` and `TokenBindingModuleInvariantStorage` while removing
`ERC3643ComplianceModuleInvariantStorage` — net +4 contracts in the inheritance graph Slither walks, all of
them filtered out of the results by the `lib` path filter.

Triage: [`slither-report-feedback.md`](./slither-report-feedback.md) ·
Overview: [`AUDIT_OVERVIEW.md`](../../AUDIT_OVERVIEW.md)

---

**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [arbitrary-send-erc20](#arbitrary-send-erc20) (2 results) (High)
 - [uninitialized-local](#uninitialized-local) (2 results) (Medium)
 - [unused-return](#unused-return) (9 results) (Medium)
 - [calls-loop](#calls-loop) (17 results) (Low)
 - [timestamp](#timestamp) (1 results) (Low)
 - [assembly](#assembly) (2 results) (Informational)
 - [dead-code](#dead-code) (3 results) (Informational)
 - [naming-convention](#naming-convention) (6 results) (Informational)
 - [unused-state](#unused-state) (4 results) (Informational)
## arbitrary-send-erc20
Impact: High
Confidence: High
 - [ ] ID-0
[RuleConditionalTransferLightBase.approveAndTransferIfAllowed(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L115-L141) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L130)

src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L115-L141


 - [ ] ID-1
[RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L131-L157) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L147)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L131-L157


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
[RuleERC2980Internal._removeFrozenlistAddresses(address[])](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L110-L116) ignores return value by [_frozenlist.removeBatch(addressesToRemove)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L115)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L110-L116


 - [ ] ID-5
[BalanceCapManager._setBalanceToken(address)](src/rules/validation/abstract/core/BalanceCapManager.sol#L176-L189) ignores return value by [IBalanceOf(newBalanceToken).balanceOf(address(this))](src/rules/validation/abstract/core/BalanceCapManager.sol#L181-L186)

src/rules/validation/abstract/core/BalanceCapManager.sol#L176-L189


 - [ ] ID-6
[RuleAddressSetInternal._removeAddresses(address[])](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L77-L83) ignores return value by [_listedAddresses.removeBatch(addressesToRemove)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L82)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L77-L83


 - [ ] ID-7
[RuleERC2980Internal._removeWhitelistAddresses(address[])](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L61-L67) ignores return value by [_whitelist.removeBatch(addressesToRemove)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L66)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L61-L67


 - [ ] ID-8
[RuleERC2980Internal._addWhitelistAddresses(address[])](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L47-L53) ignores return value by [_whitelist.addBatch(addressesToAdd,_requireNotZeroAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L52)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L47-L53


 - [ ] ID-9
[RuleERC2980Internal._addFrozenlistAddresses(address[])](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L96-L102) ignores return value by [_frozenlist.addBatch(addressesToAdd,_requireNotZeroAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L101)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L96-L102


 - [ ] ID-10
[RuleAddressSetInternal._addAddresses(address[])](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L44-L50) ignores return value by [_listedAddresses.addBatch(addressesToAdd,_requireNotZeroAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L49)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L44-L50


 - [ ] ID-11
[TokenSupplyReader._probeTotalSupplyCallable(address)](src/rules/validation/abstract/core/TokenSupplyReader.sol#L65-L71) ignores return value by [ITotalSupply(candidate).totalSupply()](src/rules/validation/abstract/core/TokenSupplyReader.sol#L66-L70)

src/rules/validation/abstract/core/TokenSupplyReader.sol#L65-L71


 - [ ] ID-12
[ChainlinkPoRFeedManager._maxBackedSupply()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L195-L231) ignores return value by [(answer,updatedAt) = feed.latestRoundData()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L210-L230)

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L195-L231


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-13
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleWhitelistWrapperHarnessInternal.exposedTransferredSpenderInternal(address,address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-14
[RuleWhitelistWrapperBase._checkRule(address)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L243-L256) has external calls inside a loop: [require(bool,error)(IAddressListPolarity(rule_).isAllowList(),revert RuleWhitelistWrapper_ChildIsNotAnAllowList(address)(rule_))](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L255)
	Calls stack containing the loop:
		RulesManagementModule.setRules(IRule[])
		RulesManagementModule._addRule(IRule)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L243-L256


 - [ ] ID-15
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestriction(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-16
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestrictionFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-17
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-18
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransfer(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-19
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.FungibleTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-20
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleWhitelistWrapperBase.isVerified(address)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-21
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.MultiTokenTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-22
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-23
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,address,uint256,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-24
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleTransferValidation.canTransferFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-25
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-26
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-27
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransferFrom(address,address,address,uint256,uint256)
		RuleNFTAdapter.detectTransferRestrictionFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-28
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleTransferValidation.canTransfer(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


 - [ ] ID-29
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293) has external calls inside a loop: [isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L279)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L263-L293


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-30
[ChainlinkPoRFeedManager._maxBackedSupply()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L195-L231) uses timestamp for comparisons
	Dangerous comparisons:
	- [answer < 0 || updatedAt == 0 || updatedAt > block.timestamp](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L216)
	- [staleness != 0 && block.timestamp - updatedAt > staleness](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L221)

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L195-L231


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-31
[RuleConditionalTransferLightApprovalBase._transferHash(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L163-L174) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L167-L173)

src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L163-L174


 - [ ] ID-32
[RuleConditionalTransferLightMultiTokenBase._transferHash(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L450-L464) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L456-L463)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L450-L464


## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-33
[RuleERC2980Internal._requireNotZeroAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L142-L144) is never used and should be removed

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L142-L144


 - [ ] ID-34
[RuleChainlinkPoRBase._detectTransferRestrictionOnNotify(address,address,uint256)](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L175-L182) is never used and should be removed

src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L175-L182


 - [ ] ID-35
[RuleAddressSetInternal._requireNotZeroAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L64-L66) is never used and should be removed

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L64-L66


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-36
Parameter [RuleERC2980Base.frozenlist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L374) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L374


 - [ ] ID-37
Parameter [IdentityRegistryWhitelistBase.isVerified(address)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L92) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L92


 - [ ] ID-38
Parameter [IdentityRegistryWhitelistBase.deleteIdentity(address)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L67) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L67


 - [ ] ID-39
Parameter [RuleERC2980Base.whitelist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L325) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L325


 - [ ] ID-40
Parameter [IdentityRegistryWhitelistBase.registerIdentity(address,address,uint16)._identity](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L48) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L48


 - [ ] ID-41
Parameter [IdentityRegistryWhitelistBase.registerIdentity(address,address,uint16)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L47) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L47


## unused-state
Impact: Informational
Confidence: High
 - [ ] ID-42
[RuleNFTAdapter.TRANSFERRED_SELECTOR_RULE_ENGINE](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L37) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L37


 - [ ] ID-43
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L41-L42) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L41-L42


 - [ ] ID-44
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943_FROM](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L46-L47) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L46-L47


 - [ ] ID-45
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC3643](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L33) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L33


