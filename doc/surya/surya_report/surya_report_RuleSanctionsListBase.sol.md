## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/base/RuleSanctionsListBase.sol | 7be04d4946d46170d0bc0e31d815d8398cead12a |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleSanctionsListBase** | Implementation | MetaTxModuleStandalone, RuleNFTAdapter, RuleSanctionsListInvariantStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | MetaTxModuleStandalone |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | setSanctionListOracle | Public ❗️ | 🛑  | onlySanctionListManager |
| └ | clearSanctionListOracle | Public ❗️ | 🛑  | onlySanctionListManager |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | _setSanctionListOracle | Internal 🔒 | 🛑  | |
| └ | _authorizeSanctionListManager | Internal 🔒 |   | |
| └ | _detectTransferRestriction | Internal 🔒 |   | |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 |   | |
| └ | _transferredFrom | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
