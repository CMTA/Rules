// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import {RuleSharedInvariantStorage} from "../../invariant/RuleSharedInvariantStorage.sol";

/**
 * @title RuleWhitelistInvariantStorage — constants and events for the whitelist rule.
 */
abstract contract RuleWhitelistInvariantStorage is RuleSharedInvariantStorage {
    /* ============ String message ============ */
    /**
     * @notice Restriction message returned when the sender is not whitelisted.
     */
    string constant TEXT_ADDRESS_FROM_NOT_WHITELISTED = "The sender is not in the whitelist";
    /**
     * @notice Restriction message returned when the recipient is not whitelisted.
     */
    string constant TEXT_ADDRESS_TO_NOT_WHITELISTED = "The recipient is not in the whitelist";
    /**
     * @notice Restriction message returned when the spender is not whitelisted.
     */
    string constant TEXT_ADDRESS_SPENDER_NOT_WHITELISTED = "The spender is not in the whitelist";
    /**
     * @notice Restriction message returned when minting is not allowed.
     */
    string constant TEXT_MINT_NOT_ALLOWED = "Minting is not allowed";
    /**
     * @notice Restriction message returned when burning is not allowed.
     */
    string constant TEXT_BURN_NOT_ALLOWED = "Burning is not allowed";

    /* ============ Code ============ */
    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the sender is not whitelisted.
     */
    uint8 public constant CODE_ADDRESS_FROM_NOT_WHITELISTED = 21;
    /**
     * @notice Restriction code returned when the recipient is not whitelisted.
     */
    uint8 public constant CODE_ADDRESS_TO_NOT_WHITELISTED = 22;
    /**
     * @notice Restriction code returned when the spender is not whitelisted.
     */
    uint8 public constant CODE_ADDRESS_SPENDER_NOT_WHITELISTED = 23;
    /**
     * @notice Restriction code returned when minting is not allowed by this rule.
     */
    uint8 public constant CODE_MINT_NOT_ALLOWED = 24;
    /**
     * @notice Restriction code returned when burning is not allowed by this rule.
     */
    uint8 public constant CODE_BURN_NOT_ALLOWED = 25;

    /* ============ Events ============ */
    /**
     * @notice Emitted when the `checkSpender` flag is updated.
     * @param newValue New value of the `checkSpender` flag.
     */
    event CheckSpenderUpdated(bool newValue);
    /**
     * @notice Emitted when the `allowMint` flag is updated.
     * @param newValue New value of the `allowMint` flag.
     */
    event AllowMintUpdated(bool newValue);
    /**
     * @notice Emitted when the `allowBurn` flag is updated.
     * @param newValue New value of the `allowBurn` flag.
     */
    event AllowBurnUpdated(bool newValue);

    /**
     * @notice A candidate child rule does not answer `areAddressesListed(address[])`.
     * @dev Raised by `RuleWhitelistWrapper` when a rule is added that does not advertise
     * {AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID} via ERC-165. Without the guard
     * the wrapper accepted it and then reverted on the blind call during a transfer, bricking every
     * check whose targets were not already resolved. Nethermind AuditAgent NM-18, audit F-5.
     * @param rule The rejected candidate.
     */
    error RuleWhitelistWrapper_ChildIsNotAnAddressList(address rule);

    /**
     * @notice A candidate child rule does not declare whether its list means "allowed" or "denied".
     * @dev Absence is treated as a refusal, never as an assumed allow-list: that is the only reading
     * that fails closed for a contract predating {IAddressListPolarity} or deliberately declining it
     * (`RuleSpenderWhitelist` declines, because its set is spenders rather than holders).
     * @param rule The rejected candidate.
     */
    error RuleWhitelistWrapper_ChildDoesNotDeclarePolarity(address rule);

    /**
     * @notice A candidate child rule declares itself a DENY-list; this wrapper aggregates allow-lists.
     * @dev The wrapper ORs its children's membership answers and reads `true` as eligible, so a
     * deny-list child would make its blocked addresses permitted and `isVerified` report them as
     * verified investors. Nethermind AuditAgent NM-20.
     * @param rule The rejected candidate.
     */
    error RuleWhitelistWrapper_ChildIsNotAnAllowList(address rule);

    error RuleWhitelist_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleWhitelist_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
}
