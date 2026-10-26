// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "./RuleSharedInvariantStorage.sol";

/**
 * @title RuleMaxBalanceInvariantStorage — constants, events and errors for the max-balance rule.
 */
abstract contract RuleMaxBalanceInvariantStorage is RuleSharedInvariantStorage {
    /**
     * @notice Role allowed to change the cap, the observed token and the exemption list.
     */
    bytes32 public constant MAX_BALANCE_ROLE = keccak256("MAX_BALANCE_ROLE");

    /**
     * @notice Restriction message returned when the receiver's balance would exceed the cap.
     */
    string constant TEXT_MAX_BALANCE_EXCEEDED = "Recipient balance would exceed the maximum";
    /**
     * @notice Restriction message returned when the receiver's balance cannot be read.
     */
    string constant TEXT_BALANCE_UNAVAILABLE = "Token balance is unavailable";

    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the transfer would push the receiver above {maxBalance}.
     */
    uint8 public constant CODE_MAX_BALANCE_EXCEEDED = 82;
    /**
     * @notice Restriction code returned when `balanceToken.balanceOf(to)` reverts or the token has
     * lost its code, so the receiver's balance cannot be established.
     * @dev Fail-closed: without a balance the cap cannot be verified, so the transfer is blocked
     * rather than assumed safe.
     */
    uint8 public constant CODE_BALANCE_UNAVAILABLE = 83;

    /**
     * @notice Emitted when the maximum balance per holder is updated.
     * @param newMaxBalance The new cap, in token units.
     */
    event MaxBalanceUpdated(uint256 newMaxBalance);
    /**
     * @notice Emitted when the observed token contract is updated.
     * @dev Named distinctly from `RuleMaxTotalSupply`'s `TokenContractUpdated`: `HelperContract`
     * inherits both invariant-storage contracts and identical identifiers would clash.
     * @param newBalanceToken Address of the newly configured token contract.
     */
    event MaxBalanceTokenUpdated(address indexed newBalanceToken);
    /**
     * @notice Emitted when an address is exempted from the cap.
     * @param targetAddress The newly exempt address.
     */
    event ExemptAddressAdded(address indexed targetAddress);
    /**
     * @notice Emitted when an address loses its exemption.
     * @param targetAddress The address that is no longer exempt.
     */
    event ExemptAddressRemoved(address indexed targetAddress);
    /**
     * @notice Emitted when several addresses are exempted in one call.
     * @param targetAddresses The submitted addresses.
     * @param added Number of addresses that were not already exempt.
     * @param skipped Number of addresses that were already exempt.
     */
    event ExemptAddressesAdded(address[] targetAddresses, uint256 added, uint256 skipped);
    /**
     * @notice Emitted when several addresses lose their exemption in one call.
     * @param targetAddresses The submitted addresses.
     * @param removed Number of addresses that were exempt.
     * @param skipped Number of addresses that were not exempt.
     */
    event ExemptAddressesRemoved(address[] targetAddresses, uint256 removed, uint256 skipped);

    error RuleMaxBalance_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleMaxBalance_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
    error RuleMaxBalance_TokenAddressZeroNotAllowed();
    error RuleMaxBalance_TokenIsNotAContract(address token);
    error RuleMaxBalance_TokenBalanceUnavailable(address token);
}
