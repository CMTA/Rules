// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "../../invariant/RuleSharedInvariantStorage.sol";

/**
 * @title RuleBlacklistInvariantStorage — constants and errors for the blacklist rule.
 */
abstract contract RuleBlacklistInvariantStorage is RuleSharedInvariantStorage {
    /* ============ String message ============ */
    /**
     * @notice Restriction message returned when the sender is blacklisted.
     */
    string constant TEXT_ADDRESS_FROM_IS_BLACKLISTED = "The sender is blacklisted";
    /**
     * @notice Restriction message returned when the recipient is blacklisted.
     */
    string constant TEXT_ADDRESS_TO_IS_BLACKLISTED = "The recipient is blacklisted";
    /**
     * @notice Restriction message returned when the spender is blacklisted.
     */
    string constant TEXT_ADDRESS_SPENDER_IS_BLACKLISTED = "The spender is blacklisted";

    /* ============ Code ============ */
    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the sender is blacklisted.
     */
    uint8 public constant CODE_ADDRESS_FROM_IS_BLACKLISTED = 36;
    /**
     * @notice Restriction code returned when the recipient is blacklisted.
     */
    uint8 public constant CODE_ADDRESS_TO_IS_BLACKLISTED = 37;
    /**
     * @notice Restriction code returned when the spender is blacklisted.
     */
    uint8 public constant CODE_ADDRESS_SPENDER_IS_BLACKLISTED = 38;

    error RuleBlacklist_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleBlacklist_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
}
