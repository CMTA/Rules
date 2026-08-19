// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleSharedInvariantStorage} from "../../validation/abstract/invariant/RuleSharedInvariantStorage.sol";

/**
 * @title RuleConditionalTransferLightInvariantStorage — constants, events and errors for the conditional-transfer rule
 */
abstract contract RuleConditionalTransferLightInvariantStorage is RuleSharedInvariantStorage {
    /* ============ Role ============ */
    /**
     * @notice Role allowed to approve, cancel and execute conditional transfers
     */
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* ============ State variables ============ */
    /**
     * @notice Human-readable message returned when a transfer has not been approved
     */
    string constant TEXT_TRANSFER_REQUEST_NOT_APPROVED = "ConditionalTransferLight: The request is not approved";
    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when a transfer request has not been approved
     */
    uint8 public constant CODE_TRANSFER_REQUEST_NOT_APPROVED = 46;

    /* ============ Events ============ */
    /**
     * @notice Emitted when a transfer is approved
     * @param from The sender of the approved transfer
     * @param to The recipient of the approved transfer
     * @param value The amount of the approved transfer
     * @param count The approval count for this transfer after the approval
     */
    event TransferApproved(address indexed from, address indexed to, uint256 value, uint256 count);
    /**
     * @notice Emitted when an approved transfer is executed
     * @param from The sender of the executed transfer
     * @param to The recipient of the executed transfer
     * @param value The amount of the executed transfer
     * @param remaining The approval count remaining for this transfer after execution
     */
    event TransferExecuted(address indexed from, address indexed to, uint256 value, uint256 remaining);
    /**
     * @notice Emitted when a transfer approval is cancelled
     * @param from The sender of the cancelled transfer approval
     * @param to The recipient of the cancelled transfer approval
     * @param value The amount of the cancelled transfer approval
     * @param remaining The approval count remaining for this transfer after cancellation
     */
    event TransferApprovalCancelled(address indexed from, address indexed to, uint256 value, uint256 remaining);
    /**
     * @notice Emitted when every outstanding approval for a transfer is cleared at once
     * @param from The sender of the cleared transfer approvals
     * @param to The recipient of the cleared transfer approvals
     * @param value The amount of the cleared transfer approvals
     * @param cleared The approval count that was discarded
     */
    event TransferApprovalReset(address indexed from, address indexed to, uint256 value, uint256 cleared);
    /**
     * @notice Emitted when a RuleEngine is authorized to call the transfer execution hooks
     * @param ruleEngine The RuleEngine now allowed to call `transferred`
     */
    event RuleEngineBound(address indexed ruleEngine);
    /**
     * @notice Emitted when a RuleEngine's authorization to call the transfer execution hooks is revoked
     * @param ruleEngine The RuleEngine no longer allowed to call `transferred`
     */
    event RuleEngineUnbound(address indexed ruleEngine);

    /* ============ Custom error ============ */
    error RuleConditionalTransferLight_TransferExecutorUnauthorized(address account);
    error RuleConditionalTransferLight_TokenNotBound();
    error RuleConditionalTransferLight_TokenAlreadyBound();
    error RuleConditionalTransferLight_InsufficientAllowance(
        address token, address owner, uint256 allowance, uint256 required
    );
    error TransferNotApproved();
    error TransferApprovalNotFound();
    /**
     * @notice The approval created by {approveAndTransferIfAllowed} was not consumed by the transfer.
     * @dev The helper inverts CEI deliberately so the approval exists while the token runs its
     * compliance callback. That is only correct if the callback actually reaches this rule; when it
     * does not -- a plain ERC-20 bound for the helper, or a RuleEngine never bound or since unbound --
     * the transfer used to succeed and leave a spendable approval behind, authorising a later
     * never-approved transfer of the same tuple. The post-condition turns that silent hole into this
     * revert. Nethermind AuditAgent NM-17.
     * @param token The bound ERC-20 the transfer was executed on.
     * @param from The sender of the transfer.
     * @param to The recipient of the transfer.
     * @param value The amount transferred.
     */
    error RuleConditionalTransferLight_ApprovalNotConsumed(address token, address from, address to, uint256 value);

    error RuleConditionalTransferLight_RuleEngineAddressZeroNotAllowed();
    error RuleConditionalTransferLight_RuleEngineNotBound();
    error RuleConditionalTransferLight_RuleEngineAlreadyBound();
}
