## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleWhitelistWrapper.sol | 005b5e7c5bf3a40ffbc299c2444f5512e52eb83c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleWhitelistWrapper** | Implementation | RuleWhitelistWrapperBase, AccessControlModuleStandalone, RulesManagementModuleRolesStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleWhitelistWrapperBase AccessControlModuleStandalone |
| └ | hasRole | Public ❗️ |   |NO❗️ |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _grantRole | Internal 🔒 | 🛑  | |
| └ | _revokeRole | Internal 🔒 | 🛑  | |
| └ | _authorizeCheckSpenderManager | Internal 🔒 |   | onlyRole |
| └ | _authorizeMintBurnManager | Internal 🔒 |   | onlyRole |
| └ | _onlyRulesManager | Internal 🔒 |   | onlyRole |
| └ | _onlyRulesLimitManager | Internal 🔒 |   | onlyRole |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
