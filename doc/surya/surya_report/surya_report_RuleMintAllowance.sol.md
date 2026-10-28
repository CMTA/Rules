## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/RuleMintAllowance.sol | 8a05b53e6191e9abd7d7c1714ea811132db54fb8 |


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
