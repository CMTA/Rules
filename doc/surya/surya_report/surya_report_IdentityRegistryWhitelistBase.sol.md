## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./registry/abstract/IdentityRegistryWhitelistBase.sol | 3bba6ad17cbcf93b254fb597feaaaffef4812195 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IdentityRegistryWhitelistBase** | Implementation | RuleAddressSetInternal, VersionModule, IIdentityRegistryERC3643, IdentityRegistryWhitelistInvariantStorage |||
| └ | registerIdentity | External ❗️ | 🛑  | onlyIdentityRegistrar |
| └ | deleteIdentity | External ❗️ | 🛑  | onlyIdentityRegistrar |
| └ | registeredIdentityCount | External ❗️ |   |NO❗️ |
| └ | isVerified | Public ❗️ |   |NO❗️ |
| └ | investorCountry | Public ❗️ |   |NO❗️ |
| └ | _authorizeIdentityRegistrar | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
