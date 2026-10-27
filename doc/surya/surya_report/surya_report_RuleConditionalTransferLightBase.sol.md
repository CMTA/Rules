## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleConditionalTransferLightBase.sol | 371cd65d61dffbc82129e3c9d6912802628ce81c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleConditionalTransferLightBase** | Implementation | VersionModule, ERC3643ComplianceModule, RuleConditionalTransferLightApprovalBase, IRuleEngineERC1404, IRule |||
| └ | created | External ❗️ | 🛑  | onlyBoundToken |
| └ | destroyed | External ❗️ | 🛑  | onlyBoundToken |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | External ❗️ |   |NO❗️ |
| └ | approveAndTransferIfAllowed | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | transferred | Public ❗️ | 🛑  | onlyTransferExecutor |
| └ | transferred | Public ❗️ | 🛑  | onlyTransferExecutor |
| └ | bindToken | Public ❗️ | 🛑  | onlyTokenBindingManager |
| └ | bindRuleEngine | Public ❗️ | 🛑  | onlyTokenBindingManager |
| └ | unbindRuleEngine | Public ❗️ | 🛑  | onlyTokenBindingManager |
| └ | isTransferExecutor | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestrictionFrom | Public ❗️ |   |NO❗️ |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | canTransferFrom | Public ❗️ |   |NO❗️ |
| └ | _ruleNotBound | Internal 🔒 |   | |
| └ | _authorizeTransferExecution | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
