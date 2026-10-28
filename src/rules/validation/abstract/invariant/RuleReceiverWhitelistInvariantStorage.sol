// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "./RuleSharedInvariantStorage.sol";

/**
 * @title RuleReceiverWhitelistInvariantStorage — constants and error for the receiver-whitelist rule.
 */
abstract contract RuleReceiverWhitelistInvariantStorage is RuleSharedInvariantStorage {
    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the receiver is not whitelisted.
     * @dev Named `RECEIVER` rather than `TO` so it does not collide with `RuleWhitelist`'s
     * `CODE_ADDRESS_TO_NOT_WHITELISTED` (22) when a test contract inherits both invariant stores.
     */
    uint8 public constant CODE_ADDRESS_RECEIVER_NOT_WHITELISTED = 81;
    /**
     * @notice Restriction message returned when the receiver is not whitelisted.
     */
    string constant TEXT_ADDRESS_RECEIVER_NOT_WHITELISTED = "ReceiverWhitelist: Receiver is not whitelisted";

    error RuleReceiverWhitelist_InvalidTransfer(
        address rule, address from, address to, uint256 value, uint8 restrictionCode
    );
    error RuleReceiverWhitelist_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 restrictionCode
    );
}
