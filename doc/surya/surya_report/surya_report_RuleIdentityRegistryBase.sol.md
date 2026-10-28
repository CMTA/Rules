## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/base/RuleIdentityRegistryBase.sol | 6c0505a1fe8008319e8943ad802c5898a10f1f0d |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleIdentityRegistryBase** | Implementation | RuleNFTAdapter, RuleIdentityRegistryInvariantStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | setIdentityRegistry | Public ❗️ | 🛑  | onlyIdentityRegistryManager |
| └ | setCheckSender | Public ❗️ | 🛑  | onlyIdentityRegistryManager |
| └ | setCheckSpender | Public ❗️ | 🛑  | onlyIdentityRegistryManager |
| └ | clearIdentityRegistry | Public ❗️ | 🛑  | onlyIdentityRegistryManager |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | _authorizeIdentityRegistryManager | Internal 🔒 |   | |
| └ | _detectTransferRestriction | Internal 🔒 |   | |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 |   | |
| └ | _transferredFrom | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
