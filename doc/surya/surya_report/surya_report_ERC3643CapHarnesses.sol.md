## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./mocks/harness/ERC3643CapHarnesses.sol | 1ee6bd8daa637884f5fb5a851f708640f146d380 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **ERC3643MaxTotalSupplyHarness** | Implementation | RuleMaxTotalSupply |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleMaxTotalSupply |
| └ | _detectTransferRestrictionOnNotify | Internal 🔒 |   | |
||||||
| **ERC3643MaxBalanceHarness** | Implementation | RuleMaxBalance |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleMaxBalance |
| └ | _detectTransferRestrictionOnNotify | Internal 🔒 |   | |
||||||
| **ERC3643ChainlinkPoRHarness** | Implementation | RuleChainlinkPoR |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleChainlinkPoR |
| └ | _detectTransferRestrictionOnNotify | Internal 🔒 |   | |
||||||
| **TrackedSupplyHarness** | Implementation | RuleMaxTotalSupply |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleMaxTotalSupply |
| └ | setTrackedSupply | External ❗️ | 🛑  |NO❗️ |
| └ | _currentSupply | Internal 🔒 |   | |
| └ | _supplyToken | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
