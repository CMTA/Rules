## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleIssuanceCapBase.sol | a70b9c4df97ddf7b95a82eeaf25268338ea3c81e |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleIssuanceCapBase** | Implementation | RuleMaxTotalSupplyBase, ERC3643ComplianceModule, RuleIssuanceCapInvariantStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleMaxTotalSupplyBase |
| └ | created | External ❗️ | 🛑  | onlyBoundToken |
| └ | destroyed | External ❗️ | 🛑  | onlyBoundToken |
| └ | bindToken | Public ❗️ | 🛑  | onlyTokenBindingManager |
| └ | transferred | Public ❗️ | 🛑  | onlyBoundToken |
| └ | transferred | Public ❗️ | 🛑  | onlyBoundToken |
| └ | canReturnTransferRestrictionCode | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | _detectTransferRestriction | Internal 🔒 |   | |
| └ | _afterMintChecked | Internal 🔒 | 🛑  | |
| └ | _remainingMintable | Internal 🔒 |   | |
| └ | remainingMintable | Public ❗️ |   |NO❗️ |
| └ | _ruleNotBound | Internal 🔒 |   | |
| └ | _issuanceExceededBy | Internal 🔒 |   | |
| └ | _authorizeTokenContractManager | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
