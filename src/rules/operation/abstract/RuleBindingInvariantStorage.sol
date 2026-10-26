// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title RuleBindingInvariantStorage — the restriction code of a stateful rule that has no bound caller.
 * @dev Shared by `RuleConditionalTransferLight`, `RuleMintAllowance` and `RuleIssuanceCap`, whose `transferred`
 * accepts only a bound caller. Until one is bound, every operation reverts, so their views return this code
 * instead of answering as if it would succeed. One code and one message for all three, as `IRule` requires of a
 * shared code.
 */
abstract contract RuleBindingInvariantStorage {
    /**
     * @notice Restriction message returned while the rule has no bound caller.
     */
    string constant TEXT_RULE_NOT_BOUND = "Rule not bound to a token or RuleEngine";

    /**
     * @notice Restriction code returned while the rule has no bound caller.
     */
    uint8 public constant CODE_RULE_NOT_BOUND = 85;
}
