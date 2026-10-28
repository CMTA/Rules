## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleMaxTotalSupplyOwnable2Step.sol | b6971a040b1d53653a1ddcdde65b464f4d75b164 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMaxTotalSupplyOwnable2Step** | Implementation | RuleMaxTotalSupplyBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleMaxTotalSupplyBase Ownable |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeMaxTotalSupplyManager | Internal 🔒 |   | onlyOwner |
| └ | _authorizeTokenContractManager | Internal 🔒 |   | onlyOwner |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
