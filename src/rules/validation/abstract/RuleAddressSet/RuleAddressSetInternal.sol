// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/* ==== OpenZeppelin === */
import {EnumerableSet} from "OZ/utils/structs/EnumerableSet.sol";

/**
 * @title Rule Address Set (Internal)
 * @notice Internal utility for managing a set of rule-related addresses.
 * @dev
 * - Uses OpenZeppelin's EnumerableSet for efficient enumeration.
 * - Designed for internal inheritance and logic composition.
 * - Batch operations do not revert when individual entries are invalid.
 */
abstract contract RuleAddressSetInternal {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev Storage for all listed addresses.
    EnumerableSet.AddressSet private _listedAddresses;

    /*//////////////////////////////////////////////////////////////
                               CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the set.
     * @dev
     * - Does not revert if an address is already listed.
     * - Skips existing entries silently.
     * @param addressesToAdd The array of addresses to add.
     */
    function _addAddresses(address[] calldata addressesToAdd) internal {
        for (uint256 i = 0; i < addressesToAdd.length; ++i) {
            _listedAddresses.add(addressesToAdd[i]);
        }
    }

    /**
     * @notice Removes multiple addresses from the set.
     * @dev
     * - Does not revert if an address is not found.
     * - Skips non-existing entries silently.
     * @param addressesToRemove The array of addresses to remove.
     */
    function _removeAddresses(address[] calldata addressesToRemove) internal {
        for (uint256 i = 0; i < addressesToRemove.length; ++i) {
            _listedAddresses.remove(addressesToRemove[i]);
        }
    }

    /**
     * @notice Adds a single address to the set.
     * @param targetAddress The address to add.
     */
    function _addAddress(address targetAddress) internal {
        _listedAddresses.add(targetAddress);
    }

    /**
     * @notice Removes a single address from the set.
     * @param targetAddress The address to remove.
     */
    function _removeAddress(address targetAddress) internal {
        _listedAddresses.remove(targetAddress);
    }

    /**
     * @notice Returns the total number of listed addresses.
     * @return count The number of listed addresses.
     */
    function _listedAddressCount() internal view returns (uint256 count) {
        count = _listedAddresses.length();
    }

    /**
     * @notice Checks if an address is listed.
     * @param targetAddress The address to check.
     * @return isListed True if the address is listed, false otherwise.
     */
    function _isAddressListed(address targetAddress) internal view returns (bool isListed) {
        isListed = _listedAddresses.contains(targetAddress);
    }
}
