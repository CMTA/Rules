## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/core/BalanceCapManager.sol | 8d23cbb921630627842b86c40e4941ae4ef676f6 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **BalanceCapManager** | Implementation | CapAccounting, RuleAddressSetInternal, RuleMaxBalanceInvariantStorage |||
| └ | setMaxBalance | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | setBalanceToken | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | addExemptAddress | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | removeExemptAddress | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | addExemptAddresses | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | removeExemptAddresses | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | isExemptAddress | Public ❗️ |   |NO❗️ |
| └ | exemptAddressCount | Public ❗️ |   |NO❗️ |
| └ | _addExemptAddress | Internal 🔒 | 🛑  | |
| └ | _removeExemptAddress | Internal 🔒 | 🛑  | |
| └ | _setMaxBalance | Internal 🔒 | 🛑  | |
| └ | _setBalanceToken | Internal 🔒 | 🛑  | |
| └ | _authorizeMaxBalanceManager | Internal 🔒 |   | |
| └ | _remainingCapacity | Internal 🔒 |   | |
| └ | _balanceOf | Internal 🔒 |   | |
| └ | _capExceeded | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
