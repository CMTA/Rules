## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/base/RuleERC2980Base.sol | b391797a15cf166c899e323fad1f0b63cb84b754 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleERC2980Base** | Implementation | MetaTxModuleStandalone, RuleERC2980InvariantStorage, RuleERC2980Internal, RuleNFTAdapter, IERC2980, IIdentityRegistryVerified |||
| └ | <Constructor> | Public ❗️ | 🛑  | MetaTxModuleStandalone |
| └ | addWhitelistAddresses | Public ❗️ | 🛑  | onlyWhitelistAdd |
| └ | removeWhitelistAddresses | Public ❗️ | 🛑  | onlyWhitelistRemove |
| └ | addWhitelistAddress | Public ❗️ | 🛑  | onlyWhitelistAdd |
| └ | removeWhitelistAddress | Public ❗️ | 🛑  | onlyWhitelistRemove |
| └ | addFrozenlistAddresses | Public ❗️ | 🛑  | onlyFrozenlistAdd |
| └ | removeFrozenlistAddresses | Public ❗️ | 🛑  | onlyFrozenlistRemove |
| └ | addFrozenlistAddress | Public ❗️ | 🛑  | onlyFrozenlistAdd |
| └ | removeFrozenlistAddress | Public ❗️ | 🛑  | onlyFrozenlistRemove |
| └ | setAllowMint | Public ❗️ | 🛑  | onlyMintBurnManager |
| └ | setAllowBurn | Public ❗️ | 🛑  | onlyMintBurnManager |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | canReturnTransferRestrictionCode | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | whitelistAddressCount | Public ❗️ |   |NO❗️ |
| └ | isWhitelisted | Public ❗️ |   |NO❗️ |
| └ | whitelist | Public ❗️ |   |NO❗️ |
| └ | isVerified | Public ❗️ |   |NO❗️ |
| └ | areWhitelisted | Public ❗️ |   |NO❗️ |
| └ | frozenlistAddressCount | Public ❗️ |   |NO❗️ |
| └ | isFrozen | Public ❗️ |   |NO❗️ |
| └ | frozenlist | Public ❗️ |   |NO❗️ |
| └ | areFrozen | Public ❗️ |   |NO❗️ |
| └ | _authorizeMintBurnManager | Internal 🔒 |   | |
| └ | _authorizeWhitelistAdd | Internal 🔒 |   | |
| └ | _authorizeWhitelistRemove | Internal 🔒 |   | |
| └ | _authorizeFrozenlistAdd | Internal 🔒 |   | |
| └ | _authorizeFrozenlistRemove | Internal 🔒 |   | |
| └ | _detectTransferRestriction | Internal 🔒 |   | |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 |   | |
| └ | _transferredFrom | Internal 🔒 |   | |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
