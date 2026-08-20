## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleConditionalTransferLightBase.sol | 3af5272b60151e4954fb35bc7e7605f78548e375 |


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
| └ | bindToken | Public ❗️ | 🛑  | onlyComplianceManager |
| └ | bindRuleEngine | Public ❗️ | 🛑  | onlyComplianceManager |
| └ | unbindRuleEngine | Public ❗️ | 🛑  | onlyComplianceManager |
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
