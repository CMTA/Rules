// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/* ==== OpenZeppelin === */
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AddressSetBatchLib} from "../RuleAddressSet/AddressSetBatchLib.sol";
import {RuleERC2980InvariantStorage} from "./invariantStorage/RuleERC2980InvariantStorage.sol";

/**
 * @title RuleERC2980Internal
 * @notice Internal storage and helpers for two independent address sets:
 *         a whitelist and a frozenlist, following the same pattern as {RuleAddressSetInternal}.
 * @dev
 * - Whitelist: only whitelisted addresses may receive tokens.
 * - Frozenlist: frozen addresses may neither send nor receive tokens.
 * - Batch operations do not revert when individual entries are already present or absent.
 */
abstract contract RuleERC2980Internal is RuleERC2980InvariantStorage {
    using EnumerableSet for EnumerableSet.AddressSet;
    using AddressSetBatchLib for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Addresses allowed to receive tokens.
     */
    EnumerableSet.AddressSet private _whitelist;

    /**
     * @dev Addresses completely blocked from sending and receiving tokens.
     */
    EnumerableSet.AddressSet private _frozenlist;

    /*//////////////////////////////////////////////////////////////
                          WHITELIST — INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the whitelist, skipping any already present.
     * @dev REVERTS on `address(0)`, rejecting the whole batch; see the inline comment below.
     * @param addressesToAdd Addresses to add to the whitelist.
     * @return added Number of addresses newly added.
     * @return skipped Number of addresses that were already whitelisted.
     */
    function _addWhitelistAddresses(address[] calldata addressesToAdd)
        internal
        virtual
        returns (uint256 added, uint256 skipped)
    {
        return _whitelist.addBatch(addressesToAdd, _requireNotZeroAddress);
    }

    /**
     * @notice Removes multiple addresses from the whitelist, skipping any that are absent.
     * @param addressesToRemove Addresses to remove from the whitelist.
     * @return removed Number of addresses actually removed.
     * @return skipped Number of addresses that were not whitelisted.
     */
    function _removeWhitelistAddresses(address[] calldata addressesToRemove)
        internal
        virtual
        returns (uint256 removed, uint256 skipped)
    {
        return _whitelist.removeBatch(addressesToRemove);
    }

    /**
     * @notice Adds a single address to the whitelist.
     * @param targetAddress Address to add to the whitelist.
     */
    function _addWhitelistAddress(address targetAddress) internal virtual returns (bool) {
        return _whitelist.add(targetAddress);
    }

    /**
     * @notice Removes a single address from the whitelist.
     * @param targetAddress Address to remove from the whitelist.
     */
    function _removeWhitelistAddress(address targetAddress) internal virtual returns (bool) {
        return _whitelist.remove(targetAddress);
    }

    /*//////////////////////////////////////////////////////////////
                         FROZENLIST — INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the frozenlist, skipping any already present.
     * @dev REVERTS on `address(0)`, rejecting the whole batch; see the inline comment below.
     * @param addressesToAdd Addresses to add to the frozenlist.
     * @return added Number of addresses newly added.
     * @return skipped Number of addresses that were already frozen.
     */
    function _addFrozenlistAddresses(address[] calldata addressesToAdd)
        internal
        virtual
        returns (uint256 added, uint256 skipped)
    {
        return _frozenlist.addBatch(addressesToAdd, _requireNotZeroAddress);
    }

    /**
     * @notice Removes multiple addresses from the frozenlist, skipping any that are absent.
     * @param addressesToRemove Addresses to remove from the frozenlist.
     * @return removed Number of addresses actually removed.
     * @return skipped Number of addresses that were not frozen.
     */
    function _removeFrozenlistAddresses(address[] calldata addressesToRemove)
        internal
        virtual
        returns (uint256 removed, uint256 skipped)
    {
        return _frozenlist.removeBatch(addressesToRemove);
    }

    /**
     * @notice Adds a single address to the frozenlist.
     * @param targetAddress Address to add to the frozenlist.
     */
    function _addFrozenlistAddress(address targetAddress) internal virtual returns (bool) {
        return _frozenlist.add(targetAddress);
    }

    /**
     * @notice Removes a single address from the frozenlist.
     * @param targetAddress Address to remove from the frozenlist.
     */
    function _removeFrozenlistAddress(address targetAddress) internal virtual returns (bool) {
        return _frozenlist.remove(targetAddress);
    }

    /**
     * @notice Per-entry guard for both batch adders; reverts on the zero address.
     * @dev The zero address is the mint/burn sentinel, never a participant. REJECTED rather than
     * skipped, so the emitted batch event can never report it as a list member. Passed to
     * {AddressSetBatchLib.addBatch} as a function pointer so the shared loop rejects the sentinel
     * with THIS rule's error rather than a generic one.
     * @param targetAddress The candidate address.
     */
    function _requireNotZeroAddress(address targetAddress) internal pure virtual {
        require(targetAddress != address(0), RuleERC2980_ZeroAddressNotAllowed());
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW — INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether an address is whitelisted.
     * @param targetAddress Address to check.
     * @return True if the address is whitelisted.
     */
    function _isWhitelisted(address targetAddress) internal view virtual returns (bool) {
        return _whitelist.contains(targetAddress);
    }

    /**
     * @notice Returns the number of whitelisted addresses.
     * @return The count of whitelisted addresses.
     */
    function _whitelistCount() internal view virtual returns (uint256) {
        return _whitelist.length();
    }

    /**
     * @notice Returns whether an address is frozen.
     * @param targetAddress Address to check.
     * @return True if the address is frozen.
     */
    function _isFrozen(address targetAddress) internal view virtual returns (bool) {
        return _frozenlist.contains(targetAddress);
    }

    /**
     * @notice Returns the number of frozen addresses.
     * @return The count of frozen addresses.
     */
    function _frozenlistCount() internal view virtual returns (uint256) {
        return _frozenlist.length();
    }
}
