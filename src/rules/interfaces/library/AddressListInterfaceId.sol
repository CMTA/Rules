// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/**
 * @title AddressListInterfaceId
 * @dev ERC-165 interface ID for the full {IAddressList} hierarchy (XOR of all function selectors).
 *
 *      `type(IAddressList).interfaceId` CANNOT be used: it XORs only the selectors declared directly
 *      on `IAddressList` and omits `contains(address)`, inherited from `IIdentityRegistryContains`.
 *      This constant is computed from the flattened `IAddressListAllFunctions` interface instead.
 *
 *      See src/mocks/IAddressListInterfaceIdHelper.sol; the value is asserted by
 *      test/InterfaceId/AddressListInterfaceId.t.sol.
 */
library AddressListInterfaceId {
    /**
     * @notice ERC-165 interface ID of the full {IAddressList} hierarchy.
     */
    bytes4 public constant IADDRESS_LIST_INTERFACE_ID = 0x5d10e182;

    /**
     * @notice ERC-165 interface ID of {IAddressListBatchQuery}, the single function
     * `areAddressesListed(address[])`.
     * @dev This is what `RuleWhitelistWrapper` requires of a child, because it is the only function
     * the wrapper ever calls. Demanding {IADDRESS_LIST_INTERFACE_ID} instead would also require four
     * write functions, `listedAddressCount`, `isAddressListed` and `contains` — none of which the
     * wrapper uses — and would exclude a read-only child that is otherwise perfectly usable.
     *
     * Safe to state as a literal: {IAddressListBatchQuery} declares one function and inherits
     * nothing, so unlike {IADDRESS_LIST_INTERFACE_ID} there is no omitted-parent trap here. The
     * value equals the selector of the single function; asserted in
     * test/InterfaceId/AddressListInterfaceId.t.sol.
     */
    bytes4 public constant IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID = 0x20e8e17a;

    /**
     * @notice ERC-165 interface ID of {IAddressListPolarity}, the single function `isAllowList()`.
     * @dev Paired with {IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID} by consumers that read membership as
     * eligibility: the first says the contract can answer, this one says what the answer means. A
     * consumer must treat its ABSENCE as a refusal, not as an allow-list — that is the only reading
     * that fails closed for a contract predating the interface or deliberately declining it.
     *
     * Safe as a literal for the same reason as the batch-query id: one function, no inheritance.
     */
    bytes4 public constant IADDRESS_LIST_POLARITY_INTERFACE_ID = 0xdc4efe10;
}
