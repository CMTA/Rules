## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleReceiverWhitelist.sol | f2d5adfa22718d97a5d1a4947bf2aae9a5d6f12c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleReceiverWhitelist** | Implementation | RuleReceiverWhitelistBase, AccessControlModuleStandalone |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleReceiverWhitelistBase AccessControlModuleStandalone |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeAddressListAdd | Internal 🔒 |   | onlyRole |
| └ | _authorizeAddressListRemove | Internal 🔒 |   | onlyRole |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
