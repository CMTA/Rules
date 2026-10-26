// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "./RuleSharedInvariantStorage.sol";

/**
 * @title RuleSpenderWhitelistInvariantStorage — constants and error for the spender-whitelist rule.
 */
abstract contract RuleSpenderWhitelistInvariantStorage is RuleSharedInvariantStorage {
    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the spender is not whitelisted.
     */
    uint8 public constant CODE_ADDRESS_SPENDER_NOT_WHITELISTED = 66;
    /**
     * @notice Restriction message returned when the spender is not whitelisted.
     */
    string constant TEXT_ADDRESS_SPENDER_NOT_WHITELISTED = "SpenderWhitelist: Spender is not whitelisted";

    error RuleSpenderWhitelist_InvalidTransferFrom(
        address ruleEngine, address spender, address from, address to, uint256 value, uint8 restrictionCode
    );
}
