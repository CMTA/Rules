// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "./RuleSharedInvariantStorage.sol";

/**
 * @title RuleIdentityRegistryInvariantStorage — constants and event for the identity-registry rule.
 */
abstract contract RuleIdentityRegistryInvariantStorage is RuleSharedInvariantStorage {
    /**
     * @notice Restriction message returned when the sender is not verified.
     */
    string constant TEXT_ADDRESS_FROM_NOT_VERIFIED = "The sender is not verified";
    /**
     * @notice Restriction message returned when the recipient is not verified.
     */
    string constant TEXT_ADDRESS_TO_NOT_VERIFIED = "The recipient is not verified";
    /**
     * @notice Restriction message returned when the spender is not verified.
     */
    string constant TEXT_ADDRESS_SPENDER_NOT_VERIFIED = "The spender is not verified";

    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the sender is not verified.
     */
    uint8 public constant CODE_ADDRESS_FROM_NOT_VERIFIED = 55;
    /**
     * @notice Restriction code returned when the recipient is not verified.
     */
    uint8 public constant CODE_ADDRESS_TO_NOT_VERIFIED = 56;
    /**
     * @notice Restriction code returned when the spender is not verified.
     */
    uint8 public constant CODE_ADDRESS_SPENDER_NOT_VERIFIED = 57;

    /**
     * @notice Emitted when the identity registry address is updated.
     * @param newRegistry Address of the newly configured identity registry.
     */
    event IdentityRegistryUpdated(address indexed newRegistry);
    /**
     * @notice Emitted when the identity rule's `checkSender` flag is updated.
     * @param newValue New value of the `checkSender` flag.
     */
    event IdentityCheckSenderUpdated(bool newValue);
    /**
     * @notice Emitted when the identity rule's `checkSpender` flag is updated.
     * @dev Named distinctly from the whitelist rule's `CheckSpenderUpdated` so a contract may inherit
     *      both invariant-storage contracts (e.g. the test HelperContract) without a name clash.
     * @param newValue New value of the `checkSpender` flag.
     */
    event IdentityCheckSpenderUpdated(bool newValue);

    error RuleIdentityRegistry_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleIdentityRegistry_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
    error RuleIdentityRegistry_RegistryAddressZeroNotAllowed();
}
