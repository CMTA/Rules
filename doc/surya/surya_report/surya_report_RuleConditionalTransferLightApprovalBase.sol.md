## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol | 147867677947edf0d0a36476e65fcdad28502e08 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleConditionalTransferLightApprovalBase** | Implementation | RuleConditionalTransferLightInvariantStorage |||
| └ | transferred | External ❗️ | 🛑  | onlyTransferExecutor |
| └ | approveTransfer | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | cancelTransferApproval | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | resetApproval | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | approvedCount | Public ❗️ |   |NO❗️ |
| └ | _transferredFromContext | Internal 🔒 | 🛑  | |
| └ | _transferred | Internal 🔒 | 🛑  | |
| └ | _transferHash | Internal 🔒 |   | |
| └ | _authorizeTransferApproval | Internal 🔒 |   | |
| └ | _authorizeTransferExecution | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
