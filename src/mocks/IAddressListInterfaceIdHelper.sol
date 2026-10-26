// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IAddressList} from "../rules/interfaces/IAddressList.sol";
import {IIdentityRegistryContains} from "../rules/interfaces/IIdentityRegistry.sol";
import {AddressListInterfaceId} from "../rules/interfaces/library/AddressListInterfaceId.sol";

/**
 * @title IAddressListAllFunctions
 * @dev Flattened interface containing ALL functions from the {IAddressList} hierarchy.
 *      Used to compute the full ERC-165 interface ID (XOR of all selectors).
 *
 *      `type(IAddressList).interfaceId` only covers the functions declared directly on
 *      `IAddressList` and OMITS `contains(address)`, which is inherited from
 *      `IIdentityRegistryContains`. `type(IAddressListAllFunctions).interfaceId` covers
 *      the full hierarchy and is the value stored in {AddressListInterfaceId}.
 */
interface IAddressListAllFunctions {
    /* ==== From IAddressList ==== */

    /**
     * @notice Adds several addresses to the set.
     * @param targetAddresses The addresses to add.
     */
    function addAddresses(address[] calldata targetAddresses) external;

    /**
     * @notice Removes several addresses from the set.
     * @param targetAddresses The addresses to remove.
     */
    function removeAddresses(address[] calldata targetAddresses) external;

    /**
     * @notice Adds a single address to the set.
     * @param targetAddress The address to add.
     */
    function addAddress(address targetAddress) external;

    /**
     * @notice Removes a single address from the set.
     * @param targetAddress The address to remove.
     */
    function removeAddress(address targetAddress) external;

    /**
     * @notice Returns the number of addresses currently in the set.
     * @return count The number of listed addresses.
     */
    function listedAddressCount() external view returns (uint256 count);

    /**
     * @notice Returns whether a single address is in the set.
     * @param targetAddress The address to check.
     * @return isListed True if the address is listed.
     */
    function isAddressListed(address targetAddress) external view returns (bool isListed);

    /**
     * @notice Returns membership for several addresses in one call.
     * @param targetAddresses The addresses to check.
     * @return results One boolean per input address, in the same order.
     */
    function areAddressesListed(address[] memory targetAddresses) external view returns (bool[] memory results);

    /* ==== From IIdentityRegistryContains ==== */

    /**
     * @notice Returns whether an address is in the set.
     * @dev This is the selector that `type(IAddressList).interfaceId` OMITS, because it is
     *      inherited rather than declared directly. Redeclaring it here is the whole point of
     *      this flattened interface.
     * @param _userAddress The address to check.
     * @return True if the address is listed.
     */
    function contains(address _userAddress) external view returns (bool);
}

/**
 * @title IAddressListInterfaceIdHelper
 * @dev Helper contract exposing the {IAddressList} interface IDs so the pre-computed constant
 *      can be verified in tests.
 */
contract IAddressListInterfaceIdHelper {
    /**
     * @notice Returns `type(IAddressList).interfaceId` — INCOMPLETE, omits inherited selectors.
     * @return The naive interface ID, which does NOT include the inherited `contains(address)`.
     */
    function getIAddressListInterfaceId() external pure returns (bytes4) {
        return type(IAddressList).interfaceId;
    }

    /**
     * @notice Returns the XOR of ALL selectors in the {IAddressList} hierarchy (flattened).
     * @return The complete interface ID, including the inherited `contains(address)` selector.
     */
    function getIAddressListAllFunctionsInterfaceId() external pure returns (bytes4) {
        return type(IAddressListAllFunctions).interfaceId;
    }

    /**
     * @notice Returns the constant defined in the {AddressListInterfaceId} library.
     * @return The pre-computed constant the rules actually advertise via ERC-165.
     */
    function getAddressListInterfaceIdConstant() external pure returns (bytes4) {
        return AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID;
    }

    /**
     * @notice Returns the interface ID of the inherited parent interface.
     * @return The interface ID of {IIdentityRegistryContains}.
     */
    function getIIdentityRegistryContainsInterfaceId() external pure returns (bytes4) {
        return type(IIdentityRegistryContains).interfaceId;
    }
}
