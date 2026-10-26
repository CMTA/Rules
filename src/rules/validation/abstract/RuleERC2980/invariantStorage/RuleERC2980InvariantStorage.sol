// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "../../invariant/RuleSharedInvariantStorage.sol";

/**
 * @title RuleERC2980InvariantStorage — constants, roles, events and errors for the ERC-2980 rule.
 */
abstract contract RuleERC2980InvariantStorage is RuleSharedInvariantStorage {
    /* ============ String message ============ */
    /**
     * @notice Restriction message returned when the sender is frozen.
     */
    string constant TEXT_ADDRESS_FROM_IS_FROZEN = "The sender address is frozen";
    /**
     * @notice Restriction message returned when the recipient is frozen.
     */
    string constant TEXT_ADDRESS_TO_IS_FROZEN = "The recipient address is frozen";
    /**
     * @notice Restriction message returned when the spender is frozen.
     */
    string constant TEXT_ADDRESS_SPENDER_IS_FROZEN = "The spender address is frozen";
    /**
     * @notice Restriction message returned when the recipient is not whitelisted.
     */
    string constant TEXT_ADDRESS_TO_NOT_WHITELISTED = "The recipient is not in the whitelist";
    /**
     * @notice Restriction message returned when minting is not allowed.
     */
    string constant TEXT_MINT_NOT_ALLOWED = "Minting is not allowed";
    /**
     * @notice Restriction message returned when burning is not allowed.
     */
    string constant TEXT_BURN_NOT_ALLOWED = "Burning is not allowed";

    /* ============ Code ============ */
    // It is very important that each rule uses a unique code
    /**
     * @notice Restriction code returned when the sender is frozen.
     */
    uint8 public constant CODE_ADDRESS_FROM_IS_FROZEN = 60;
    /**
     * @notice Restriction code returned when the recipient is frozen.
     */
    uint8 public constant CODE_ADDRESS_TO_IS_FROZEN = 61;
    /**
     * @notice Restriction code returned when the spender is frozen.
     */
    uint8 public constant CODE_ADDRESS_SPENDER_IS_FROZEN = 62;
    /**
     * @notice Restriction code returned when the recipient is not whitelisted.
     */
    uint8 public constant CODE_ADDRESS_TO_NOT_WHITELISTED = 63;
    /**
     * @notice Restriction code returned when minting is not allowed by this rule.
     */
    uint8 public constant CODE_MINT_NOT_ALLOWED = 64;
    /**
     * @notice Restriction code returned when burning is not allowed by this rule.
     */
    uint8 public constant CODE_BURN_NOT_ALLOWED = 65;

    /* ============ Roles ============ */
    /**
     * @notice Role allowed to add addresses to the whitelist.
     */
    bytes32 public constant WHITELIST_ADD_ROLE = keccak256("WHITELIST_ADD_ROLE");
    /**
     * @notice Role allowed to remove addresses from the whitelist.
     */
    bytes32 public constant WHITELIST_REMOVE_ROLE = keccak256("WHITELIST_REMOVE_ROLE");
    /**
     * @notice Role allowed to add addresses to the frozenlist.
     */
    bytes32 public constant FROZENLIST_ADD_ROLE = keccak256("FROZENLIST_ADD_ROLE");
    /**
     * @notice Role allowed to remove addresses from the frozenlist.
     */
    bytes32 public constant FROZENLIST_REMOVE_ROLE = keccak256("FROZENLIST_REMOVE_ROLE");

    /* ============ Events ============ */
    /**
     * @notice Emitted when a batch whitelist add completes.
     * @dev `targetAddresses` is the input as submitted, not the set that changed state; `added` and
     * `skipped` describe the effect. See {IAddressList.AddAddresses}.
     * @param targetAddresses The array submitted by the caller.
     * @param added Number of addresses newly whitelisted.
     * @param skipped Number of addresses already whitelisted.
     */
    event AddWhitelistAddresses(address[] targetAddresses, uint256 added, uint256 skipped);
    /**
     * @notice Emitted when a batch whitelist remove completes.
     * @param targetAddresses The array submitted by the caller.
     * @param removed Number of addresses actually removed.
     * @param skipped Number of addresses that were not whitelisted.
     */
    event RemoveWhitelistAddresses(address[] targetAddresses, uint256 removed, uint256 skipped);
    /**
     * @notice Emitted when a single address is added to the whitelist.
     * @param targetAddress Address added to the whitelist.
     */
    event AddWhitelistAddress(address indexed targetAddress);
    /**
     * @notice Emitted when a single address is removed from the whitelist.
     * @param targetAddress Address removed from the whitelist.
     */
    event RemoveWhitelistAddress(address indexed targetAddress);

    /**
     * @notice Emitted when a batch frozenlist add completes.
     * @param targetAddresses The array submitted by the caller.
     * @param added Number of addresses newly frozen.
     * @param skipped Number of addresses already frozen.
     */
    event AddFrozenlistAddresses(address[] targetAddresses, uint256 added, uint256 skipped);
    /**
     * @notice Emitted when a batch frozenlist remove completes.
     * @param targetAddresses The array submitted by the caller.
     * @param removed Number of addresses actually removed.
     * @param skipped Number of addresses that were not frozen.
     */
    event RemoveFrozenlistAddresses(address[] targetAddresses, uint256 removed, uint256 skipped);
    /**
     * @notice Emitted when a single address is added to the frozenlist.
     * @param targetAddress Address added to the frozenlist.
     */
    event AddFrozenlistAddress(address indexed targetAddress);
    /**
     * @notice Emitted when a single address is removed from the frozenlist.
     * @param targetAddress Address removed from the frozenlist.
     */
    event RemoveFrozenlistAddress(address indexed targetAddress);

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

    /* ============ Custom errors ============ */
    error RuleERC2980_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleERC2980_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
    /**
     * @notice Thrown when trying to add the zero address to the whitelist or the frozenlist.
     * @dev The zero address is the ERC-20 mint/burn sentinel, not a participant. Listing it would
     *      make the MANDATORY ERC-2980 getter `whitelist(address(0))` return `true`. Mint/burn
     *      permission is governed by the explicit `allowMint` / `allowBurn` flags instead.
     */
    error RuleERC2980_ZeroAddressNotAllowed();
    /**
     * @notice Thrown when adding an address that is already on the whitelist.
     */
    error RuleERC2980_AddressAlreadyWhitelisted();
    /**
     * @notice Thrown when removing an address that is not on the whitelist.
     */
    error RuleERC2980_AddressNotWhitelisted();
    /**
     * @notice Thrown when adding an address that is already on the frozenlist.
     */
    error RuleERC2980_AddressAlreadyFrozen();
    /**
     * @notice Thrown when removing an address that is not on the frozenlist.
     */
    error RuleERC2980_AddressNotFrozen();
}
