## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./registry/abstract/IdentityRegistryWhitelistBase.sol | a829964c7d939f9ee5aab8bebf1ae471320606ad |


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
