// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/* ==== OpenZeppelin === */
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AddressSetBatchLib} from "./AddressSetBatchLib.sol";
import {RuleAddressSetInvariantStorage} from "./invariantStorage/RuleAddressSetInvariantStorage.sol";

/**
 * @title Rule Address Set (Internal)
 * @notice Internal utility for managing a set of rule-related addresses.
 * @dev
 * - Uses OpenZeppelin's EnumerableSet for efficient enumeration.
 * - Designed for internal inheritance and logic composition.
 * - Batch operations do not revert when individual entries are invalid.
 */
abstract contract RuleAddressSetInternal is RuleAddressSetInvariantStorage {
    using EnumerableSet for EnumerableSet.AddressSet;
    using AddressSetBatchLib for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Storage for all listed addresses.
     */
    EnumerableSet.AddressSet private _listedAddresses;

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the set.
     * @dev
     * - Does not revert if an address is already listed.
     * - Skips existing entries silently.
     * - REVERTS on `address(0)`, rejecting the whole batch; see the inline comment below.
     * @param addressesToAdd The array of addresses to add.
     * @return added The number of newly added addresses.
     * @return skipped The number of addresses that were already listed.
     */
    function _addAddresses(address[] calldata addressesToAdd)
        internal
        virtual
        returns (uint256 added, uint256 skipped)
    {
        return _listedAddresses.addBatch(addressesToAdd, _requireNotZeroAddress);
    }

    /**
     * @notice Per-entry guard for {_addAddresses}; reverts on the zero address.
     * @dev The zero address is the mint/burn sentinel, never a participant. It is REJECTED rather
     * than skipped: the batch convention skips *duplicates* (an idempotent no-op that the emitted
     * event still describes truthfully), but silently dropping address(0) would make `AddAddresses`
     * report a member that is not in the set — re-polluting the very off-chain view this guard
     * exists to keep clean. Mint/burn is governed by allowMint/allowBurn, never by list membership.
     *
     * Passed to {AddressSetBatchLib.addBatch} as a function pointer so the shared loop can reject
     * the sentinel with THIS rule's error rather than a generic one.
     * @param targetAddress The candidate address.
     */
    function _requireNotZeroAddress(address targetAddress) internal pure virtual {
        require(targetAddress != address(0), RuleAddressSet_ZeroAddressNotAllowed());
    }

    /**
     * @notice Removes multiple addresses from the set.
     * @dev
     * - Does not revert if an address is not found.
     * - Skips non-existing entries silently.
     * @param addressesToRemove The array of addresses to remove.
     * @return removed The number of addresses removed.
     * @return skipped The number of addresses that were not listed.
     */
    function _removeAddresses(address[] calldata addressesToRemove)
        internal
        virtual
        returns (uint256 removed, uint256 skipped)
    {
        return _listedAddresses.removeBatch(addressesToRemove);
    }

    /**
     * @notice Adds a single address to the set.
     * @dev Forwards {EnumerableSet}'s "did this change anything" result so the caller can reject a
     * duplicate without a second lookup: the membership test the caller would otherwise perform is
     * the same one `add` already does internally (`CLAUDE_ANALYSIS.md` B-4).
     * @param targetAddress The address to add.
     * @return True when the address was not already listed.
     */
    function _addAddress(address targetAddress) internal virtual returns (bool) {
        return _listedAddresses.add(targetAddress);
    }

    /**
     * @notice Removes a single address from the set.
     * @dev Forwards {EnumerableSet}'s result; see {_addAddress}.
     * @param targetAddress The address to remove.
     * @return True when the address was listed and has been removed.
     */
    function _removeAddress(address targetAddress) internal virtual returns (bool) {
        return _listedAddresses.remove(targetAddress);
    }

    /**
     * @notice Returns the total number of listed addresses.
     * @return count The number of listed addresses.
     */
    function _listedAddressCount() internal view virtual returns (uint256 count) {
        count = _listedAddresses.length();
    }

    /**
     * @notice Checks if an address is listed.
     * @param targetAddress The address to check.
     * @return isListed True if the address is listed, false otherwise.
     */
    function _isAddressListed(address targetAddress) internal view virtual returns (bool isListed) {
        isListed = _listedAddresses.contains(targetAddress);
    }
}
