// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleSharedInvariantStorage} from "./RuleSharedInvariantStorage.sol";

/**
 * @title RuleMaxTotalSupplyInvariantStorage — constants and events for the max-total-supply rule.
 */
abstract contract RuleMaxTotalSupplyInvariantStorage is RuleSharedInvariantStorage {
    /**
     * @notice Restriction message returned when the max total supply would be exceeded.
     */
    string constant TEXT_MAX_TOTAL_SUPPLY_EXCEEDED = "Max total supply exceeded";
    /**
     * @notice Restriction message returned when the token's total supply cannot be read.
     * @dev Named differently from `RuleChainlinkPoR`'s equivalent on purpose: `HelperContract`
     * inherits both invariant-storage contracts, and identical identifiers would clash.
     */
    string constant TEXT_SUPPLY_ORACLE_UNAVAILABLE = "Token total supply is unavailable";

    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the max total supply would be exceeded.
     */
    uint8 public constant CODE_MAX_TOTAL_SUPPLY_EXCEEDED = 50;
    /**
     * @notice Restriction code returned when `tokenContract.totalSupply()` reverts or the token has
     * lost its code, so the current supply cannot be established.
     * @dev Fail-closed: without a supply figure the cap cannot be verified, so the mint is blocked
     * rather than assumed safe.
     */
    uint8 public constant CODE_SUPPLY_ORACLE_UNAVAILABLE = 51;

    /**
     * @notice Emitted when the maximum total supply is updated, including the initial assignment.
     * @param previousMaxTotalSupply Cap before the update; `0` for the constructor's assignment.
     * @param newMaxTotalSupply New maximum total supply cap.
     */
    event MaxTotalSupplyUpdated(uint256 previousMaxTotalSupply, uint256 newMaxTotalSupply);
    /**
     * @notice Emitted when the tracked token contract is updated.
     * @param newTokenContract Address of the newly configured token contract.
     */
    event TokenContractUpdated(address indexed newTokenContract);

    error RuleMaxTotalSupply_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleMaxTotalSupply_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
    error RuleMaxTotalSupply_TokenAddressZeroNotAllowed();
    error RuleMaxTotalSupply_TokenIsNotAContract(address token);
    error RuleMaxTotalSupply_TokenTotalSupplyUnavailable(address token);
}
