// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "./RuleSharedInvariantStorage.sol";
import {ISanctionsList} from "../../../interfaces/ISanctionsList.sol";

/**
 * @title RuleSanctionsListInvariantStorage — constants, role, event and errors for the sanctions-list rule.
 */
abstract contract RuleSanctionsListInvariantStorage is RuleSharedInvariantStorage {
    /* ============ Role ============ */
    /**
     * @notice Role allowed to configure the sanctions-list oracle.
     */
    bytes32 public constant SANCTIONLIST_ROLE = keccak256("SANCTIONLIST_ROLE");

    /* ============ String message ============ */
    /**
     * @notice Restriction message returned when the sender is sanctioned.
     */
    string constant TEXT_ADDRESS_FROM_IS_SANCTIONED = "The sender is sanctioned";
    /**
     * @notice Restriction message returned when the recipient is sanctioned.
     */
    string constant TEXT_ADDRESS_TO_IS_SANCTIONED = "The recipient is sanctioned";
    /**
     * @notice Restriction message returned when the spender is sanctioned.
     */
    string constant TEXT_ADDRESS_SPENDER_IS_SANCTIONED = "The spender is sanctioned";

    /* ============ Code ============ */
    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the sender is sanctioned.
     */
    uint8 public constant CODE_ADDRESS_FROM_IS_SANCTIONED = 30;
    /**
     * @notice Restriction code returned when the recipient is sanctioned.
     */
    uint8 public constant CODE_ADDRESS_TO_IS_SANCTIONED = 31;
    /**
     * @notice Restriction code returned when the spender is sanctioned.
     */
    uint8 public constant CODE_ADDRESS_SPENDER_IS_SANCTIONED = 32;

    /* ============ Event ============ */
    /**
     * @notice Emitted when the sanctions-list oracle is set.
     * @param newOracle Address of the newly configured sanctions-list oracle.
     */
    event SetSanctionListOracle(ISanctionsList newOracle);

    /* ============ Custom errors ============ */
    error RuleSanctionsList_OracleAddressZeroNotAllowed();
    error RuleSanctionsList_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleSanctionsList_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
}
