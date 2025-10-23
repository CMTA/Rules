// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

abstract contract RuleAddressSetInvariantStorage {
    /* ============ Events ============ */
    event AddAddresses(address[] listTargetAddresses);
    event RemoveAddresses(address[] listTargetAddresses);
    event AddAddress(address targetAddress);
    event RemoveAddress(address targetAddress);

    /* ============ Custom errors ============ */
    error RuleAddressSet_AdminWithAddressZeroNotAllowed();

    /// @notice Thrown when trying to add an address that is already listed.
    error RuleAddressSet_AddressAlreadyListed();

    /// @notice Thrown when trying to remove an address that is not listed.
    error RuleAddressSet_AddressNotFound();

    /* ============ Role ============ */
    bytes32 public constant ADDRESS_LIST_REMOVE_ROLE =
        keccak256("ADDRESS_LIST_REMOVE_ROLE");
    bytes32 public constant ADDRESS_LIST_ADD_ROLE =
        keccak256("ADDRESS_LIST_ADD_ROLE");
}
