## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleMintAllowanceBase.sol | f6bd8256c7e76b1d2ea980fbfd3c2bb7aa1ee453 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMintAllowanceBase** | Implementation | VersionModule, ERC3643ComplianceModule, RuleMintAllowanceInvariantStorage, IRuleEngineERC1404, IRule |||
| └ | created | External ❗️ | 🛑  | onlyBoundToken |
| └ | destroyed | External ❗️ | 🛑  | onlyBoundToken |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | setMintAllowance | Public ❗️ | 🛑  | onlyAllowanceOperator |
| └ | increaseMintAllowance | Public ❗️ | 🛑  | onlyAllowanceOperator |
| └ | decreaseMintAllowance | Public ❗️ | 🛑  | onlyAllowanceOperator |
| └ | clearMintAllowances | Public ❗️ | 🛑  | onlyAllowanceOperator |
| └ | bindToken | Public ❗️ | 🛑  | onlyTokenBindingManager |
| └ | transferred | Public ❗️ | 🛑  | onlyBoundToken |
| └ | transferred | Public ❗️ | 🛑  | onlyBoundToken |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestrictionFrom | Public ❗️ |   |NO❗️ |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | canTransferFrom | Public ❗️ |   |NO❗️ |
| └ | _transferred | Internal 🔒 | 🛑  | |
| └ | _transferredFrom | Internal 🔒 | 🛑  | |
| └ | _setMintAllowance | Internal 🔒 | 🛑  | |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | _ruleNotBound | Internal 🔒 |   | |
| └ | _authorizeSetMintAllowance | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
