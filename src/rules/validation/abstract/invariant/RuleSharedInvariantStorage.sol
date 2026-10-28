// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title RuleSharedInvariantStorage — constants shared across all rules.
 */
abstract contract RuleSharedInvariantStorage {
    /* ============ String message ============ */
    /**
     * @notice Message returned when a restriction code has no associated message.
     */
    string constant TEXT_CODE_NOT_FOUND = "Unknown restriction code";
}
