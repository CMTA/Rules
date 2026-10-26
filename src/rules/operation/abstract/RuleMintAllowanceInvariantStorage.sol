// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "../../validation/abstract/invariant/RuleSharedInvariantStorage.sol";

/**
 * @title RuleMintAllowanceInvariantStorage — constants, events and errors for the mint-allowance rule
 */
abstract contract RuleMintAllowanceInvariantStorage is RuleSharedInvariantStorage {
    /* ============ Role ============ */
    /**
     * @notice Role allowed to set, increase and decrease minter allowances
     */
    bytes32 public constant ALLOWANCE_OPERATOR_ROLE = keccak256("ALLOWANCE_OPERATOR_ROLE");

    /* ============ State variables ============ */
    /**
     * @notice Human-readable message returned when a minter's allowance is exceeded
     */
    string constant TEXT_MINTER_ALLOWANCE_EXCEEDED = "MintAllowance: minter allowance exceeded";
    // It is very important that each rule uses a unique code
    /**
     * @notice Restriction code returned when a minter's allowance is exceeded
     */
    uint8 public constant CODE_MINTER_ALLOWANCE_EXCEEDED = 70;

    /* ============ Events ============ */
    /**
     * @notice Emitted when a minter's allowance is set to an absolute value
     * @param minter The minter whose allowance was set
     * @param newAllowance The allowance after the update
     */
    event MintAllowanceSet(address indexed minter, uint256 newAllowance);
    /**
     * @notice Emitted when a minter's allowance is increased
     * @param minter The minter whose allowance was increased
     * @param addedAmount The amount added to the allowance
     * @param newAllowance The allowance after the increase
     */
    event MintAllowanceIncreased(address indexed minter, uint256 addedAmount, uint256 newAllowance);
    /**
     * @notice Emitted when a minter's allowance is decreased
     * @param minter The minter whose allowance was decreased
     * @param reducedAmount The amount subtracted from the allowance
     * @param newAllowance The allowance after the decrease
     */
    event MintAllowanceDecreased(address indexed minter, uint256 reducedAmount, uint256 newAllowance);
    /**
     * @notice Emitted when a mint consumes part of a minter's allowance
     * @param minter The minter whose allowance was consumed
     * @param consumed The amount deducted by the mint
     * @param remaining The allowance remaining after consumption
     */
    event MintAllowanceConsumed(address indexed minter, uint256 consumed, uint256 remaining);

    /* ============ Custom error ============ */
    error RuleMintAllowance_AllowanceExceeded(address rule, address minter, uint256 allowance, uint256 amount);
    error RuleMintAllowance_DecreaseBelowZero(address minter, uint256 currentAllowance, uint256 reductionAmount);
    error RuleMintAllowance_TokenAlreadyBound();
}
