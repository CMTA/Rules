// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/**
 * @title RuleAddressSetRolesStorage — the roles gating the public address-set API.
 * @dev Deliberately separate from {RuleAddressSetInvariantStorage}. These two roles authorise
 *      `addAddress` / `removeAddress`, which live on {RuleAddressSet} -- the *public* layer. A
 *      contract that inherits only {RuleAddressSetInternal} (the storage primitives) reuses the
 *      set machinery without exposing that API, and must not advertise roles it never checks:
 *      `IdentityRegistryWhitelist` gates registration on `IDENTITY_REGISTRAR_ROLE`, so publishing
 *      `ADDRESS_LIST_ADD_ROLE` there would invite an operator to grant a privilege that authorises
 *      nothing, with no on-chain signal that it had no effect.
 *
 *      Keeping the roles here means only the layer that enforces them declares them.
 */
abstract contract RuleAddressSetRolesStorage {
    /**
     * @notice Role allowed to remove addresses from the set.
     */
    bytes32 public constant ADDRESS_LIST_REMOVE_ROLE = keccak256("ADDRESS_LIST_REMOVE_ROLE");
    /**
     * @notice Role allowed to add addresses to the set.
     */
    bytes32 public constant ADDRESS_LIST_ADD_ROLE = keccak256("ADDRESS_LIST_ADD_ROLE");
}
