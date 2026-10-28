## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleWhitelistOwnable2Step.sol | 6388dcde4a64c9c85f896226bee6f07728f36c4c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleWhitelistOwnable2Step** | Implementation | RuleWhitelistBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleWhitelistBase Ownable |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeAddressListAdd | Internal 🔒 |   | onlyOwner |
| └ | _authorizeAddressListRemove | Internal 🔒 |   | onlyOwner |
| └ | _authorizeCheckSpenderManager | Internal 🔒 |   | onlyOwner |
| └ | _authorizeMintBurnManager | Internal 🔒 |   | onlyOwner |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
