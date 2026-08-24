## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/core/TotalSupplyCapManager.sol | 4b3c48fb12e49a65c1a2ddb3998a5fd7d2cb3b37 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **TotalSupplyCapManager** | Implementation | CapAccounting, TokenSupplyReader, RuleMaxTotalSupplyInvariantStorage |||
| └ | setMaxTotalSupply | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | setTokenContract | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | _setMaxTotalSupply | Internal 🔒 | 🛑  | |
| └ | _setTokenContract | Internal 🔒 | 🛑  | |
| └ | _validateTokenContract | Internal 🔒 |   | |
| └ | _authorizeMaxTotalSupplyManager | Internal 🔒 |   | |
| └ | _supplyToken | Internal 🔒 |   | |
| └ | _capExceeded | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
