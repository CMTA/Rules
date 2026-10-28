// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title RuleConditionalTransferInvariantStorage — the restriction code of an unapproved conditional transfer.
 * @dev Shared by `RuleConditionalTransferLight` and `RuleConditionalTransferLightMultiToken`. A RuleEngine answers
 * `messageForTransferRestriction` from the first rule claiming the code, so a code used by two rules must carry
 * one message: with both rules in one engine, either may answer for the other's rejection.
 */
abstract contract RuleConditionalTransferInvariantStorage {
    /**
     * @notice Restriction message returned when a transfer has not been approved.
     */
    string constant TEXT_TRANSFER_REQUEST_NOT_APPROVED = "ConditionalTransfer: The request is not approved";

    /**
     * @notice Restriction code returned when a transfer request has not been approved.
     */
    uint8 public constant CODE_TRANSFER_REQUEST_NOT_APPROVED = 46;
}
