## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleBlacklistOwnable2Step.sol | 87bd6df360372d9bdfd45ef99981ae63093376aa |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleBlacklistOwnable2Step** | Implementation | RuleBlacklistBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleBlacklistBase Ownable |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeAddressListAdd | Internal 🔒 |   | onlyOwner |
| └ | _authorizeAddressListRemove | Internal 🔒 |   | onlyOwner |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
