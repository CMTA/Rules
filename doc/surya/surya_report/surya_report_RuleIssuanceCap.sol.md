## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/RuleIssuanceCap.sol | bef972bbd26e582ffa38013cd72acb2eda97a3cf |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleIssuanceCap** | Implementation | AccessControlModuleStandalone, RuleIssuanceCapBase, ERC3643ComplianceRolesStorage, RuleMaxTotalSupplyRolesStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | AccessControlModuleStandalone RuleIssuanceCapBase |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeMaxTotalSupplyManager | Internal 🔒 |   | onlyRole |
| └ | _onlyComplianceManager | Internal 🔒 |   | onlyRole |
| └ | _authorizeTokenBindingChange | Internal 🔒 |   | onlyRole |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
