// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/**
 * @title RuleAddressSetInvariantStorage — errors shared by the address-set rules.
 * @dev The roles gating the public API live in {RuleAddressSetRolesStorage}: a contract that
 *      inherits only {RuleAddressSetInternal} must not advertise roles it never enforces.
 */
abstract contract RuleAddressSetInvariantStorage {
    /* ============ Custom errors ============ */
    /**
     * @notice Thrown when trying to add an address that is already listed.
     */
    error RuleAddressSet_AddressAlreadyListed();

    /**
     * @notice Thrown when trying to remove an address that is not listed.
     */
    error RuleAddressSet_AddressNotFound();

    /**
     * @notice Thrown when trying to add the zero address to the set.
     * @dev The zero address is the ERC-20 mint/burn sentinel, not a participant. Listing it would
     *      make `isVerified(address(0))` / `contains(address(0))` return `true`, contradicting
     *      ERC-3643. Mint/burn permission is governed by the explicit `allowMint` / `allowBurn`
     *      flags instead.
     */
    error RuleAddressSet_ZeroAddressNotAllowed();
}
