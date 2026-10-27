## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/core/TotalSupplyCapManager.sol | 2480d5c2b67486b18690c6dd41b0a66aab5b1d13 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **TotalSupplyCapManager** | Implementation | CapAccounting, TokenSupplyReader, RuleMaxTotalSupplyInvariantStorage |||
| └ | setMaxTotalSupply | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | increaseMaxTotalSupply | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | decreaseMaxTotalSupply | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | setTokenContract | Public ❗️ | 🛑  | onlyTokenContractManager |
| └ | _setMaxTotalSupply | Internal 🔒 | 🛑  | |
| └ | _setTokenContract | Internal 🔒 | 🛑  | |
| └ | _validateTokenContract | Internal 🔒 |   | |
| └ | _authorizeMaxTotalSupplyManager | Internal 🔒 |   | |
| └ | _authorizeTokenContractManager | Internal 🔒 |   | |
| └ | _supplyToken | Internal 🔒 |   | |
| └ | _capExceeded | Internal 🔒 |   | |
| └ | _remainingMintable | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
