// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIdentityRegistryContains} from "./IIdentityRegistry.sol";
interface IAddressList is IIdentityRegistryContains {
    /* ============ Events ============ */
    /// @notice Emitted when multiple addresses are added.
    /// @param targetAddresses The array of added addresses.
    event AddAddresses(address[] targetAddresses);

    /// @notice Emitted when multiple addresses are removed.
    /// @param targetAddresses The array of removed addresses.
    event RemoveAddresses(address[] targetAddresses);

    /// @notice Emitted when a single address is added.
    /// @param targetAddress The added address.
    event AddAddress(address targetAddress);

    /// @notice Emitted when a single address is removed.
    /// @param targetAddress The removed address.
    event RemoveAddress(address targetAddress);


    /* ============ Write ============ */
    /**
     * @notice Adds multiple addresses to the set.
     * @dev Does not revert if some addresses are already listed.
     * @param targetAddresses The addresses to add.
     */
    function addAddresses(address[] calldata targetAddresses) external;

    /**
     * @notice Removes multiple addresses from the set.
     * @dev Does not revert if some addresses are not listed.
     * @param targetAddresses The addresses to remove.
     */
    function removeAddresses(address[] calldata targetAddresses) external;

    /**
     * @notice Adds a single address to the set.
     * @dev Reverts if the address is already listed.
     * @param targetAddress The address to add.
     */
    function addAddress(address targetAddress) external;

    /**
     * @notice Removes a single address from the set.
     * @dev Reverts if the address is not listed.
     * @param targetAddress The address to remove.
     */
    function removeAddress(address targetAddress) external;


    /* ============ Read ============ */

    /**
     * @notice Returns the number of currently listed addresses.
     * @return count The number of listed addresses.
     */
    function listedAddressCount() external view returns (uint256 count);

    /**
     * @notice Checks whether the provided address is listed.
     * @param targetAddress The address to check.
     * @return isListed True if listed, otherwise false.
     */
    function isAddressListed(address targetAddress) external view returns (bool isListed);

    /**
     * @notice Checks multiple addresses for listing status.
     * @param targetAddresses Array of addresses to check.
     * @return results Boolean array aligned by index with listing results.
     */
    function areAddressesListed(address[] memory targetAddresses)
        external
        view
        returns (bool[] memory results);
}