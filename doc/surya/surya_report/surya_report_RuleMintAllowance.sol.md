## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/RuleMintAllowance.sol | 5dffbe6960ee9eb1154007dc3f33dba2ae4601e0 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMintAllowance** | Implementation | AccessControlModuleStandalone, RuleMintAllowanceBase, ERC3643ComplianceRolesStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | AccessControlModuleStandalone |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _onlyComplianceManager | Internal 🔒 |   | onlyRole |
| └ | _authorizeSetMintAllowance | Internal 🔒 |   | onlyRole |
| └ | _authorizeTokenBindingChange | Internal 🔒 |   | onlyRole |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
