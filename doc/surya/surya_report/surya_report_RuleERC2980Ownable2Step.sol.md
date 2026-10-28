## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleERC2980Ownable2Step.sol | 227f48947f8b9bf802cf396f4df774b46fbac340 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleERC2980Ownable2Step** | Implementation | RuleERC2980Base, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleERC2980Base Ownable |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeMintBurnManager | Internal 🔒 |   | onlyOwner |
| └ | _authorizeWhitelistAdd | Internal 🔒 |   | onlyOwner |
| └ | _authorizeWhitelistRemove | Internal 🔒 |   | onlyOwner |
| └ | _authorizeFrozenlistAdd | Internal 🔒 |   | onlyOwner |
| └ | _authorizeFrozenlistRemove | Internal 🔒 |   | onlyOwner |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
