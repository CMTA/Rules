## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./mocks/harness/ERC3643CapHarnesses.sol | e73b331535951bf8e3c87a1b8bd32d7d2f8a9980 |


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
