## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./mocks/ERC3643TokenMock.sol | 1ed75c6e22c5677378835a73273381ce42e7b7aa |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IERC3643ComplianceForToken** | Interface |  |||
| └ | bindToken | External ❗️ | 🛑  |NO❗️ |
| └ | unbindToken | External ❗️ | 🛑  |NO❗️ |
| └ | transferred | External ❗️ | 🛑  |NO❗️ |
| └ | created | External ❗️ | 🛑  |NO❗️ |
| └ | destroyed | External ❗️ | 🛑  |NO❗️ |
| └ | canTransfer | External ❗️ |   |NO❗️ |
||||||
| **ERC3643TokenMock** | Implementation |  |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | setIdentityRegistry | External ❗️ | 🛑  |NO❗️ |
| └ | setCompliance | External ❗️ | 🛑  |NO❗️ |
| └ | setAgent | External ❗️ | 🛑  |NO❗️ |
| └ | transfer | External ❗️ | 🛑  |NO❗️ |
| └ | transferFrom | External ❗️ | 🛑  |NO❗️ |
| └ | mint | External ❗️ | 🛑  | onlyAgent |
| └ | burn | External ❗️ | 🛑  | onlyAgent |
| └ | recoveryAddress | External ❗️ | 🛑  | onlyAgent |
| └ | forcedTransfer | Public ❗️ | 🛑  | onlyAgent |
| └ | _complianceTransferred | Internal 🔒 | 🛑  | |
| └ | _transfer | Internal 🔒 | 🛑  | |
| └ | _canTransfer | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
