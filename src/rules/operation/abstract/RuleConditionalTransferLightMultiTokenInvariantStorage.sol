// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleSharedInvariantStorage} from "../../validation/abstract/invariant/RuleSharedInvariantStorage.sol";

/**
 * @title RuleConditionalTransferLightMultiTokenInvariantStorage — constants, events and errors for the multi-token conditional-transfer rule
 */
abstract contract RuleConditionalTransferLightMultiTokenInvariantStorage is RuleSharedInvariantStorage {
    /* ============ Role ============ */
    /**
     * @notice Role allowed to approve, cancel and execute conditional transfers
     */
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* ============ State variables ============ */
    /**
     * @notice Human-readable message returned when a transfer has not been approved
     */
    string constant TEXT_TRANSFER_REQUEST_NOT_APPROVED =
        "ConditionalTransferLightMultiToken: The request is not approved";
    /**
     * @notice Restriction code returned when a transfer request has not been approved
     */
    uint8 public constant CODE_TRANSFER_REQUEST_NOT_APPROVED = 46;

    /* ============ Events ============ */
    /**
     * @notice Emitted when a transfer is approved for a given token
     * @param token The token the approval applies to
     * @param from The sender of the approved transfer
     * @param to The recipient of the approved transfer
     * @param value The amount of the approved transfer
     * @param count The approval count for this transfer after the approval
     */
    event TransferApproved(
        address indexed token, address indexed from, address indexed to, uint256 value, uint256 count
    );
    /**
     * @notice Emitted when an approved transfer is executed for a given token
     * @param token The token the transfer applies to
     * @param from The sender of the executed transfer
     * @param to The recipient of the executed transfer
     * @param value The amount of the executed transfer
     * @param remaining The approval count remaining for this transfer after execution
     */
    event TransferExecuted(
        address indexed token, address indexed from, address indexed to, uint256 value, uint256 remaining
    );
    /**
     * @notice Emitted when a transfer approval is cancelled for a given token
     * @param token The token the approval applies to
     * @param from The sender of the cancelled transfer approval
     * @param to The recipient of the cancelled transfer approval
     * @param value The amount of the cancelled transfer approval
     * @param remaining The approval count remaining for this transfer after cancellation
     */
    event TransferApprovalCancelled(
        address indexed token, address indexed from, address indexed to, uint256 value, uint256 remaining
    );
    /**
     * @notice Emitted when every outstanding approval for a per-token transfer is cleared at once
     * @param token The token the cleared approvals applied to
     * @param from The sender of the cleared transfer approvals
     * @param to The recipient of the cleared transfer approvals
     * @param value The amount of the cleared transfer approvals
     * @param cleared The approval count that was discarded
     */
    event TransferApprovalReset(
        address indexed token, address indexed from, address indexed to, uint256 value, uint256 cleared
    );

    /* ============ Custom error ============ */
    error RuleConditionalTransferLightMultiToken_TransferExecutorUnauthorized(address account);
    error RuleConditionalTransferLightMultiToken_InsufficientAllowance(
        address token, address owner, uint256 allowance, uint256 required
    );
    /**
     * @notice The approval created by {approveAndTransferIfAllowed} was not consumed by the transfer.
     * @dev See the single-token twin: the helper inverts CEI so the approval exists for the token's
     * compliance callback, and this post-condition catches the case where no callback reached the
     * rule and the approval would otherwise have been left spendable. Nethermind AuditAgent NM-17.
     * @param token The token the transfer was executed on.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount transferred.
     */
    error RuleConditionalTransferLightMultiToken_ApprovalNotConsumed(
        address token, address from, address to, uint256 value
    );

    error RuleConditionalTransferLightMultiToken_InvalidToken();
    error RuleConditionalTransferLightMultiToken_TransferNotApproved();
    error RuleConditionalTransferLightMultiToken_TransferApprovalNotFound();
}
