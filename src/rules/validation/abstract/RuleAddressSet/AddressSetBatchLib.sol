// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title AddressSetBatchLib
 * @notice The batch add/remove loops shared by every address-list rule in this library.
 * @dev Extracted because the same two loops were written three times and had already drifted: only
 * the {RuleAddressSetInternal} copy was covered by a zero-address test.
 * Only the loops live here; single-address `add` / `remove` / `contains` / `length` stay as one-line
 * delegations to {EnumerableSet}, where a library would add indirection without removing duplication.
 *
 * @dev **The zero-address guard is a function-pointer parameter** so each rule keeps its own error
 * (`RuleAddressSet_ZeroAddressNotAllowed` vs `RuleERC2980_ZeroAddressNotAllowed`), per the
 * one-error-namespace-per-rule convention. Being a required parameter makes it MANDATORY: the call
 * does not compile without one. Returning a "zero found" flag instead would make the guard optional
 * in practice, and a caller that forgot it would list `address(0)` -- exactly what it prevents. The
 * pointer resolves at compile time and the library is `internal`, so this is a jump, not a
 * `DELEGATECALL`.
 */
library AddressSetBatchLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice Adds every address in `addressesToAdd` to `set`, skipping entries already present.
     * @dev Duplicates are skipped and counted rather than rejected: an idempotent no-op that the
     * caller's batch event still describes truthfully. `address(0)` is NOT skipped -- `guard` is
     * invoked for every entry and is expected to revert on it, rejecting the whole batch. Silently
     * dropping the sentinel would make the caller's `Add*` event, which echoes the input array,
     * report a member that is not in the set.
     * @param set The address set to modify.
     * @param addressesToAdd The addresses to add.
     * @param guard Per-entry validation supplied by the calling rule; reverts with that rule's own
     * error. Invoked before the entry is inserted.
     * @return added The number of addresses newly inserted.
     * @return skipped The number of addresses already present.
     */
    function addBatch(
        EnumerableSet.AddressSet storage set,
        address[] calldata addressesToAdd,
        function(address) internal pure guard
    ) internal returns (uint256 added, uint256 skipped) {
        for (uint256 i = 0; i < addressesToAdd.length; ++i) {
            guard(addressesToAdd[i]);
            if (set.add(addressesToAdd[i])) {
                added += 1;
            } else {
                skipped += 1;
            }
        }
    }

    /**
     * @notice Removes every address in `addressesToRemove` from `set`, skipping absent entries.
     * @dev No guard: removal has no invalid input. Removing an address that is not present is an
     * idempotent no-op, counted in `skipped`.
     * @param set The address set to modify.
     * @param addressesToRemove The addresses to remove.
     * @return removed The number of addresses actually removed.
     * @return skipped The number of addresses that were not present.
     */
    function removeBatch(EnumerableSet.AddressSet storage set, address[] calldata addressesToRemove)
        internal
        returns (uint256 removed, uint256 skipped)
    {
        for (uint256 i = 0; i < addressesToRemove.length; ++i) {
            if (set.remove(addressesToRemove[i])) {
                removed += 1;
            } else {
                skipped += 1;
            }
        }
    }
}
