// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleBindingInvariantStorage} from "./RuleBindingInvariantStorage.sol";

/**
 * @title RuleIssuanceCapInvariantStorage — constants, events and errors for the issuance-cap rule
 * @dev Only what `RuleIssuanceCap` adds. Codes 50 / 51, the cap events and the cap errors are inherited
 * from `RuleMaxTotalSupplyInvariantStorage`.
 */
abstract contract RuleIssuanceCapInvariantStorage is RuleBindingInvariantStorage {
    /**
     * @notice Restriction message returned when cumulative issuance would exceed the cap.
     */
    string constant TEXT_ISSUANCE_CAP_EXCEEDED = "Issuance cap exceeded";

    /**
     * @notice Restriction code returned when cumulative issuance would exceed the cap.
     */
    uint8 public constant CODE_ISSUANCE_CAP_EXCEEDED = 71;

    /**
     * @notice Emitted once at deployment with the issuance already counted.
     * @param initialIssued Issuance before the rule was installed.
     */
    event TotalIssuedInitialized(uint256 initialIssued);

    /**
     * @notice Emitted when an accepted mint is recorded.
     * @param value Amount minted.
     * @param totalIssued Cumulative issuance after the mint.
     */
    event IssuanceRecorded(uint256 value, uint256 totalIssued);

    error RuleIssuanceCap_InitialIssuedBelowSupply(uint256 initialIssued, uint256 totalSupply);
    error RuleIssuanceCap_IssuanceCapExceeded(address rule, uint256 totalIssued, uint256 cap, uint256 value);
    error RuleIssuanceCap_TokenContractLocked();
    error RuleIssuanceCap_TokenAlreadyBound();
}
