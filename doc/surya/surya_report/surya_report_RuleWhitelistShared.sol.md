## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/core/RuleWhitelistShared.sol | 0fffa7148b88756ab660cafd928e9ed9b707a37a |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleWhitelistShared** | Implementation | RuleNFTAdapter, RuleWhitelistInvariantStorage |||
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | External ❗️ |   |NO❗️ |
| └ | setCheckSpender | Public ❗️ | 🛑  | onlyCheckSpenderManager |
| └ | setAllowMint | Public ❗️ | 🛑  | onlyMintBurnManager |
| └ | setAllowBurn | Public ❗️ | 🛑  | onlyMintBurnManager |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | _setCheckSpender | Internal 🔒 | 🛑  | |
| └ | _setAllowMintBurn | Internal 🔒 | 🛑  | |
| └ | _detectMintBurnRestriction | Internal 🔒 |   | |
| └ | _authorizeMintBurnManager | Internal 🔒 |   | |
| └ | _authorizeCheckSpenderManager | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 |   | |
| └ | _transferredFrom | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
