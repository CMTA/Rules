## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleMaxTotalSupply.sol | 7ca5131c6986506adfb4f6494700b68f3bb1765c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMaxTotalSupply** | Implementation | AccessControlModuleStandalone, RuleMaxTotalSupplyBase, RuleMaxTotalSupplyRolesStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | AccessControlModuleStandalone RuleMaxTotalSupplyBase |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeMaxTotalSupplyManager | Internal 🔒 |   | onlyRole |
| └ | _authorizeTokenContractManager | Internal 🔒 |   | onlyRole |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
