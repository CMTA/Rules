## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/interfaces/IAddressList.sol | 2986fa01ee3211e35276e0ef8970a939c1c9f050 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IAddressListBatchQuery** | Interface |  |||
| └ | areAddressesListed | External ❗️ |   |NO❗️ |
||||||
| **IAddressListPolarity** | Interface |  |||
| └ | isAllowList | External ❗️ |   |NO❗️ |
||||||
| **IAddressList** | Interface | IIdentityRegistryContains, IAddressListBatchQuery |||
| └ | addAddresses | External ❗️ | 🛑  |NO❗️ |
| └ | removeAddresses | External ❗️ | 🛑  |NO❗️ |
| └ | addAddress | External ❗️ | 🛑  |NO❗️ |
| └ | removeAddress | External ❗️ | 🛑  |NO❗️ |
| └ | listedAddressCount | External ❗️ |   |NO❗️ |
| └ | isAddressListed | External ❗️ |   |NO❗️ |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
