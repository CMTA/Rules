**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [unused-return](#unused-return) (4 results) (Medium)
 - [dead-code](#dead-code) (3 results) (Informational)
 - [solc-version](#solc-version) (1 results) (Informational)
 - [naming-convention](#naming-convention) (2 results) (Informational)
 - [constable-states](#constable-states) (1 results) (Optimization)
 - [var-read-using-this](#var-read-using-this) (9 results) (Optimization)
## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-0
[RuleAddressSetInternal._addAddresses(address[])](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L36-L40) ignores return value by [_listedAddresses.add(addressesToAdd[i])](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L38)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L36-L40


 - [ ] ID-1
[RuleAddressSetInternal._addAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L59-L61) ignores return value by [_listedAddresses.add(targetAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L60)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L59-L61


 - [ ] ID-2
[RuleAddressSetInternal._removeAddresses(address[])](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L49-L53) ignores return value by [_listedAddresses.remove(addressesToRemove[i])](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L51)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L49-L53


 - [ ] ID-3
[RuleAddressSetInternal._removeAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L67-L69) ignores return value by [_listedAddresses.remove(targetAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L68)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L67-L69


## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-4
[RuleAddressSet._msgData()](src/rules/validation/abstract/RuleAddressSet/RuleAddressSet.sol#L157-L159) is never used and should be removed

src/rules/validation/abstract/RuleAddressSet/RuleAddressSet.sol#L157-L159


 - [ ] ID-5
[RuleSanctionsList._msgData()](src/rules/validation/RuleSanctionsList.sol#L254-L256) is never used and should be removed

src/rules/validation/RuleSanctionsList.sol#L254-L256


 - [ ] ID-6
[RuleWhitelistWrapper._msgData()](src/rules/validation/RuleWhitelistWrapper.sol#L215-L217) is never used and should be removed

src/rules/validation/RuleWhitelistWrapper.sol#L215-L217


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-7
Version constraint ^0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- DataLocationChangeInInternalOverride
	- NestedCalldataArrayAbiReencodingSizeValidation
	- SignedImmutables
	- ABIDecodeTwoDimensionalArrayMemory
	- KeccakCaching.
It is used by:
	- [^0.8.0](src/rules/interfaces/IAddressList.sol#L2)

src/rules/interfaces/IAddressList.sol#L2


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-8
Parameter [RuleBlacklist.canReturnTransferRestrictionCode(uint8)._restrictionCode](src/rules/validation/RuleBlacklist.sol#L103) is not in mixedCase

src/rules/validation/RuleBlacklist.sol#L103


 - [ ] ID-9
Parameter [RuleBlacklist.messageForTransferRestriction(uint8)._restrictionCode](src/rules/validation/RuleBlacklist.sol#L120) is not in mixedCase

src/rules/validation/RuleBlacklist.sol#L120


## constable-states
Impact: Optimization
Confidence: High
 - [ ] ID-10
[RuleAddressSet._listedAddressCountCache](src/rules/validation/abstract/RuleAddressSet/RuleAddressSet.sol#L33) should be constant 

src/rules/validation/abstract/RuleAddressSet/RuleAddressSet.sol#L33


## var-read-using-this
Impact: Optimization
Confidence: High
 - [ ] ID-11
The function [RuleSanctionsList.transferred(address,address,address,uint256)](src/rules/validation/RuleSanctionsList.sol#L201-L212) reads [code = this.detectTransferRestrictionFrom(spender,from,to,value)](src/rules/validation/RuleSanctionsList.sol#L207) with `this` which adds an extra STATICCALL.

src/rules/validation/RuleSanctionsList.sol#L201-L212


 - [ ] ID-12
The function [RuleWhitelistCommon.transferred(address,address,address,uint256)](src/rules/validation/abstract/RuleWhitelistCommon.sol#L97-L103) reads [code = this.detectTransferRestrictionFrom(spender,from,to,value)](src/rules/validation/abstract/RuleWhitelistCommon.sol#L98) with `this` which adds an extra STATICCALL.

src/rules/validation/abstract/RuleWhitelistCommon.sol#L97-L103


 - [ ] ID-13
The function [RuleBlacklist.transferred(address,address,uint256)](src/rules/validation/RuleBlacklist.sol#L144-L155) reads [code = this.detectTransferRestriction(from,to,value)](src/rules/validation/RuleBlacklist.sol#L150) with `this` which adds an extra STATICCALL.

src/rules/validation/RuleBlacklist.sol#L144-L155


 - [ ] ID-14
The function [RuleBlacklist.transferred(address,address,address,uint256)](src/rules/validation/RuleBlacklist.sol#L157-L168) reads [code = this.detectTransferRestrictionFrom(spender,from,to,value)](src/rules/validation/RuleBlacklist.sol#L163) with `this` which adds an extra STATICCALL.

src/rules/validation/RuleBlacklist.sol#L157-L168


 - [ ] ID-15
The function [RuleWhitelistCommon.transferred(address,address,uint256)](src/rules/validation/abstract/RuleWhitelistCommon.sol#L79-L85) reads [code = this.detectTransferRestriction(from,to,value)](src/rules/validation/abstract/RuleWhitelistCommon.sol#L80) with `this` which adds an extra STATICCALL.

src/rules/validation/abstract/RuleWhitelistCommon.sol#L79-L85


 - [ ] ID-16
The function [RuleValidateTransfer.canTransfer(address,address,uint256)](src/rules/validation/abstract/RuleValidateTransfer.sol#L45-L53) reads [this.detectTransferRestriction(from,to,amount) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)](src/rules/validation/abstract/RuleValidateTransfer.sol#L52) with `this` which adds an extra STATICCALL.

src/rules/validation/abstract/RuleValidateTransfer.sol#L45-L53


 - [ ] ID-17
The function [RuleValidateTransfer.canTransferFrom(address,address,address,uint256)](src/rules/validation/abstract/RuleValidateTransfer.sol#L58-L67) reads [this.detectTransferRestrictionFrom(spender,from,to,value) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)](src/rules/validation/abstract/RuleValidateTransfer.sol#L65-L66) with `this` which adds an extra STATICCALL.

src/rules/validation/abstract/RuleValidateTransfer.sol#L58-L67


 - [ ] ID-18
The function [RuleSanctionsList.transferred(address,address,uint256)](src/rules/validation/RuleSanctionsList.sol#L184-L195) reads [code = this.detectTransferRestriction(from,to,value)](src/rules/validation/RuleSanctionsList.sol#L190) with `this` which adds an extra STATICCALL.

src/rules/validation/RuleSanctionsList.sol#L184-L195


 - [ ] ID-19
The function [RuleValidateTransfer.canTransfer(address,address,uint256,uint256)](src/rules/validation/abstract/RuleValidateTransfer.sol#L26-L35) reads [this.detectTransferRestriction(from,to,tokenId,amount) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)](src/rules/validation/abstract/RuleValidateTransfer.sol#L33-L34) with `this` which adds an extra STATICCALL.

src/rules/validation/abstract/RuleValidateTransfer.sol#L26-L35


