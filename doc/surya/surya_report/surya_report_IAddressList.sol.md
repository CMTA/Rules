## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/interfaces/IAddressList.sol | abe344e2f5902c44284fa7618f35e8f7efabf7c5 |


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
