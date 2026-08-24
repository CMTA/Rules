## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleConditionalTransferLightBase.sol | d69293485b40c9f6bd53bb0b7cce2e86938939c2 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleConditionalTransferLightBase** | Implementation | VersionModule, ERC3643ComplianceModule, RuleConditionalTransferLightApprovalBase, IRule |||
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
| └ | _authorizeTransferExecution | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
